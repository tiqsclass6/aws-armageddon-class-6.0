#!/usr/bin/env bash
# =============================================================================
# Task-2 EKS (3 apps behind ONE shared ALB Ingress)
# -----------------------------------------------------------------------------
# Features (production-grade deploy script):
#   - Optional build/tag/push to ECR (safe when app dirs are missing)
#   - Dynamic ingress subnet patch from Terraform output (optional)
#   - Rollout gating + in-cluster health checks before success
#   - Optional kubeconfig update (aws eks update-kubeconfig)
#
# Usage:
#   See usage function or run with -h/--help for details.
#
# Assumptions:
#   - AWS Load Balancer Controller is installed and running in the cluster.
#   - kubectl context is set up with access to the cluster (or use --update-kubeconfig).
#   - Docker is installed locally if not skipping build/push.
#
# Notes:
#   - Health check hits service DNS from inside cluster using a curl pod.
#   - If your nodes cannot pull public images, set CURL_IMAGE to an ECR-hosted curl image.
# =============================================================================

set -euo pipefail

# -------------------------------
# Defaults / Config
# -------------------------------
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-demo}"                             # optional; used only for kubeconfig update if provided
NAMESPACE="${NAMESPACE:-task2-ns}"
MANIFEST_DIR="${MANIFEST_DIR:-manifests}"
SUBNETS_FILE="${SUBNETS_FILE:-/scripts/public-subnets.json}"     # terraform output file shaped like: {"value":["subnet-..","subnet-.."]}
INGRESS_NAME="${INGRESS_NAME:-apps-shared-ingress}"

ALB_CONTROLLER_NS="${ALB_CONTROLLER_NS:-kube-system}"
ALB_CONTROLLER_DEPLOY="${ALB_CONTROLLER_DEPLOY:-aws-load-balancer-controller}"

APPS=(app1 app2 app3)
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Docker build contexts
APPS_DIR="${APPS_DIR:-/scripts/apps}"                            # default location for app sources: ./apps/app1/Dockerfile etc.
FORCE_BUILD=false                                                # if true: missing contexts => hard fail

# Health endpoints (override via env)
APP1_HEALTH_PATH="${APP1_HEALTH_PATH:-/health}"
APP2_HEALTH_PATH="${APP2_HEALTH_PATH:-/health}"
APP3_HEALTH_PATH="${APP3_HEALTH_PATH:-/health}"

# Curl image (override if you need a private/ECR-hosted image)
CURL_IMAGE="${CURL_IMAGE:-curlimages/curl:8.6.0}"

# Timeouts
WAIT_TIMEOUT_CONTROLLER="${WAIT_TIMEOUT_CONTROLLER:-300s}"
WAIT_TIMEOUT_ROLLOUT="${WAIT_TIMEOUT_ROLLOUT:-600s}"
WAIT_TIMEOUT_INGRESS="${WAIT_TIMEOUT_INGRESS:-600s}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-180}"
HEALTH_INTERVAL_SECONDS="${HEALTH_INTERVAL_SECONDS:-5}"
HEALTH_MAX_TIME_PER_REQ="${HEALTH_MAX_TIME_PER_REQ:-3}"

# Modes / flags
DRY_RUN=false
DESTROY=false
SKIP_ECR=false
SKIP_BUILD=false
SKIP_PUSH=false
SKIP_SET_IMAGES=false
SKIP_SUBNET_PATCH=false
SKIP_HEALTH=false
UPDATE_KUBECONFIG=false

