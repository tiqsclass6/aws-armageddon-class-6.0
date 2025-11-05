#!/usr/bin/env bash
# =============================================================================
# deploy-all-apps.sh — Task-2 EKS Deployment Script
# -----------------------------------------------------------------------------
# Builds Docker images, pushes them to ECR, creates/updates an EKS cluster,
# sets up OIDC and IRSA (for IAM Roles for Service Accounts),
# applies Kubernetes manifests, and prints full app URLs.
# =============================================================================

set -euo pipefail

# -------------------------------
# 1.) Configuration
# -------------------------------
AWS_REGION="us-east-1"
CLUSTER_NAME="task-2"
NODEGROUP_NAME="task-2-ng"
CLUSTER_VERSION="1.33"
NAMESPACE="task2-ns"

SERVICE_ACCOUNT_NAME="task2-sa"
IRSA_ROLE_NAME="task2-irsa-s3-role"
IRSA_POLICY_ARN="arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"

MANIFEST_DIR="manifests"
APPS=("app1" "app2" "app3")

# -------------------------------
# 2.) Helper functions
# -------------------------------
info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# -------------------------------
# 3.) AWS STS connectivity check
# -------------------------------
info "Checking AWS STS connectivity..."
aws sts get-caller-identity --region "$AWS_REGION" >/dev/null \
  || error "AWS STS unreachable — check credentials or network."

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
info "Authenticated with AWS Account: $AWS_ACCOUNT_ID"

# -------------------------------
# 4.) Create or verify EKS cluster
# -------------------------------
if eksctl get cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  info "EKS cluster '$CLUSTER_NAME' already exists."
else
  info "Creating new EKS cluster '$CLUSTER_NAME' (version $CLUSTER_VERSION)..."
  eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --version "$CLUSTER_VERSION" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --node-type t3.medium \
    --nodes 3 \
    --nodes-min 3 \
    --nodes-max 6 \
    --managed
  success "Cluster '$CLUSTER_NAME' created successfully."
fi

# -------------------------------
# 5.) Configure kubectl
# -------------------------------
info "Updating kubeconfig for kubectl access..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# -------------------------------
# 6.) Enable IAM OIDC provider
# -------------------------------
info "Associating IAM OIDC provider with cluster..."
eksctl utils associate-iam-oidc-provider \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --approve || true
success "OIDC provider configured."

# -------------------------------
# 7.) Create IRSA (IAM Role + SA)
# -------------------------------
info "Creating IRSA role '$IRSA_ROLE_NAME' and service account '$SERVICE_ACCOUNT_NAME'..."
eksctl create iamserviceaccount \
  --name "$SERVICE_ACCOUNT_NAME" \
  --namespace "$NAMESPACE" \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --role-name "$IRSA_ROLE_NAME" \
  --attach-policy-arn "$IRSA_POLICY_ARN" \
  --approve || true
success "IRSA role and service account created."

# -------------------------------
# 8.) Log into ECR
# -------------------------------
info "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_BASE"

# -------------------------------
# 9.) Ensure ECR repos exist
# -------------------------------
for app in "${APPS[@]}"; do
  if ! aws ecr describe-repositories --repository-names "$app" --region "$AWS_REGION" >/dev/null 2>&1; then
    info "Creating ECR repo for $app..."
    aws ecr create-repository --repository-name "$app" --region "$AWS_REGION" >/dev/null
  else
    info "ECR repo '$app' already exists."
  fi
done
success "ECR repositories verified."

# -------------------------------
# 10.) Build and push app images
# -------------------------------
for app in "${APPS[@]}"; do
  IMAGE="${ECR_BASE}/${app}:latest"

  info "Building Docker image for $app..."
  (cd "$app" && docker build -t "$app:latest" .)

  info "Tagging image $app → $IMAGE"
  docker tag "$app:latest" "$IMAGE"

  info "Pushing $app image to ECR..."
  docker push "$IMAGE"
done
success "All app images built and pushed to ECR."

# -------------------------------
# 11.) Apply Kubernetes manifests
# -------------------------------
info "Deploying manifests to namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

for app in "${APPS[@]}"; do
  for kind in deployment service hpa; do
    file="${MANIFEST_DIR}/${app}-${kind}.yaml"
    [[ -f "$file" ]] || continue
    info "Applying $file..."
    kubectl apply -f "$file" --namespace "$NAMESPACE"
  done
done
success "All manifests applied successfully."

# -------------------------------
# 12.) Print full application URLs
# -------------------------------
info "Retrieving external LoadBalancer URLs..."
printf "\n%-8s %-30s %-8s %-50s\n" "APP" "SERVICE" "PORT" "FULL URL"
printf "%-8s %-30s %-8s %-50s\n" "--------" "------------------------------" "--------" "--------------------------------------------------"

for app in "${APPS[@]}"; do
  svc="${app}-service"
  port=$(kubectl get svc "$svc" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
  host=$(kubectl get svc "$svc" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  [[ -z "$host" ]] && host=$(kubectl get svc "$svc" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

  if [[ -z "$host" || "$host" == "<pending>" ]]; then
    printf "%-8s %-30s %-8s %-50s\n" "$app" "$svc" "$port" "LoadBalancer pending..."
  else
    url="http://${host}:${port}"
    printf "%-8s %-30s %-8s %-50s\n" "$app" "$svc" "$port" "$url"
  fi
done

# -------------------------------
# 13.) Completion message
# -------------------------------
success "Deployment complete!"
echo "Access your apps at the URLs above."
echo "To clean up, run: ./destroy-all-apps.sh"
