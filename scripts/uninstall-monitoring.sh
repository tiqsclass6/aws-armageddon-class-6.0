#!/usr/bin/env bash
# Remove Envoy Gateway and kube-prometheus-stack. Safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVOY_VERSION="${ENVOY_VERSION:-v1.5.3}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD="\033[1m"; RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"
  BLUE="\033[34m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; RESET=""
fi

section()    { echo -e "${BOLD}${CYAN}\n=======================================\n$*${RESET}"; }
subsection() { echo -e "${BOLD}${BLUE}\n# $*${RESET}"; }
info()       { echo -e "${YELLOW}➜ $*${RESET}"; }
success()    { echo -e "${GREEN}✔ $*${RESET}"; }
warn()       { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()      { echo -e "${RED}✖ $*${RESET}"; }

trap 'error "Script failed on line ${BASH_LINENO[0]}"; exit 1' ERR

helm_uninstall_if_exists() {
  local release="$1"
  local namespace="$2"
  if helm status "$release" -n "$namespace" >/dev/null 2>&1; then
    info "Uninstalling Helm release: ${release} (${namespace})"
    helm uninstall "$release" -n "$namespace"
    success "Uninstalled: ${release}"
  else
    warn "Helm release not found: ${release} (${namespace})"
  fi
}

wait_for_namespace_deletion() {
  local ns="$1"
  local timeout="${2:-180}"
  info "Waiting for namespace '${ns}' to terminate (timeout: ${timeout}s)..."
  local start now
  start="$(date +%s)"
  while kubectl get ns "$ns" >/dev/null 2>&1; do
    sleep 3
    now="$(date +%s)"
    if (( now - start > timeout )); then
      warn "Namespace '${ns}' still exists after ${timeout}s."
      return 0
    fi
  done
  success "Namespace '${ns}' is gone."
}

section "Uninstall Envoy + Prometheus + Grafana"

subsection "Application routes and demo Gateway"
kubectl delete -f "${ROOT}/scripts/manifests/grafana-route.yaml" --ignore-not-found=true
kubectl delete -f "${ROOT}/scripts/manifests/servicemonitor-envoy.yaml" --ignore-not-found=true
kubectl delete -f "${ROOT}/scripts/manifests/poddisruptionbudgets.yaml" --ignore-not-found=true
kubectl delete -f "https://github.com/envoyproxy/gateway/releases/download/${ENVOY_VERSION}/quickstart.yaml" \
  --namespace default --ignore-not-found=true
success "Gateway demo resources deleted (or were absent)."

subsection "Helm releases"
helm_uninstall_if_exists eg envoy-gateway-system
helm_uninstall_if_exists monitoring observability

subsection "Namespaces"
kubectl delete namespace envoy-gateway-system --ignore-not-found=true
wait_for_namespace_deletion envoy-gateway-system 180
kubectl delete namespace observability --ignore-not-found=true
wait_for_namespace_deletion observability 240

section "Uninstall complete"
success "Envoy Gateway and the monitoring stack have been removed."
info "Terraform infrastructure is unchanged. Run terraform destroy in terraform/ to tear down EKS."
