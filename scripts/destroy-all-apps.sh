#!/usr/bin/env bash
# =============================================================================
# destroy-all-apps.sh — Task-2 EKS Cleanup Script
# -----------------------------------------------------------------------------
# Deletes Kubernetes app resources, IRSA (IAM Role + ServiceAccount), ECR repos,
# and optionally the EKS cluster. Commands are described inline for clarity.
# =============================================================================

set -euo pipefail

# -------------------------------
# 🧩 1. Configuration
# -------------------------------
AWS_REGION="us-east-1"                 # Your AWS region
CLUSTER_NAME="task-2"                  # EKS cluster name
NAMESPACE="task2-ns"                   # Namespace where apps live
SERVICE_ACCOUNT_NAME="task2-sa"        # IRSA-linked service account name
IRSA_ROLE_NAME="task2-irsa-s3-role"    # IRSA role created by deploy script

# Manifests directory and app names (must match deploy-all-apps.sh)
MANIFEST_DIR="manifests"
APPS=("app1" "app2" "app3")

# ECR repos to delete (must match deploy-all-apps.sh)
ECR_REPOS=("app1" "app2" "app3")

# -------------------------------
# 🎨 2. Helper functions
# -------------------------------
info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || error "Required tool '$1' not found."; }

# -------------------------------
# 🔧 3. Tool checks
# -------------------------------
need kubectl
need eksctl
need aws

# -------------------------------
# ⚠️ 4. Safety confirmation
# -------------------------------
echo
echo "This will remove:"
echo "  • K8s resources in namespace: $NAMESPACE"
echo "  • IRSA: ServiceAccount '$SERVICE_ACCOUNT_NAME' and IAM Role '$IRSA_ROLE_NAME'"
echo "  • ECR repositories: ${ECR_REPOS[*]}"
echo "  • (Optional) EKS cluster: $CLUSTER_NAME in $AWS_REGION"
echo
read -p "Type 'DESTROY' to proceed: " CONFIRM
[[ "$CONFIRM" == "DESTROY" ]] || error "Aborted."

# -------------------------------
# 🔐 5. Ensure kubeconfig and context
# -------------------------------
info "Setting kubectl context to the EKS cluster (so deletes work against the right cluster)..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# -------------------------------
# 🧹 6. Delete Kubernetes resources
# -------------------------------
info "Deleting Kubernetes resources applied by manifests (deployments/services/HPAs)..."
for app in "${APPS[@]}"; do
  for kind in deployment service hpa; do
    file="${MANIFEST_DIR}/${app}-${kind}.yaml"
    [[ -f "$file" ]] || continue
    info "kubectl delete -f $file --namespace $NAMESPACE --ignore-not-found=true"
    kubectl delete -f "$file" --namespace "$NAMESPACE" --ignore-not-found=true || warn "Delete may have already occurred for $file"
  done
done

info "Optionally deleting the entire namespace to remove any leftover resources..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true || true

# Wait briefly for pods/ELBs to drain (best effort)
info "Waiting up to 120s for pods and services to terminate (best-effort)..."
kubectl wait --for=delete pod -l "app in (app1,app2,app3)" -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

# -------------------------------
# 🧷 7. IRSA cleanup (ServiceAccount + IAM Role)
# -------------------------------
info "Removing IRSA binding (eksctl manages both the K8s SA and IAM role binding)..."
info "eksctl delete iamserviceaccount --name $SERVICE_ACCOUNT_NAME --namespace $NAMESPACE --cluster $CLUSTER_NAME --region $AWS_REGION"
eksctl delete iamserviceaccount \
  --name "$SERVICE_ACCOUNT_NAME" \
  --namespace "$NAMESPACE" \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --wait || warn "IRSA iamserviceaccount deletion encountered an issue (may already be removed)."

# Note: The above removes the IAM role created by eksctl for this SA.
# If you created additional custom IAM policies/roles, delete or detach them here.

# -------------------------------
# 🗑️ 8. ECR repositories cleanup
# -------------------------------
info "Deleting ECR repositories (forces deletion of all images too)..."
for repo in "${ECR_REPOS[@]}"; do
  info "aws ecr delete-repository --repository-name $repo --force --region $AWS_REGION"
  aws ecr delete-repository \
    --repository-name "$repo" \
    --force \
    --region "$AWS_REGION" \
    >/dev/null 2>&1 || warn "Repo '$repo' may already be gone or in use."
done
success "ECR cleanup complete."

# -------------------------------
# 🧨 9. Optionally delete the EKS cluster
# -------------------------------
read -p "Also delete the EKS cluster '$CLUSTER_NAME'? (y/N): " DEL_CLUSTER
if [[ "${DEL_CLUSTER:-N}" =~ ^[Yy]$ ]]; then
  echo
  echo "FINAL WARNING: Deleting the EKS cluster will also remove its nodegroups and control plane."
  read -p "Type the cluster name '$CLUSTER_NAME' to confirm: " CL_CONFIRM
  [[ "$CL_CONFIRM" == "$CLUSTER_NAME" ]] || error "Cluster deletion aborted — name mismatch."

  info "Deleting EKS cluster (this may take 10–20 minutes)..."
  info "eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION --wait"
  eksctl delete cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --wait

  # Optional: best-effort OIDC disassociation if any OIDC provider lingers
  info "Attempting best-effort OIDC disassociation (safe to ignore if already gone)..."
  eksctl utils disassociate-iam-oidc-provider \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" || true

  success "Cluster '$CLUSTER_NAME' deleted."
else
  info "Cluster deletion skipped."
fi

# -------------------------------
# ✅ 10. Completion
# -------------------------------
success "Destroy completed. Environment is cleaned."
echo "You can redeploy with: ./deploy-all-apps.sh"
