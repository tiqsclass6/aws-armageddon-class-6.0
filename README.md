# Armageddon Task 2 - Docker based Flask Apps → AWS ECR → AWS ECS  

![Docker](https://img.shields.io/badge/Docker-Containerized-blue?logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestrated-326CE5?logo=kubernetes)
![Flask](https://img.shields.io/badge/Flask-Web%20Framework-lightgrey?logo=flask)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-orange?logo=amazon-aws)
![Python](https://img.shields.io/badge/Python-3.10+-yellow?logo=python)
![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4?logo=terraform)
![AWS ECR](https://img.shields.io/badge/AWS-ECR-FF9900?logo=amazon-aws)
![AWS ECS](https://img.shields.io/badge/AWS-ECS-FF9A00?logo=amazon-aws)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)
![Last Updated](https://img.shields.io/badge/Last%20Updated-November%202025-informational)

---

## 🔥 Overview

This project deploys **three dynamic web applications** using **Docker + Flask + Kubernetes (EKS)**, each representing an iconic Death Row Records artist. Each app features a **Death Row Records background**, **each possess their own unique port**, and runs inside **self-healing, auto-scaling Kubernetes pods**.

| App | Artist | Port | Notable Album |
|-----|--------|------|---------------|
| **App1** | Tupac Shakur "2Pac" | `8081` | *All Eyez On Me* |
| **App2** | Dr. Dre | `8082` | *The Chronic* |
| **App3** | Snoop Dogg | `8083` | *Doggystyle* |

---

![diagram](/Screenshots/diagram.png)

## 🎯 Task 2 Objective

> [!TIP]
> The Dev team wants to explore using Docker and Kubernetes to deploy their applications.  
> Build and deploy 3 externally accessible and highly available web apps.  
> Each application must:
>
> - Run in **self-healing pods** within your **EKS cluster**  
> - Feature its own **unique Docker image** and **non-standard port**  
> - Follow **Kubernetes best practices**

---

## 🧩 Features

- ⚙️ **Dynamic Image Generation** (Pillow + Flask)
- 🔄 **Self-Healing Pods** with Liveness / Readiness probes
- 📈 **Auto-Scaling (HPA)** 3–10 pods @ 70% CPU
- 🌐 **External Access** via AWS Load Balancer
- 🧰 **One-Click Deployment** and Cleanup scripts
- 🧠 **Kubernetes Best Practices** (Rolling updates, health checks, limits)

---

## 🗂️ Project Structure

```plaintext
TASK-2/
│
├── .vscode/
│   └── launch.json
│
├── app1/
│   ├── static/
│   │   ├── app1.jpg
│   │   ├── death-row-bg.jpg
│   │   └── styles.css
│   ├── templates/
│   │   └── index.html
│   ├── app1.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── app2/
│   ├── static/
│   │   ├── app2.jpg
│   │   ├── death-row-bg.jpg
│   │   └── styles.css
│   ├── templates/
│   │   └── index.html
│   ├── app2.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── app3/
│   ├── static/
│   │   ├── app3.jpg
│   │   ├── death-row-bg.jpg
│   │   └── styles.css
│   ├── templates/
│   │   └── index.html
│   ├── app3.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── manifests/
│   ├── app1-deployment.yaml
│   ├── app1-hpa.yaml
│   ├── app1-service.yaml
│   ├── app2-deployment.yaml
│   ├── app2-hpa.yaml
│   ├── app2-service.yaml
│   ├── app3-deployment.yaml
│   ├── app3-hpa.yaml
│   └── app3-service.yaml
│
├── Screenshots/
│   ├── app1-complete.jpg
│   ├── app2-complete.jpg
│   ├── app3-complete.jpg
│   ├── aws-ecr-private-repo-for-apps.jpg
│   ├── cleanup-app-pt1.jpg
│   ├── cleanup-app-pt2.jpg
│   ├── cleanup-app-pt3.jpg
│   ├── deploy-app-pt1.jpg
│   ├── deploy-app-pt2.jpg
│   ├── deploy-app-pt3.jpg
│   ├── deploy-app-pt4.jpg
│   ├── deploy-app-pt5.jpg
│   ├── deploy-app-pt6.jpg
│   ├── deploy-app-pt7.jpg
│   ├── diagram.png
│   ├── docker-hub-custom-images.jpg
│   └── eks-task-2-cluster.jpg
│
├── scripts/
│   ├── deploy-all-apps.sh
│   └── destroy-all-apps.sh
│
├── .gitignore
└── README.md
```

---

## 🧰 Tech Stack

| Layer | Technology |
|-------|-------------|
| Application | Python (Flask, Pillow) |
| Container | Docker |
| Orchestration | Kubernetes (EKS) |
| Registry | Amazon ECR |
| Load Balancing | AWS ALB |

---

## 🚀 `deploy-all-apps.sh` - Deployment Shell Script

> [!TIP]
> Ensure you Run Docker Desktop BEFORE you run the deployment script!!

```bash
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
```

---

## 🚀 Quick Start

```bash
# 1. Build repo and folders
git clone <your-repo>
cd task-2

# 2. Edit AWS settings
# scripts/deploy-all-apps.sh → set AWS_REGION
# manifests/*.yaml → replace <ACCOUNT_ID> and <REGION>

# 3. Deploy all apps
chmod +x scripts/deploy-all-apps.sh
./scripts/deploy-all-apps.sh
```

![deploy-app-pt1](/Screenshots/deploy-app-pt1.jpg)
![deploy-app-pt2](/Screenshots/deploy-app-pt2.jpg)
![deploy-app-pt3](/Screenshots/deploy-app-pt3.jpg)
![deploy-app-pt4](/Screenshots/deploy-app-pt4.jpg)
![deploy-app-pt5](/Screenshots/deploy-app-pt5.jpg)
![deploy-app-pt6](/Screenshots/deploy-app-pt6.jpg)
![deploy-app-pt7](/Screenshots/deploy-app-pt7.jpg)

---

## 📄 Final Output

```plaintext
Deployment is complete ..
- App1 → http://a3f84f67724cc469e8a54dd211ebb013-641140867.us-east-1.elb.amazonaws.com:8081/
- App2 → http://a395d8534ed5d4f02bc51d615d87b88b-199479770.us-east-1.elb.amazonaws.com:8082/
- App3 → http://a8b108d5f27d940d498808419d4b72eb-1741287837.us-east-1.elb.amazonaws.com:8083/
```

![app1-complete](/Screenshots/app1-complete.jpg)
![app2-complete](/Screenshots/app2-complete.jpg)
![app3-complete](/Screenshots/app3-complete.jpg)

---

## 📸 Screenshots (Show Your Work)

- **Docker Hub with Custom Images:**
  ![docker-hub-custom-images.jpg](/Screenshots/docker-hub-custom-images.jpg)
- **AWS EKS Cluster:**
  ![eks-task-2-cluster.jpg](/Screenshots/eks-task-2-cluster.jpg)
  ![eks-cluster-nodes-and-nodegroups.jpg](/Screenshots/eks-cluster-nodes-and-nodegroups.jpg)  
- **AWS ECR Private Repo for all apps (with Docker Images):**
  ![aws-ecr-private-repo-for-apps.jpg](/Screenshots/aws-ecr-private-repo-for-apps.jpg)
  ![ecr-app1-image.jpg](/Screenshots/ecr-app1-image.jpg)
  ![ecr-app2-image.jpg](/Screenshots/ecr-app2-image.jpg)
  ![ecr-app3-image.jpg](/Screenshots/ecr-app3-image.jpg)
- **AWS EC2 Instances:**
  ![ec2-instances.jpg](/Screenshots/ec2-instances.jpg)
- **AWS Load Balancers:**
  ![load-balancers.jpg](/Screenshots/load-balancers.jpg)
- **Full VPC Summary:**
  ![vpc-full-summary.jpg](/Screenshots/vpc-full-summary.jpg)

---

## 🔁 Test Self-Healing

```bash
# Delete a pod to test auto-recovery
kubectl delete pod -l app=app1 --force

# Watch it respawn
kubectl get pods -l app=app1 -w
```

---

## 🧪 Local Development

1. Open folder in VS Code  
2. Press `F5` to launch locally  
3. Access:
   - App1 → <http://localhost:8081>  
   - App2 → <http://localhost:8082>  
   - App3 → <http://localhost:8083>  

---

## 💥 `destroy-all-apps.sh` - Cleanup Shell Script

> [!TIP]
> Delete your images in Docker Hub while the script is tearing down everything !!

```bash
#!/usr/bin/env bash
# =============================================================================
# destroy-all-apps.sh — Tear down Death Row EKS demo
#
# This script will:
#   1. Delete all K8s resources for app1, app2, app3
#   2. Optionally delete ECR repos (app1, app2, app3)
#   3. Optionally delete the EKS cluster (via eksctl)
#
# DANGER: Deleting the cluster will remove the control plane + nodegroup
# =============================================================================

set -euo pipefail

# -------------------------------
# 1.) Configuration (edit these)
# -------------------------------
MANIFEST_DIR="manifests"
NAMESPACE="${NAMESPACE:-default}"         # Replace with namespace
AWS_REGION="${AWS_REGION:-us-east-1}"     # Update Region Here
CLUSTER_NAME="${CLUSTER_NAME:-task-2}"    # Update Cluster Name

# ECR Repos created on deployment script
ECR_REPOS=("app1" "app2" "app3")

# K8s YAMLs that will be deleted
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
# 1.a) Helpers
# -------------------------------
info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# -------------------------------
# 2.) Tool checks
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
# 3.) Delete Kubernetes resources
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

# Wait for pods to terminate (doesn’t fail if they’re deleted)
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
# 4.) ECR cleanup
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
# 5.) Ask if we should delete the EKS cluster
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

# -------------------------------
# 6.) Tear Down Complete
# -------------------------------
echo
success "DESTROY COMPLETE."
echo "You can re-deploy with: ./deploy-all-apps.sh"
```

---

## 🧹 Cleanup

```bash
chmod +x scripts/destroy-all-apps.sh
./scripts/destroy-all-apps.sh
```

![cleanup-app-pt1](/Screenshots/cleanup-app-pt1.jpg)
![cleanup-app-pt2](/Screenshots/cleanup-app-pt2.jpg)
![cleanup-app-pt3](/Screenshots/cleanup-app-pt3.jpg)

---

## 🧯 Troubleshooting

| Issue | Cause | Fix |
|--------|--------|-----|
| ❌ `CrashLoopBackOff` | App failing readiness probe | Check logs with `kubectl logs <pod>` |
| ⚠️ HPA not scaling | Missing metrics-server | `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml` |
| ⛔ LoadBalancer pending | EKS IAM permissions or subnet config | Ensure correct `service.beta.kubernetes.io/aws-load-balancer-type` annotation |
| 🧩 ImagePullBackOff | ECR login expired | Run `aws ecr get-login-password docker login` |

---

## ✍️ Authors & Acknowledgments

- **Author:** T.I.Q.S.
- **Group Leader:** John Sweeney

> “Keep it real. Keep it Death Row.” 🎤

---
