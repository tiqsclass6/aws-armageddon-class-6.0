#!/usr/bin/env bash
# =============================================================================
# deploy-all-apps.sh — Build, Push, Deploy Death Row EKS Demo
# Now with:
#   - STS preflight check (fails fast if no AWS network/creds)
#   - OIDC association for addons
# =============================================================================

set -euo pipefail

# -------------------------------
# 1.) Configuration Section
# -------------------------------
AWS_REGION="${AWS_REGION:-us-east-1}"        # Update Region Here
CLUSTER_NAME="${CLUSTER_NAME:-task-2}"       # Update Cluster Name
MANIFEST_DIR="${MANIFEST_DIR:-manifests}"
NAMESPACE="${NAMESPACE:-default}"
K8S_VALIDATE="${K8S_VALIDATE:-true}"
SKIP_BUILD="${SKIP_BUILD:-0}"

APPS=("app1" "app2" "app3")
PORTS=(8081 8082 8083)

# -------------------------------
# 1.a) Helpers
# -------------------------------
info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# -------------------------------
# 2.) Tool checks
# -------------------------------
command -v aws     >/dev/null 2>&1 || error "AWS CLI not found."
command -v docker  >/dev/null 2>&1 || error "Docker not found."
command -v kubectl >/dev/null 2>&1 || error "kubectl not found."
command -v eksctl  >/dev/null 2>&1 || error "eksctl not found."

# ------------------------------------------------------
# 3.) STS preflight — FAIL FAST if we can't talk to AWS
# ------------------------------------------------------
info "Checking AWS STS connectivity..."
if ! AWS_STS_JSON=$(aws sts get-caller-identity --output json --region "$AWS_REGION" 2>/dev/null); then
  error "Cannot reach AWS STS in region '$AWS_REGION'.
Make sure:
  - You have valid AWS credentials (env vars, profile, or IAM role)
  - This machine has network access to https://sts.$AWS_REGION.amazonaws.com
  - If you're in a private subnet, add NAT or run this script from a host with internet.
Aborting deploy."
fi

AWS_ACCOUNT_ID=$(echo "$AWS_STS_JSON" | jq -r '.Account' 2>/dev/null || true)
if [[ -z "${AWS_ACCOUNT_ID:-}" || "$AWS_ACCOUNT_ID" == "null" ]]; then
  error "STS returned no account ID — cannot continue."
fi

ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
info "Using AWS Account: $AWS_ACCOUNT_ID"
info "Region: $AWS_REGION"
info "Cluster: $CLUSTER_NAME"

# -------------------------------
# 4.) Ensure EKS cluster exists
# -------------------------------
if eksctl get cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  info "EKS cluster '$CLUSTER_NAME' already exists."
else
  warn "EKS cluster '$CLUSTER_NAME' not found — creating it now..."
  eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --version 1.30 \
    --nodegroup-name worker-nodes \
    --node-type t3.medium \
    --nodes 3 \
    --nodes-min 3 \
    --nodes-max 6 \
    --managed
  success "EKS cluster '$CLUSTER_NAME' created."
fi

# -------------------------------
# 5.) Update kubeconfig
# -------------------------------
info "Updating kubeconfig for cluster '$CLUSTER_NAME'..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
kubectl get nodes || warn "Cluster may still be starting, continuing..."

# -------------------------------
# 6.) Associate IAM OIDC provider
# -------------------------------
info "Ensuring IAM OIDC provider is associated..."
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --approve || true
success "OIDC association step complete (or already present)."

# -------------------------------
# 7.) ECR login
# -------------------------------
if [[ "$SKIP_BUILD" -ne 1 ]]; then
  info "Logging into ECR at $ECR_BASE ..."
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$ECR_BASE"
else
  info "SKIP_BUILD=1 → skipping ECR login and image builds."
fi

# -------------------------------
# 8.) Ensure ECR repos
# -------------------------------
ensure_repo() {
  local repo="$1"
  if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    info "Creating ECR repo: $repo"
    aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" >/dev/null
  else
    info "ECR repo '$repo' exists"
  fi
}
for repo in "${APPS[@]}"; do
  ensure_repo "$repo"
done
success "ECR repositories ready."

# --------------------------------------
# 9.) Build & push Docker Custom images
# --------------------------------------
if [[ "$SKIP_BUILD" -ne 1 ]]; then
  for i in "${!APPS[@]}"; do
    app="${APPS[$i]}"
    image="${ECR_BASE}/${app}:latest"

    info "Building image for ${app}..."
    (
      cd "$app"
      docker build -t "$app:latest" .
    )

    info "Tagging ${app} → ${image}"
    docker tag "$app:latest" "$image"

    info "Pushing ${app} → ${image}"
    docker push "$image"
  done
  success "All images built and pushed."
else
  info "SKIP_BUILD=1 → assuming images already in ECR."
fi

# ---------------------------------
# 10.) Apply Kubernetes manifests
# ---------------------------------
info "Applying manifests from '${MANIFEST_DIR}'..."
for app in "${APPS[@]}"; do
  for kind in deployment service hpa; do
    file="${MANIFEST_DIR}/${app}-${kind}.yaml"
    [[ -f "$file" ]] || continue

    if [[ "$K8S_VALIDATE" == "false" ]]; then
      info "kubectl apply --validate=false -f $file"
      kubectl apply --validate=false -f "$file" || warn "Failed to apply $file"
    else
      info "kubectl apply -f $file"
      kubectl apply -f "$file" || warn "Failed to apply $file (try K8S_VALIDATE=false)"
    fi
  done
done
success "Kubernetes manifests applied."

# -------------------------------
# 11.) Restart deployments
# -------------------------------
for app in "${APPS[@]}"; do
  kubectl rollout restart deploy/"$app" || true
done

# -------------------------------
# 12. Print LoadBalancer URLs
# -------------------------------
info "Waiting for external LoadBalancer addresses..."
printf "%-8s %-25s %-8s %s\n" "APP" "SERVICE" "PORT" "URL"
printf "%-8s %-25s %-8s %s\n" "--------" "------------------------" "--------" "-------------------------"

for app in "${APPS[@]}"; do
  svc="${app}-service"
  external=""
  port=$(kubectl get svc "$svc" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")

  for _ in {1..60}; do
    external=$(kubectl get svc "$svc" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    [[ -z "$external" ]] && external=$(kubectl get svc "$svc" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    [[ -n "$external" && "$external" != "<pending>" ]] && break
    sleep 5
  done

  if [[ -z "$external" || "$external" == "<pending>" ]]; then
    printf "%-8s %-25s %-8s %s\n" "$app" "$svc" "${port:-?}" "PENDING"
    continue
  fi

  if [[ "$port" == "80" || "$port" == "443" || -z "$port" ]]; then
    url="http://${external}"
  else
    url="http://${external}:${port}"
  fi

  printf "%-8s %-25s %-8s %s\n" "$app" "$svc" "${port:-?}" "$url"
done

success "Deployment is complete .."
echo "To tear down everything, run: ./destroy-all-apps.sh"