# -------------------------------
# UX helpers
# -------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[1;36m'; MAGENTA='\033[1;35m'; NC='\033[0m'
ts() { date +"%Y-%m-%d %H:%M:%S %Z"; }
hr() { printf "${MAGENTA}%0.s=" {1..110}; printf "${NC}\n"; }
stage(){ hr; echo -e "${CYAN}==> [$(ts)] $1${NC}"; hr; }
info(){ echo -e "${BLUE}[INFO]${NC}  $*"; }
ok(){ echo -e "${GREEN}[OK]${NC}    $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC}  $*"; }
die(){ echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [options]

Core:
  --manifests DIR           Manifests directory (default: ${MANIFEST_DIR})
  --namespace NS            Namespace (default: ${NAMESPACE})
  --ingress NAME            Ingress name (default: ${INGRESS_NAME})
  --dry-run                 kubectl apply --dry-run=server
  --destroy                 delete resources defined in manifests

ECR / Images:
  --region REGION           AWS region (default: ${AWS_REGION})
  --image-tag TAG           Image tag (default: ${IMAGE_TAG})
  --apps-dir DIR            App sources directory (default: ${APPS_DIR})
  --force-build             Fail if Docker contexts are missing

Skip switches:
  --skip-ecr                Skip all ECR actions (sts/login/repos/build/push)
  --skip-build              Skip local docker builds
  --skip-push               Skip docker push to ECR
  --skip-set-images         Do not run kubectl set image (deploy uses YAML images)
  --skip-subnet-patch       Do not annotate ingress subnets
  --skip-health             Do not run in-cluster health checks

Subnet patch:
  --subnets-file FILE       Terraform output json file (default: ${SUBNETS_FILE})

Cluster access:
  --update-kubeconfig       Run: aws eks update-kubeconfig (requires --cluster-name)
  --cluster-name NAME       Cluster name for kubeconfig update

Env overrides (health + curl image):
  APP1_HEALTH_PATH=/health  APP2_HEALTH_PATH=/health  APP3_HEALTH_PATH=/health
  CURL_IMAGE=<image>        (use ECR-hosted curl if public pulls blocked)

Examples:
  # Deploy-only (no build/push), still patches ingress subnets + health checks:
  $0 --skip-build --skip-push

  # Build from ./apps/app1 ./apps/app2 ./apps/app3:
  APPS_DIR=apps $0

  # Per-app override:
  APP1_DIR=./flask/app1 APP2_DIR=./flask/app2 APP3_DIR=./flask/app3 $0

EOF
}

# -------------------------------
# Arg parsing
# -------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifests) MANIFEST_DIR="$2"; shift 2;;
    --namespace) NAMESPACE="$2"; shift 2;;
    --ingress) INGRESS_NAME="$2"; shift 2;;
    --subnets-file) SUBNETS_FILE="$2"; shift 2;;
    --region) AWS_REGION="$2"; shift 2;;
    --image-tag) IMAGE_TAG="$2"; shift 2;;
    --apps-dir) APPS_DIR="$2"; shift 2;;
    --force-build) FORCE_BUILD=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    --destroy) DESTROY=true; shift;;
    --skip-ecr) SKIP_ECR=true; shift;;
    --skip-build) SKIP_BUILD=true; shift;;
    --skip-push) SKIP_PUSH=true; shift;;
    --skip-set-images) SKIP_SET_IMAGES=true; shift;;
    --skip-subnet-patch) SKIP_SUBNET_PATCH=true; shift;;
    --skip-health) SKIP_HEALTH=true; shift;;
    --update-kubeconfig) UPDATE_KUBECONFIG=true; shift;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1";;
  esac
done

# -------------------------------
# Tooling helpers
# -------------------------------
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

kubectl_apply() {
  local f="$1"
  if $DRY_RUN; then kubectl apply --dry-run=server -f "$f"; else kubectl apply -f "$f"; fi
}

kubectl_delete() {
  local f="$1"
  if $DRY_RUN; then kubectl delete --dry-run=server -f "$f" >/dev/null 2>&1 || true
  else kubectl delete -f "$f" >/dev/null 2>&1 || true
  fi
}

