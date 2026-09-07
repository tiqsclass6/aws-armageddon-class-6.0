#!/usr/bin/env bash
# =============================================================================
# destroy-all-apps.sh — Complete cleanup of Task 2 Kubernetes resources + ECR
# =============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="${NAMESPACE:-task2-ns}"
MANIFEST_DIR="${MANIFEST_DIR:-manifests}"

NS_FILE="${MANIFEST_DIR}/apps-namespace.yaml"
INGRESS_FILE="${MANIFEST_DIR}/apps-ingress.yaml"

APP1_MANIFESTS=(
  "${MANIFEST_DIR}/app1-hpa.yaml"
  "${MANIFEST_DIR}/app1-service.yaml"
  "${MANIFEST_DIR}/app1-deployment.yaml"
)

APP2_MANIFESTS=(
  "${MANIFEST_DIR}/app2-hpa.yaml"
  "${MANIFEST_DIR}/app2-service.yaml"
  "${MANIFEST_DIR}/app2-deployment.yaml"
)

APP3_MANIFESTS=(
  "${MANIFEST_DIR}/app3-hpa.yaml"
  "${MANIFEST_DIR}/app3-service.yaml"
  "${MANIFEST_DIR}/app3-deployment.yaml"
)

APPS=(app1 app2 app3)

# ──────────────────────────────────────────────────────────────────────────────
# Colors & logging
# ──────────────────────────────────────────────────────────────────────────────
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_CYAN="\033[1;36m"
C_MAGENTA="\033[1;35m"

hr()       { echo -e "${C_BOLD}══════════════════════════════════════════════════════════════════════════════${C_RESET}"; }
stage()    { hr; echo -e "${C_MAGENTA}==> $*${C_RESET}"; hr; }
info()     { echo -e "${C_CYAN}[INFO]${C_RESET}  $*"; }
warn()     { echo -e "${C_YELLOW}[WARN]${C_RESET}  $*"; }
success()  { echo -e "${C_GREEN}[SUCCESS]${C_RESET}  $*"; }
fatal()    { echo -e "${C_RED}[ERROR]${C_RESET} $*" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
# Utility: check required commands
# ──────────────────────────────────────────────────────────────────────────────
need() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fatal "Required command not found: $cmd"
}

# ──────────────────────────────────────────────────────────────────────────────
# Safe delete helper
# ──────────────────────────────────────────────────────────────────────────────
safe_delete() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    warn "File not found – skipping: $path"
    return 0
  fi
  info "Deleting $(basename "$path")"
  kubectl delete -f "$path" --ignore-not-found=true --grace-period=0 2>/dev/null || true
}

# ──────────────────────────────────────────────────────────────────────────────
# Main execution
# ──────────────────────────────────────────────────────────────────────────────
stage "Starting cleanup of namespace: ${NAMESPACE}"

need kubectl
need aws
need jq

# 1. Ingress first
stage "Removing Ingress"
safe_delete "${INGRESS_FILE}"
info "Waiting 30–45 seconds for AWS Load Balancer Controller to clean up ALB..."
sleep 35

# 2. Application resources (reverse order)
stage "Removing application resources"

info "→ app3"
for f in "${APP3_MANIFESTS[@]}"; do safe_delete "$f"; done

info "→ app2"
for f in "${APP2_MANIFESTS[@]}"; do safe_delete "$f"; done

info "→ app1"
for f in "${APP1_MANIFESTS[@]}"; do safe_delete "$f"; done

# 3. Namespace
stage "Removing namespace ${NAMESPACE}"
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --grace-period=0 2>/dev/null || true

# Force-remove finalizers if namespace hangs
timeout=120
start_time=$(date +%s)
while kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; do
  elapsed=$(( $(date +%s) - start_time ))
  if (( elapsed > timeout )); then
    warn "Namespace still terminating after ${timeout}s – forcing finalizer removal"
    kubectl get ns "${NAMESPACE}" -o json \
      | jq '.spec.finalizers = []' \
      | kubectl replace --raw "/api/v1/namespaces/${NAMESPACE}/finalize" -f - 2>/dev/null || true
    break
  fi
  info "Namespace still terminating... (${elapsed}s)"
  sleep 6
done

if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
  success "Namespace '${NAMESPACE}' removed."
else
  warn "Namespace '${NAMESPACE}' may still exist – check manually."
fi

# 4. ECR cleanup
stage "Cleaning ECR repositories (${APPS[*]})"

for app in "${APPS[@]}"; do
  info "Repository: ${app}"

  if aws ecr describe-repositories --repository-names "$app" --region "$AWS_REGION" >/dev/null 2>&1; then
    image_ids=$(aws ecr list-images \
      --repository-name "$app" \
      --region "$AWS_REGION" \
      --query 'imageIds[*]' --output json)

    if [[ "$image_ids" != "[]" ]]; then
      info "Deleting images..."
      aws ecr batch-delete-image \
        --repository-name "$app" \
        --region "$AWS_REGION" \
        --image-ids "$image_ids" >/dev/null
      success "Images removed."
    fi

    info "Deleting repository..."
    aws ecr delete-repository \
      --repository-name "$app" \
      --region "$AWS_REGION" \
      --force >/dev/null
    success "Repository '${app}' deleted."
  else
    info "Repository '${app}' does not exist – skipping."
  fi
done

# ──────────────────────────────────────────────────────────────────────────────
# Final summary
# ──────────────────────────────────────────────────────────────────────────────
hr
success "Task 2 cleanup finished"
success "• Namespace '${NAMESPACE}' removed"
success "• All application resources deleted"
success "• ECR repositories cleaned: ${APPS[*]}"
hr