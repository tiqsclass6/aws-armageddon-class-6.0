#!/usr/bin/env bash
# Automated install of Envoy Gateway, Prometheus, and Grafana on EKS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALUES="${ROOT}/scripts/values"
MANIFESTS="${ROOT}/scripts/manifests"
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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 1; }
}

helm_upgrade_if_needed() {
  local release="$1" namespace="$2"
  shift 2
  helm upgrade --install "$release" "$@" \
    --namespace "$namespace" \
    --create-namespace
}

require_cmd helm
require_cmd kubectl

section "Envoy + Prometheus + Grafana"

subsection "Prerequisites"
kubectl cluster-info >/dev/null
info "Cluster: $(kubectl config current-context)"
if ! kubectl get storageclass gp3 >/dev/null 2>&1; then
  error "StorageClass gp3 not found. Apply terraform in terraform/ first (EBS CSI + gp3)."
  exit 1
fi
success "gp3 StorageClass is present."

subsection "Helm repositories"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
success "Helm repositories updated."

subsection "Install kube-prometheus-stack"
helm_upgrade_if_needed monitoring observability \
  prometheus-community/kube-prometheus-stack \
  --values "${VALUES}/kube-prometheus-stack.yaml"
success "Prometheus and Grafana chart applied."

info "Waiting for Grafana and Prometheus pods..."
kubectl wait --namespace observability \
  --for=condition=Ready pod \
  --selector app.kubernetes.io/name=grafana \
  --timeout=10m
kubectl wait --namespace observability \
  --for=condition=Ready pod \
  --selector app.kubernetes.io/name=prometheus \
  --timeout=10m
success "Grafana and Prometheus pods are Ready."

subsection "Install Envoy Gateway ${ENVOY_VERSION}"
helm_upgrade_if_needed eg envoy-gateway-system \
  oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_VERSION}" \
  --values "${VALUES}/envoy-gateway.yaml"
success "Envoy Gateway chart applied."

kubectl wait \
  --namespace envoy-gateway-system \
  --for=condition=Available \
  --timeout=5m \
  deployment/envoy-gateway
success "Envoy Gateway deployment is Available."

subsection "Gateway demo + Grafana route"
info "Applying Envoy quickstart (sample Gateway in default namespace)..."
kubectl apply \
  -f "https://github.com/envoyproxy/gateway/releases/download/${ENVOY_VERSION}/quickstart.yaml" \
  --namespace default
kubectl apply -f "${MANIFESTS}/grafana-route.yaml"
kubectl apply -f "${MANIFESTS}/servicemonitor-envoy.yaml"
kubectl apply -f "${MANIFESTS}/poddisruptionbudgets.yaml" || warn "PDB selector may not match this chart version — continuing."
success "Gateway, Grafana HTTPRoute, and ServiceMonitor applied."

subsection "Verify"
kubectl get pods --namespace observability
kubectl get pods --namespace envoy-gateway-system
kubectl get svc --namespace observability
kubectl get gateway,httproute -A

subsection "Access"
warn "Grafana admin password is a Kubernetes secret. It is not printed here."
echo "  kubectl get secret monitoring-grafana -n observability -o jsonpath='{.data.admin-password}' | base64 -d; echo"
echo "  Username: admin"

ENVOY_HOST="$(kubectl get gateway/eg -n default -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
if [[ -z "${ENVOY_HOST}" ]]; then
  ENVOY_HOST="$(kubectl get svc -n default -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
fi
echo -e "${BOLD}---------------------------------------${RESET}"
echo -e "Envoy Gateway:  ${GREEN}${ENVOY_HOST:-<pending>}${RESET}"
echo -e "Grafana UI:     ${GREEN}http://${ENVOY_HOST:-<pending>}/grafana/${RESET}  (via Envoy HTTPRoute)"
echo -e "Prometheus:     ClusterIP only — kubectl -n observability port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo -e "${BOLD}---------------------------------------${RESET}"

section "Setup complete"
success "Envoy, Prometheus, and Grafana are installed."