# Strong diagnostics on error
LAST_CMD=""; LAST_LINE=0
trap 'LAST_CMD="$BASH_COMMAND"; LAST_LINE=$LINENO' DEBUG
on_err() {
  local ec=$?
  hr
  echo -e "${RED}[ERROR]${NC} Failed (exit code: $ec)"
  echo -e "${RED}[ERROR]${NC} Line: $LAST_LINE"
  echo -e "${RED}[ERROR]${NC} Cmd : $LAST_CMD"
  hr

  warn "Namespace diagnostics: $NAMESPACE"
  kubectl -n "$NAMESPACE" get pods -o wide || true
  kubectl -n "$NAMESPACE" get svc -o wide || true
  kubectl -n "$NAMESPACE" get endpointslice 2>/dev/null | head -n 50 || true
  kubectl -n "$NAMESPACE" get events --sort-by='.lastTimestamp' | tail -n 120 || true
  kubectl -n "$NAMESPACE" get ingress -o wide || true
  kubectl -n "$NAMESPACE" describe ingress "$INGRESS_NAME" || true

  warn "ALB controller diagnostics (kube-system)"
  kubectl -n "$ALB_CONTROLLER_NS" get deploy "$ALB_CONTROLLER_DEPLOY" -o wide || true
  kubectl -n "$ALB_CONTROLLER_NS" get pods -l app.kubernetes.io/name=aws-load-balancer-controller -o wide || true
  kubectl -n "$ALB_CONTROLLER_NS" logs deploy/"$ALB_CONTROLLER_DEPLOY" --tail=200 || true

  hr
  exit "$ec"
}
trap on_err ERR

# -------------------------------
# App directory resolution
# -------------------------------
app_context_dir() {
  local app="$1"
  local upper
  upper="$(echo "$app" | tr '[:lower:]' '[:upper:]')"            # app1 -> APP1
  local var="${upper}_DIR"                                       # APP1_DIR
  local override="${!var:-}"
  if [[ -n "$override" ]]; then
    echo "$override"
  else
    echo "${APPS_DIR}/${app}"
  fi
}

# -------------------------------
# Health check (in-cluster via Service DNS)
# -------------------------------
health_check_service() {
  local svc="$1" port="$2" path="$3"
  local end=$(( $(date +%s) + HEALTH_TIMEOUT_SECONDS ))
  local pod="curlcheck-$RANDOM"

  stage "Health check: http://${svc}:${port}${path} (in-cluster)"

  while true; do
    if [[ $(date +%s) -gt $end ]]; then
      die "Health check FAILED for http://${svc}:${port}${path} after ${HEALTH_TIMEOUT_SECONDS}s"
    fi

    set +e
    kubectl -n "$NAMESPACE" run "$pod" --rm -i --restart=Never \
      --image="$CURL_IMAGE" \
      --command -- sh -c \
      "curl -fsS --max-time ${HEALTH_MAX_TIME_PER_REQ} http://${svc}:${port}${path} >/dev/null" \
      >/dev/null 2>&1
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
      ok "Health OK: http://${svc}:${port}${path}"
      break
    fi

    info "Not healthy yet; retrying in ${HEALTH_INTERVAL_SECONDS}s..."
    sleep "$HEALTH_INTERVAL_SECONDS"
  done
}

# -------------------------------
# Start: validation
# -------------------------------
stage "Validation"
require_cmd kubectl
require_cmd jq

[[ -d "$MANIFEST_DIR" ]] || die "Manifests directory not found: $MANIFEST_DIR"

NS_FILE="$MANIFEST_DIR/apps-namespace.yaml"
INGRESS_FILE="$MANIFEST_DIR/apps-ingress.yaml"

FILES=(
  "$NS_FILE"
  "$MANIFEST_DIR/app1-deployment.yaml" "$MANIFEST_DIR/app1-service.yaml" "$MANIFEST_DIR/app1-hpa.yaml"
  "$MANIFEST_DIR/app2-deployment.yaml" "$MANIFEST_DIR/app2-service.yaml" "$MANIFEST_DIR/app2-hpa.yaml"
  "$MANIFEST_DIR/app3-deployment.yaml" "$MANIFEST_DIR/app3-service.yaml" "$MANIFEST_DIR/app3-hpa.yaml"
  "$INGRESS_FILE"
)
for f in "${FILES[@]}"; do [[ -f "$f" ]] || die "Missing manifest: $f"; done

