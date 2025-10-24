#!/bin/bash
# File: install-kubernetes-monitoring.sh
# Description: Automated installation of Prometheus, Grafana, and Envoy Gateway on Kubernetes
# Author: T.I.Q.S.
# Version: 2.1
# Usage: bash install-kubernetes-monitoring.sh

set -euo pipefail

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD="\033[1m"; RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"
  BLUE="\033[34m"; CYAN="\033[36m"; RESET="\033[0m"
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; RESET=""
fi

section()   { echo -e "${BOLD}${CYAN}\n=======================================\n$*${RESET}"; }
subsection(){ echo -e "${BOLD}${BLUE}\n# $*${RESET}"; }
info()      { echo -e "${YELLOW}➜ $*${RESET}"; }
success()   { echo -e "${GREEN}✔ $*${RESET}"; }
warn()      { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()     { echo -e "${RED}✖ $*${RESET}"; }
spacer()    { echo ""; }

trap 'error "Script failed on line ${BASH_LINENO[0]}"; exit 1' ERR

section "🚀 Starting Helm and Observability Setup"

subsection "Setup Helm Repositories"
info "Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
success "Prometheus repo added."
spacer

info "Updating Helm repositories..."
helm repo update
success "Helm repositories updated."
spacer

subsection "Install Prometheus & Grafana (kube-prometheus-stack)"
info "Installing kube-prometheus-stack (Prometheus + Grafana)..."
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName="gp2" \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage="50Gi" \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.service.type=LoadBalancer \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.storageClassName="gp2" \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName="gp2" \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage="10Gi"
success "kube-prometheus-stack installed."
spacer

subsection "Install Envoy Gateway"
info "Installing Envoy Gateway (v1.5.3)..."
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.5.3 \
  --namespace envoy-gateway-system \
  --create-namespace
success "Envoy Gateway chart installed."
spacer

info "Waiting up to 5m for Envoy Gateway deployment to become Available..."
kubectl wait \
  --namespace envoy-gateway-system \
  --for=condition=Available \
  --timeout=5m \
  deployment/envoy-gateway
success "Envoy Gateway is Available."
spacer

subsection "Apply Envoy Gateway Quickstart"
info "Applying Envoy Gateway quickstart configuration..."
kubectl apply \
  -f https://github.com/envoyproxy/gateway/releases/download/v1.5.3/quickstart.yaml \
  --namespace default
success "Quickstart configuration applied."
spacer

subsection "Create ServiceMonitor for Envoy Metrics"
info "Creating ServiceMonitor (observability/envoy-gateway)..."

cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: envoy-gateway
  namespace: observability
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: envoy-gateway
  namespaceSelector:
    matchNames:
      - envoy-gateway-system
  endpoints:
    - port: metrics
      path: /stats/prometheus
      interval: 15s
EOF

success "ServiceMonitor created."
spacer

subsection "Verify Observability Namespace Resources"
info "Listing Pods (release=monitoring)..."
kubectl get pods \
  --namespace observability \
  --selector release=monitoring \
  || warn "No pods found yet."
spacer

info "Listing StatefulSets..."
kubectl get statefulsets \
  --namespace observability \
  || warn "No StatefulSets found."
spacer

info "Listing DaemonSets..."
kubectl get daemonsets \
  --namespace observability \
  || warn "No DaemonSets found."
spacer

info "Listing Services..."
kubectl get services \
  --namespace observability \
  || warn "No Services found."
spacer

subsection "Retrieve Grafana Admin Password"
info "Fetching Grafana admin password..."
GRAFANA_PW="$(
  kubectl get secret monitoring-grafana \
    --namespace observability \
    --output jsonpath='{.data.admin-password}' | base64 -d || true
)"

if [[ -n "${GRAFANA_PW}" ]]; then
  success "Grafana admin password: ${BOLD}${GRAFANA_PW}${RESET}"
else
  warn "Grafana secret not ready yet. Try again in a minute."
fi
spacer

subsection "Retrieve LoadBalancer Service URLs"
info "Resolving Grafana and Prometheus external addresses (this may take a bit after install)..."

GRAFANA_HOST="$(
  kubectl get service monitoring-grafana \
    --namespace observability \
    --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
)"
PROM_HOST="$(
  kubectl get service monitoring-kube-prometheus-prometheus \
    --namespace observability \
    --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
)"

GRAFANA_URL="http://${GRAFANA_HOST:-<pending>}:80"
PROM_URL="http://${PROM_HOST:-<pending>}:9090"

if [[ "${GRAFANA_HOST:-}" == "" || "${PROM_HOST:-}" == "" ]]; then
  warn "One or more LoadBalancer addresses are still pending. Re-run the URL section later if needed."
fi

echo -e "${BOLD}---------------------------------------${RESET}"
echo -e "Grafana URL:    ${GREEN}${GRAFANA_URL}${RESET}"
echo -e "Prometheus URL: ${GREEN}${PROM_URL}${RESET}"
echo -e "${BOLD}---------------------------------------${RESET}"
spacer

section "✅ Observability and Envoy Gateway Setup Complete"
success "All done!"
