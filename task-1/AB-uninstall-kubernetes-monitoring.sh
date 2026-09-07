#!/bin/bash
# File: AB-uninstall-kubernetes-monitoring.sh
# Description: Uninstalls Envoy Gateway and the kube-prometheus-stack (Prometheus + Grafana)
# Author: T.I.Q.S.
# Version: 2.2
# Usage: bash AB-uninstall-kubernetes-monitoring.sh
#
# Notes:
# - Safe to re-run: uses existence checks, --ignore-not-found, and graceful fallbacks.
# - Set NO_COLOR=1 to disable colored output (e.g., in CI).

set -euo pipefail

# ---------- Color setup ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD="\033[1m"; RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"
  BLUE="\033[34m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; RESET=""
fi

# ---------- Helpers ----------
section()     { echo -e "${BOLD}${CYAN}\n=======================================\n$*${RESET}"; }
subsection()  { echo -e "${BOLD}${BLUE}\n# $*${RESET}"; }
info()        { echo -e "${YELLOW}➜ $*${RESET}"; }
success()     { echo -e "${GREEN}✔ $*${RESET}"; }
warn()        { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()       { echo -e "${RED}✖ $*${RESET}"; }
spacer()      { echo ""; }

trap 'error "Script failed on line ${BASH_LINENO[0]}"; exit 1' ERR

# Helm uninstall helper with existence checks
helm_uninstall_if_exists() {
  local release="$1"
  local namespace="$2"
  if helm status "$release" -n "$namespace" >/dev/null 2>&1; then
    info "Uninstalling Helm release: ${release} (namespace: ${namespace})"
    helm uninstall "$release" -n "$namespace"
    success "Uninstalled: ${release}"
  else
    warn "Helm release not found: ${release} (namespace: ${namespace}) — skipping"
  fi
}

# Wait for namespace deletion (best-effort)
wait_for_namespace_deletion() {
  local ns="$1"
  local timeout="${2:-120}"   # seconds
  info "Waiting for namespace '${ns}' to terminate (timeout: ${timeout}s)..."
  local start=$(date +%s)
  while kubectl get ns "$ns" >/dev/null 2>&1; do
    sleep 3
    local now=$(date +%s)
    if (( now - start > timeout )); then
      warn "Namespace '${ns}' still exists after ${timeout}s. It may finish terminating shortly."
      return 0
    fi
  done
  success "Namespace '${ns}' no longer present."
}

section "🧹 Uninstalling Kubernetes Monitoring (Envoy + Prometheus/Grafana)"

# ----------------------------------------
subsection "Delete Envoy Gateway quickstart configuration"
info "Deleting Envoy quickstart resources (namespace: default)..."
kubectl delete -f \
  https://github.com/envoyproxy/gateway/releases/download/v1.5.3/quickstart.yaml \
  --namespace default \
  --ignore-not-found=true
success "Envoy quickstart deleted (or not present)."
spacer

# ----------------------------------------
subsection "Delete ServiceMonitor for Envoy Gateway"
info "Deleting ServiceMonitor 'envoy-gateway' (namespace: observability)..."
kubectl delete servicemonitor envoy-gateway \
  --namespace observability \
  --ignore-not-found=true
success "ServiceMonitor deleted (or not present)."
spacer

# ----------------------------------------
subsection "Uninstall Envoy Gateway"
helm_uninstall_if_exists "eg" "envoy-gateway-system"
spacer

info "Deleting namespace 'envoy-gateway-system'..."
kubectl delete namespace envoy-gateway-system \
  --ignore-not-found=true
wait_for_namespace_deletion "envoy-gateway-system" 180
spacer

# ----------------------------------------
subsection "Uninstall kube-prometheus-stack (monitoring)"
helm_uninstall_if_exists "monitoring" "observability"
spacer

info "Deleting namespace 'observability'..."
kubectl delete namespace observability \
  --ignore-not-found=true
wait_for_namespace_deletion "observability" 240
spacer

section "✅ Uninstall Complete"
success "Envoy Gateway and monitoring stack have been removed."