info "Region               : $AWS_REGION"
info "Cluster name         : ${CLUSTER_NAME:-<not set>}"
info "Namespace            : $NAMESPACE"
info "Manifests directory  : $MANIFEST_DIR"
info "Ingress              : $INGRESS_NAME"
info "Image tag            : $IMAGE_TAG"
info "Dry-run              : $DRY_RUN"
info "Destroy              : $DESTROY"
info "Skip ECR             : $SKIP_ECR"
info "Skip build           : $SKIP_BUILD"
info "Skip push            : $SKIP_PUSH"
info "Skip set-images      : $SKIP_SET_IMAGES"
info "Skip subnet patch    : $SKIP_SUBNET_PATCH"
info "Skip health          : $SKIP_HEALTH"

# Optional kubeconfig update
if $UPDATE_KUBECONFIG; then
  [[ -n "$CLUSTER_NAME" ]] || die "--update-kubeconfig requires --cluster-name"
  require_cmd aws
  stage "Update kubeconfig"
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
  ok "kubeconfig updated for cluster: $CLUSTER_NAME"
fi

kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach cluster (check kubeconfig/context)"

# -------------------------------
# Destroy mode
# -------------------------------
if $DESTROY; then
  stage "Destroying manifests"
  kubectl_delete "$INGRESS_FILE"

  kubectl_delete "$MANIFEST_DIR/app3-hpa.yaml"
  kubectl_delete "$MANIFEST_DIR/app3-service.yaml"
  kubectl_delete "$MANIFEST_DIR/app3-deployment.yaml"

  kubectl_delete "$MANIFEST_DIR/app2-hpa.yaml"
  kubectl_delete "$MANIFEST_DIR/app2-service.yaml"
  kubectl_delete "$MANIFEST_DIR/app2-deployment.yaml"

  kubectl_delete "$MANIFEST_DIR/app1-hpa.yaml"
  kubectl_delete "$MANIFEST_DIR/app1-service.yaml"
  kubectl_delete "$MANIFEST_DIR/app1-deployment.yaml"

  kubectl_delete "$NS_FILE"
  ok "Destroy complete."
  exit 0
fi

# -------------------------------
# Preflight: ALB controller
# -------------------------------
stage "Preflight: AWS Load Balancer Controller"
kubectl -n "$ALB_CONTROLLER_NS" rollout status "deployment/$ALB_CONTROLLER_DEPLOY" --timeout="$WAIT_TIMEOUT_CONTROLLER"
ok "AWS Load Balancer Controller is ready."

# -------------------------------
# ECR: login / repos / build / push (optional + safe)
# -------------------------------
AWS_ACCOUNT_ID=""
ECR_BASE=""

