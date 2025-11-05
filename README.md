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
# destroy-all-apps.sh — Task-2 EKS Cleanup Script
# -----------------------------------------------------------------------------
# Deletes Kubernetes app resources, IRSA (IAM Role + ServiceAccount), ECR repos,
# and optionally the EKS cluster. Commands are described inline for clarity.
# =============================================================================

set -euo pipefail

# -------------------------------
# 1.) Configuration
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
# 2.) Helper functions
# -------------------------------
info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || error "Required tool '$1' not found."; }

# -------------------------------
# 3.) Tool checks
# -------------------------------
need kubectl
need eksctl
need aws

# -------------------------------
# 4.) Safety confirmation
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
# 5.) Ensure kubeconfig and context
# -------------------------------
info "Setting kubectl context to the EKS cluster (so deletes work against the right cluster)..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# -------------------------------
# 6.) Delete Kubernetes resources
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

# ----------------------------------------------
# 7.) IRSA cleanup (ServiceAccount + IAM Role)
# ----------------------------------------------
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
# 8.) ECR repositories cleanup
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

# ---------------------------------------
# 9.) Optionally delete the EKS cluster
# ---------------------------------------
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
# 10.) Completion
# -------------------------------
success "Destroy completed. Environment is cleaned."
echo "You can redeploy with: ./deploy-all-apps.sh"
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
