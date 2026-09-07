# 🔥 AWS Armageddon - High Priority Taskers

![Status](https://img.shields.io/badge/Status-Active-success.svg)
![Platform](https://img.shields.io/badge/Platform-AWS-orange?logo=amazon-aws)
![Automation](https://img.shields.io/badge/Automation-Terraform%20%7C%20Helm-blue)
![Language](https://img.shields.io/badge/Language-Bash%20%26%20Terraform-yellow)
![GitHub Forks](https://img.shields.io/github/forks/tiqsclass6/aws-armageddon-class-6.0?style=social)
![Scripts](https://img.shields.io/badge/Scripts-Automated%20Install%20%26%20Uninstall-lightblue)
![Last Updated](https://img.shields.io/badge/Last%20Updated-November%202025-purple)
![GitHub License](https://img.shields.io/github/license/tiqsclass6/aws-armageddon-class-6.0)
![GitHub Stars](https://img.shields.io/github/stars/tiqsclass6/aws-armageddon-class-6.0?style=social)
![Stack](https://img.shields.io/badge/Stack-EKS%20%7C%20ECR%20%7C%20ECS%20%7C%20Envoy%20%7C%20Prometheus%20%7C%20Grafana-9cf.svg)

---

## 📖 Overview  

**AWS Armageddon Class 6.0** is a full-stack DevSecOps project that unifies **Infrastructure as Code (Terraform)**,  
**containerized Flask apps**, and **Kubernetes observability** into a cohesive AWS solution.  

It merges three major deliverables:  

- **Task 1:** Automated Observability & Network Automation  
- **Task 2:** Dockerized Flask Applications → ECR → ECS/EKS  
- **Task 3:** Coming Soon

Together, they demonstrate automated provisioning, container orchestration, and live cluster visibility for cloud engineering teams.

Clone this repository so the working tree matches a local **Armageddon 2.0** folder (Terraform + Kubernetes labs in one checkout):

```plaintext
Armageddon 2.0/
├── README.md
├── .gitignore
├── diagrams/
│   ├── task1-diagram.png
│   └── task2-diagram.png
├── task-1/                  # Observability stack (Envoy, Prometheus, Grafana)
└── task-2/                  # Flask apps → ECR → EKS
```

The historical `task-1` and `task-2` git branches remain available. The folders on this tree are the same labs, so a single checkout of `main` matches the local Armageddon 2.0 directory.

---

## 📚 References  

- [Task 1 — Automated Kubernetes Observability Stack](./task-1)  
  Based on: Envoy Gateway, Prometheus, Grafana Helm Charts, AWS EKS, Terraform provisioning modules.  
  Includes custom installation/cleanup scripts: `AA-install-kubernetes-monitoring.sh`, `AB-uninstall-kubernetes-monitoring.sh`.  
  Branch copy: [task-1](https://github.com/tiqsclass6/aws-armageddon-class-6.0/tree/task-1).

- Supporting Documentation:
  - Kubernetes Concepts —[Kubernetes Docs](https://kubernetes.io/docs/concepts/)
  - Helm Charts — [Using Helm Charts](https://helm.sh/docs/topics/charts/)
  - Envoy Documentation — [Envoy User Guide](https://www.envoyproxy.io/docs/envoy/latest/)
  - Prometheus Overview — [Prometheus Docs](https://prometheus.io/docs/introduction/overview/)
  - Grafana OSS and Enterprise — [Grafana Docs](https://grafana.com/docs/grafana/latest/)

- [Task 2 — Docker-Based Flask Apps → AWS ECR → AWS ECS](./task-2)  
  Built using: Docker, Flask, Pillow, Amazon ECR, ECS, and Kubernetes manifests for deployment.  
  Includes automation scripts: `deploy-all-apps.sh`, `destroy-all-apps.sh`.  
  Branch copy: [task-2](https://github.com/tiqsclass6/aws-armageddon-class-6.0/tree/task-2).

- Supporting Documentation:  
  - AWS EKS Documentation — [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)  
  - Amazon ECR — [Amazon ECR Docs](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)
  - Amazon ECS — [Amazon ECS Docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html)
  - Docker Docs — [Docker Engine Overview](https://docs.docker.com/engine/)
  - Flask Documentation — [Flask Docs](https://flask.palletsprojects.com/en/latest/)  
  - Pillow Documentation — [Pillow Docs](https://pillow.readthedocs.io/en/stable/)
  - Kubernetes Concepts — [Kubernetes Docs](https://kubernetes.io/docs/concepts/)

---

## 🧠 Project Objective  

Deliver a **secure, automated, and observable AWS ecosystem** capable of:  

- Provisioning VPC + EKS via Terraform  
- Automating Helm-based monitoring stacks  
- Deploying Dockerized Flask apps to ECR → ECS → EKS  
- Exposing real-time metrics through Prometheus & Grafana  
- Demonstrating best-practice IaC and CI/CD workflows  

---

## 🔗 Branches

### 🌍 [Task 1 - Automated Kubernetes Observability Stack](./task-1)

![task1-diagram](/diagrams/task1-diagram.png)

**Goal:** Automate the deployment of **Envoy Gateway**, **Prometheus**, and **Grafana** inside an EKS cluster.  

**Highlights:**  

- Single-script install/uninstall  
- Lifecycle automation via Helm + Terraform  
- Namespace teardown & repeatable IaC builds  
- Verified with screenshots and demo  

---

## 🎵 [Task 2 — Docker-Based Flask Applications → AWS ECR → AWS ECS](./task-2)  

![task2-diagram](/diagrams/task2-diagram.png)

**Goal:** Containerize and deploy three Flask apps representing Death Row Records artists, each exposed through unique ports and self-healing Kubernetes pods.  

**Highlights:**  

- Flask + Pillow dynamic image generation  
- HPA auto-scaling (3–10 pods @ 70 % CPU)  
- Liveness/Readiness probes for self-healing  
- One-click deployment and cleanup scripts  

---

## 🛠 Troubleshooting  

| Issue | Cause | Resolution |
|-------|-------|------------|
| `LoadBalancer pending` | ELB delay | Wait 3–5 min → `kubectl get svc` |
| `Grafana password missing` | Secret not ready | Re-run secret decode cmd |
| `CrashLoopBackOff` | App failed probe | `kubectl logs <pod>` → fix error |
| `ImagePullBackOff` | Expired ECR token | `aws ecr get-login-password docker login` |
| `Namespace stuck Terminating` | Finalizers present | Remove with `kubectl replace --raw` |
| `Helm release exists` | Previous install residue | Run uninstall → retry |

---

## ✍️ Authors & Acknowledgments  

- **Author:** T.I.Q.S.  
- **Group Leader:** John Sweeney  
- **Organization:** Balerica Inc. — Cloud Engineering Team 6  
- **GitHub:** [github.com/tiqsclass6](https://github.com/tiqsclass6)  

> “Automate Everything. Monitor Everything. Destroy Nothing by Hand.” 🧠  
