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

### 📄 Final Output

```plaintext
Deployment is complete ..
- App1 → http://a1b2c3d4-12345678901.REGION.elb.amazonaws.com
- App2 → http://b2c3d4de-23456789015.REGION.elb.amazonaws.com
- App3 → http://c3d4e5f6-12345678901.REGION.elb.amazonaws.com
```

![app1-complete](/Screenshots/app1-complete.jpg)
![app2-complete](/Screenshots/app2-complete.jpg)
![app3-complete](/Screenshots/app3-complete.jpg)

---

## 📸 Screenshots (Show Your Work)

- Docker Hub with Custom Images:
  ![docker-hub-custom-images.jpg](/Screenshots/docker-hub-custom-images.jpg)

- AWS EKS Cluster:
  ![eks-task-2-cluster.jpg](/Screenshots/eks-task-2-cluster.jpg)

- AWS ECR Private Repo for all apps:
  ![aws-ecr-private-repo-for-apps.jpg](/Screenshots/aws-ecr-private-repo-for-apps.jpg)

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
