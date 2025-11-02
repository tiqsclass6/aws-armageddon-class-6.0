#!/usr/bin/env bash
# =============================================================================
# destroy-all-apps.sh — Tear down Death Row EKS demo
#
# This script will:
#   1. Delete all K8s resources for app1/app2/app3
#   2. Optionally delete ECR repos (app1, app2, app3)
#   3. Optionally delete the EKS cluster (via eksctl)
#
# DANGER: Deleting the cluster will remove the control plane + nodegroup
# =============================================================================

set -euo pipefail

# -------------------------------
# Configuration (edit these)
# -------------------------------
MANIFEST_DIR="manifests"
NAMESPACE="${NAMESPACE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-task-2}"

# Repos we created in deploy script
ECR_REPOS=("app1" "app2" "app3")

# K8s YAMLs we want to delete
YAML_FILES=(
  "$MANIFEST_DIR/app1-deployment.yaml"
  "$MANIFEST_DIR/app1-service.yaml"
  "$MANIFEST_DIR/app1-hpa.yaml"
  "$MANIFEST_DIR/app2-deployment.yaml"
  "$MANIFEST_DIR/app2-service.yaml"
  "$MANIFEST_DIR/app2-hpa.yaml"
  "$MANIFEST_DIR/app3-deployment.yaml"
  "$MANIFEST_DIR/app3-service.yaml"
  "$MANIFEST_DIR/app3-hpa.yaml"
)

# -------------------------------
# Helpers
# -------------------------------
info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# -------------------------------
# Step 0: Tool checks
# -------------------------------
command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed."
command -v aws     >/dev/null 2>&1 && AWS_AVAILABLE=true  || AWS_AVAILABLE=false
command -v eksctl  >/dev/null 2>&1 && EKSCTL_AVAILABLE=true || EKSCTL_AVAILABLE=false

AWS_ACCOUNT_ID="UNKNOWN"
if [[ "$AWS_AVAILABLE" == true ]]; then
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "UNKNOWN")
fi

echo
echo "======================================================================"
echo "  WARNING: THIS WILL DELETE ALL DEATH ROW RECORDS KUBERNETES RESOURCES"
echo "----------------------------------------------------------------------"
echo "  Namespace: $NAMESPACE"
echo "  Manifests: $MANIFEST_DIR"
echo "  ECR repos: ${ECR_REPOS[*]}"
echo "  EKS cluster (optional): $CLUSTER_NAME in $AWS_REGION"
echo "================================================================"
echo
read -p "Type 'DESTROY' to delete K8s + ECR resources: " CONFIRM
[[ "$CONFIRM" == "DESTROY" ]] || error "Aborted. Confirmation not received."

# -------------------------------
# Step 1: Delete Kubernetes resources
# -------------------------------
info "Deleting Kubernetes resources in namespace '$NAMESPACE'..."

for file in "${YAML_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    info "kubectl delete -f $file --ignore-not-found=true --namespace=$NAMESPACE"
    kubectl delete -f "$file" --ignore-not-found=true --namespace="$NAMESPACE" || \
      warn "Failed to delete $file (may already be gone)"
  else
    warn "File not found: $file"
  fi
done

# Wait for pods to terminate (don’t fail if they’re already gone)
info "Waiting for pods to terminate..."
kubectl wait --for=delete pod -l 'app in (app1,app2,app3)' \
  --namespace="$NAMESPACE" --timeout=120s 2>/dev/null || true

# Final K8s check
if kubectl get deploy,svc,hpa -l 'app in (app1,app2,app3)' --namespace="$NAMESPACE" &>/dev/null; then
  warn "Some app resources may still exist. Check with:"
  warn "  kubectl get all -l 'app in (app1,app2,app3)' -n $NAMESPACE"
else
  success "All Death Row app Kubernetes resources removed."
fi

# ---------------------
# Step 2: ECR cleanup
# ---------------------
if [[ "$AWS_AVAILABLE" == true ]]; then
  info "Cleaning up ECR repositories in $AWS_REGION ..."
  for repo in "${ECR_REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &>/dev/null; then
      info "Deleting ECR repo: $repo"
      aws ecr delete-repository --repository-name "$repo" --force --region "$AWS_REGION" || \
        warn "Failed to delete ECR repo: $repo"
    else
      warn "ECR repo not found: $repo"
    fi
  done
  success "ECR cleanup complete."
else
  warn "AWS CLI not available — skipping ECR cleanup."
fi

# -------------------------------------------------
# Step 3: Ask if we should delete the EKS cluster
# -------------------------------------------------
echo
read -p "Do you ALSO want to delete the EKS cluster '$CLUSTER_NAME' (Y/N)? " DEL_CLUSTER
DEL_CLUSTER=${DEL_CLUSTER:-N}

if [[ "$DEL_CLUSTER" =~ ^[Yy]$ ]]; then
  if [[ "$EKSCTL_AVAILABLE" != true ]]; then
    error "eksctl is not installed, cannot delete cluster. Install from https://eksctl.io/"
  fi

  echo
  echo "========================================================================"
  echo "  FINAL WARNING: This will delete the EKS cluster '$CLUSTER_NAME'"
  echo "  and its nodegroup(s). This action CANNOT be undone."
  echo "========================================================================"
  read -p "Type the cluster name '$CLUSTER_NAME' to confirm: " CL_CONFIRM
  [[ "$CL_CONFIRM" == "$CLUSTER_NAME" ]] || error "Cluster deletion aborted — name mismatch."

  info "Deleting EKS cluster '$CLUSTER_NAME' in region '$AWS_REGION'..."
  eksctl delete cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --wait
  success "EKS cluster '$CLUSTER_NAME' deleted."
else
  info "Cluster deletion skipped."
fi

# ------
# Done
# ------
echo
success "DESTROY COMPLETE."
echo "You can re-deploy with: ./deploy-all-apps.sh"