if ! $SKIP_ECR; then
  require_cmd aws

  stage "AWS STS + ECR login"
  aws sts get-caller-identity --region "$AWS_REGION" >/dev/null \
    || die "AWS STS unreachable — check credentials/network."

  AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  info "Account ID: $AWS_ACCOUNT_ID"
  info "ECR Base  : $ECR_BASE"

  if ! $SKIP_BUILD || ! $SKIP_PUSH || ! $SKIP_SET_IMAGES; then
    require_cmd docker
    aws ecr get-login-password --region "$AWS_REGION" \
      | docker login --username AWS --password-stdin "$ECR_BASE" >/dev/null
    ok "Logged into ECR."
  else
    warn "No docker-related actions requested; skipping ECR login."
  fi

  stage "Verify ECR repositories"
  for app in "${APPS[@]}"; do
    if ! aws ecr describe-repositories --repository-names "$app" --region "$AWS_REGION" >/dev/null 2>&1; then
      info "Creating ECR repo: $app"
      aws ecr create-repository --repository-name "$app" --region "$AWS_REGION" >/dev/null
    else
      info "Repo exists: $app"
    fi
  done
  ok "ECR repositories verified."

  # Determine build contexts
  declare -A APP_CTX=()
  declare -A APP_HAS_CTX=()
  for app in "${APPS[@]}"; do
    ctx="$(app_context_dir "$app")"
    APP_CTX["$app"]="$ctx"
    if [[ -f "${ctx}/Dockerfile" ]]; then
      APP_HAS_CTX["$app"]=true
    else
      APP_HAS_CTX["$app"]=false
    fi
  done

  # Build
  if ! $SKIP_BUILD; then
    stage "Build Docker images (local)"
    missing=0
    for app in "${APPS[@]}"; do
      ctx="${APP_CTX[$app]}"
      if [[ "${APP_HAS_CTX[$app]}" != "true" ]]; then
        warn "No Docker context for $app (expected ${ctx}/Dockerfile). Skipping build for this app."
        ((missing++)) || true
        continue
      fi
      info "Building: ${app}:${IMAGE_TAG} (context: ${ctx})"
      docker build -t "${app}:${IMAGE_TAG}" "$ctx"
      ok "Built: ${app}:${IMAGE_TAG}"
    done
    if $FORCE_BUILD && [[ $missing -gt 0 ]]; then
      die "Missing Docker contexts for ${missing} app(s) and --force-build is set."
    fi
    ok "Build step complete."
  else
    warn "Skipping local builds."
  fi

  # Push
  if ! $SKIP_PUSH; then
    stage "Tag + push images to ECR"
    pushed_any=false
    for app in "${APPS[@]}"; do
      local_ref="${app}:${IMAGE_TAG}"
      ecr_ref="${ECR_BASE}/${app}:${IMAGE_TAG}"

      if ! docker image inspect "$local_ref" >/dev/null 2>&1; then
        warn "Local image not found: ${local_ref}. Skipping push for $app."
        continue
      fi

      info "Tagging: $local_ref -> $ecr_ref"
      docker tag "$local_ref" "$ecr_ref"

      info "Pushing: $ecr_ref"
      docker push "$ecr_ref" >/dev/null
      ok "Pushed: $ecr_ref"
      pushed_any=true
    done

    if [[ "$pushed_any" != "true" ]]; then
      warn "No images were pushed (no local images found). Continuing deploy-only."
    else
      ok "Push step complete."
    fi
  else
    warn "Skipping pushes."
  fi
fi

# -------------------------------
# Apply manifests
# -------------------------------
stage "Applying manifests"
kubectl_apply "$NS_FILE"

kubectl_apply "$MANIFEST_DIR/app1-deployment.yaml"
kubectl_apply "$MANIFEST_DIR/app1-service.yaml"
kubectl_apply "$MANIFEST_DIR/app1-hpa.yaml"

kubectl_apply "$MANIFEST_DIR/app2-deployment.yaml"
kubectl_apply "$MANIFEST_DIR/app2-service.yaml"
kubectl_apply "$MANIFEST_DIR/app2-hpa.yaml"

kubectl_apply "$MANIFEST_DIR/app3-deployment.yaml"
kubectl_apply "$MANIFEST_DIR/app3-service.yaml"
kubectl_apply "$MANIFEST_DIR/app3-hpa.yaml"

kubectl_apply "$INGRESS_FILE"
ok "All manifests applied."

# -------------------------------
# Set images to ECR (optional but recommended)
# -------------------------------
if ! $SKIP_SET_IMAGES; then
  [[ -n "${ECR_BASE:-}" ]] || die "Cannot set images to ECR because ECR_BASE is empty. (Did you run with --skip-ecr?)"
  stage "Set Deployment images to ECR"
  for app in "${APPS[@]}"; do
    ecr_ref="${ECR_BASE}/${app}:${IMAGE_TAG}"
    info "kubectl set image deploy/${app} ${app}=${ecr_ref}"
    if $DRY_RUN; then
      warn "Dry-run: skipping live set image for $app"
    else
      kubectl -n "$NAMESPACE" set image "deployment/${app}" "${app}=${ecr_ref}" >/dev/null
    fi
  done
  ok "Images set to ECR refs."
else
  warn "Skipping kubectl set image (deployments will use whatever image is in YAML)."
fi

# -------------------------------
# Patch ingress subnets (optional)
# -------------------------------
if ! $SKIP_SUBNET_PATCH; then
  stage "Ingress subnet patch (dynamic from Terraform output)"
  if [[ -f "$SUBNETS_FILE" ]]; then
    PUBLIC_SUBNETS="$(jq -r '.value | @csv' "$SUBNETS_FILE" | tr -d '"')"
    if [[ -n "$PUBLIC_SUBNETS" ]]; then
      info "Patching Ingress subnets to: $PUBLIC_SUBNETS"
      if ! $DRY_RUN; then
        kubectl -n "$NAMESPACE" annotate ingress "$INGRESS_NAME" \
          "alb.ingress.kubernetes.io/subnets=$PUBLIC_SUBNETS" --overwrite >/dev/null
        ok "Ingress subnet annotation updated."
      else
        warn "Dry-run: skipping live annotate."
      fi
    else
      warn "Subnets file present but empty .value: $SUBNETS_FILE"
    fi
  else
    warn "Subnets file not found; skipping: $SUBNETS_FILE"
  fi
else
  warn "Skipping ingress subnet patch."
fi

# -------------------------------
# Rollout gating
# -------------------------------
stage "Waiting for application rollouts"
kubectl -n "$NAMESPACE" rollout status deployment/app1 --timeout="$WAIT_TIMEOUT_ROLLOUT"
kubectl -n "$NAMESPACE" rollout status deployment/app2 --timeout="$WAIT_TIMEOUT_ROLLOUT"
kubectl -n "$NAMESPACE" rollout status deployment/app3 --timeout="$WAIT_TIMEOUT_ROLLOUT"
ok "Deployments rolled out."

# -------------------------------
# Health gating (before success)
# -------------------------------
if ! $SKIP_HEALTH; then
  health_check_service "app1-svc" "8081" "$APP1_HEALTH_PATH"
  health_check_service "app2-svc" "8082" "$APP2_HEALTH_PATH"
  health_check_service "app3-svc" "8083" "$APP3_HEALTH_PATH"
  ok "All in-cluster health checks passed."
else
  warn "Skipping health checks."
fi

# -------------------------------
# Wait for ALB hostname
# -------------------------------
stage "Waiting for ALB hostname"
if ! $DRY_RUN; then
  kubectl -n "$NAMESPACE" wait \
    --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
    --timeout="$WAIT_TIMEOUT_INGRESS" "ingress/$INGRESS_NAME" >/dev/null 2>&1 || true
fi

ALB_HOST="$(kubectl -n "$NAMESPACE" get ingress "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

# -------------------------------
# Final status
# -------------------------------
stage "Final status"
kubectl -n "$NAMESPACE" get pods -o wide
kubectl -n "$NAMESPACE" get svc -o wide
kubectl -n "$NAMESPACE" get ingress -o wide

if [[ -n "${ALB_HOST:-}" ]]; then
  hr
  ok "Deployment complete – Shared ALB:"
  info "ALB Host: $ALB_HOST"
  info "URLs:"
  info "  http://${ALB_HOST}/app1"
  info "  http://${ALB_HOST}/app2"
  info "  http://${ALB_HOST}/app3"
  hr
else
  warn "ALB hostname not assigned yet. Re-check ingress status:"
  warn "  kubectl -n $NAMESPACE get ingress $INGRESS_NAME -o wide"
fi

ok "Done."