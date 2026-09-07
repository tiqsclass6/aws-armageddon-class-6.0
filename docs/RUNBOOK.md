# Task 1 runbook — full deployment

Balerica Inc. network lab: provision EKS with Terraform, then automate Envoy Gateway, Prometheus, and Grafana.

Run these commands from **Git Bash** in:

`C:\Users\bjett\Documents\TheoWAF\class6\AWS\Terraform\Kubernetes\Armageddon 2.0\task1`

---

## What you are deploying

| Layer | Tool | Result |
| --- | --- | --- |
| VPC, subnets, NAT, EKS, nodes, IRSA, EBS CSI, `gp3` | Terraform (`terraform/`) | Private worker cluster in two AZs |
| Prometheus + Grafana | Helm `kube-prometheus-stack` | Namespace `observability` |
| Envoy Gateway | Helm `gateway-helm` v1.5.3 | Namespace `envoy-gateway-system` |
| Grafana URL | `manifests/grafana-route.yaml` | `http://<envoy>/grafana/` |
| Envoy metrics | `manifests/servicemonitor-envoy.yaml` | Scraped by Prometheus |

![Architecture](../images/diagram.png)

---

## 0. Prerequisites

Install and confirm:

```bash
terraform version    # >= 1.10
aws --version
kubectl version --client
helm version
```

Authenticate to AWS (SSO, env vars, or a named profile):

```bash
aws sts get-caller-identity
```

You need rights to create VPC, EKS, EC2, IAM, KMS, CloudWatch Logs, and Network Load Balancers.

On Windows, keep using Git Bash for the `.sh` scripts. PowerShell will not run them as-is.

---

## 1. Restrict the EKS public API

Copy the example vars and lock the control plane to your workstation.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Find your public IP:

```bash
curl -s https://checkip.amazonaws.com
```

Edit `terraform.tfvars`:

```hcl
region       = "us-east-1"
cluster_name = "balerica-task1"

eks_public_access_cidrs = ["YOUR.PUBLIC.IP.HERE/32"]
```

Leave `aws_profile` unset unless you must use a named profile. Do **not** commit `terraform.tfvars`.

---

## 2. Format, validate, and plan

Still in `terraform/`:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

`terraform init` downloads AWS, Helm, Kubernetes, and Null providers. There is no remote S3 backend by default; state is local (`terraform.tfstate`, gitignored).

Expect a plan that creates, among other things:

- VPC `10.100.0.0/16` with two public and two private subnets
- Internet Gateway and one NAT Gateway
- KMS key + CloudWatch log group for EKS
- EKS cluster `balerica-task1` (private + public API, secrets encryption)
- Node group: 3× `t3.medium`, min 2, max 5, private subnets only, IMDSv2
- OIDC provider and IRSA roles for VPC CNI and EBS CSI
- Helm release for the EBS CSI driver and a default `gp3` StorageClass

---

## 3. Apply the platform

```bash
terraform apply tfplan
```

First apply typically takes **12–20 minutes** (EKS control plane + nodes + add-ons).

![terraform-apply.jpg](../images/terraform-apply.jpg)

When it finishes, Terraform writes kubeconfig if `enable_kubeconfig = true` (default):

```bash
aws eks update-kubeconfig --region us-east-1 --name balerica-task1
```

Confirm the cluster:

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get storageclass
```

**Pass criteria**

- Three nodes `Ready` across two AZs
- StorageClass `gp3` exists and is default
- No nodes in public subnets

```bash
cd ..   # back to task1/
```

---

## 4. Install Envoy, Prometheus, and Grafana

```bash
chmod +x scripts/install-monitoring.sh scripts/uninstall-monitoring.sh
./scripts/install-monitoring.sh
```

![install-pt1.jpg](../images/install-pt1.jpg)
![install-pt2.jpg](../images/install-pt2.jpg)

The script is idempotent (`helm upgrade --install`). It does this in order:

1. Checks `kubectl` can reach the cluster and that StorageClass `gp3` exists.
2. Adds/updates the `prometheus-community` Helm repo.
3. Installs release `monitoring` into `observability` using `values/kube-prometheus-stack.yaml`.
   - Prometheus and Grafana are **ClusterIP** (not public LoadBalancers).
   - Grafana: 2 replicas, probes, PDB, anonymous auth off.
   - Prometheus: 20 Gi gp3 PVC, 7-day retention.
4. Waits up to 10 minutes for Grafana and Prometheus pods to become Ready.
5. Installs Envoy Gateway v1.5.3 into `envoy-gateway-system` using `values/envoy-gateway.yaml` (2 replicas).
6. Waits until deployment `envoy-gateway` is Available.
7. Applies the upstream Envoy quickstart Gateway (`eg` in `default`).
8. Applies:
   - `manifests/grafana-route.yaml` — HTTPRoute `/grafana` → Grafana
   - `manifests/servicemonitor-envoy.yaml` — Prometheus scrapes Envoy
   - `manifests/poddisruptionbudgets.yaml` — minAvailable 1 for Envoy
9. Prints the Envoy address and the command to read the Grafana password (it does **not** print the password).

Allow **3–5 extra minutes** after the script returns if the Gateway address is still `<pending>` (AWS NLB).

---

## 5. Verify all three services

```bash
kubectl get pods -n observability
kubectl get pods -n envoy-gateway-system
kubectl get svc -n observability
kubectl get gateway,httproute -A
kubectl get servicemonitor -n observability
```

**Pass criteria**

| Namespace | What you should see |
| --- | --- |
| `observability` | `monitoring-grafana` (2/2 Ready), Prometheus StatefulSet Ready, Alertmanager Ready |
| `envoy-gateway-system` | `envoy-gateway` Available, 2 replicas |
| `default` | Gateway `eg` with an address |
| `observability` | HTTPRoute `grafana`, ServiceMonitor `envoy-gateway` |

Services `monitoring-grafana` and `monitoring-kube-prometheus-prometheus` must be **ClusterIP**, not LoadBalancer.

![install-pt3.jpg](../images/install-pt3.jpg)

---

## 6. Access Grafana (through Envoy)

```bash
kubectl get gateway eg -n default
kubectl get secret monitoring-grafana -n observability \
  -o jsonpath='{.data.admin-password}' | base64 --decode; echo
```

Open:

```text
http://<gateway-address>/grafana/
```

- Username: `admin`
- Password: the secret from the command above
- Change that password after first login

If the hostname has no address yet:

```bash
kubectl get gateway eg -n default -w
```

![install-pt4.jpg](../images/install-pt4.jpg)

---

## 7. Access Prometheus (port-forward only)

Prometheus is not on the internet.

```bash
kubectl -n observability port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Open `http://127.0.0.1:9090`.

In **Status → Targets**, confirm kubelet, node-exporter, Grafana, and `envoy-gateway` are up. In **Graph**, a query such as `up` should return series.

Stop port-forward with `Ctrl+C` when done.

---

## 8. Screenshots for the assignment

Capture while the stack is healthy:

| Evidence | Command or URL |
| --- | --- |
| Terraform apply | terminal after `terraform apply` |
| Observability pods | `kubectl get pods -n observability` |
| Envoy pods | `kubectl get pods -n envoy-gateway-system` |
| Grafana UI | `http://<envoy>/grafana/` logged in |
| Prometheus UI | port-forward `http://127.0.0.1:9090` |
| Uninstall | after `scripts/uninstall-monitoring.sh` |
| Destroy | after `terraform destroy` |

Store new captures in `images/` if you replace the older LoadBalancer-era shots.

---

## 9. Uninstall the observability stack

This removes Helm releases and namespaces. It does **not** destroy EKS.

```bash
./scripts/uninstall-monitoring.sh
```

![uninstall-pt1.jpg](../images/uninstall-pt1.jpg)
![uninstall-pt2.jpg](../images/uninstall-pt2.jpg)

The script:

1. Deletes Grafana HTTPRoute, ServiceMonitor, PDBs, and the Envoy quickstart.
2. `helm uninstall eg` and `helm uninstall monitoring` if they exist.
3. Deletes namespaces `envoy-gateway-system` and `observability` and waits for them to terminate.

Confirm:

```bash
kubectl get ns
helm list -A
```

If a namespace sits in `Terminating`, find leftover CRDs:

```bash
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n 1 kubectl get -n observability
```

Prometheus PVCs may remain. Delete them if you do not need the data:

```bash
kubectl get pvc -A
kubectl delete pvc -n observability --all
```

---

## 10. Destroy the EKS platform

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. Destroy often takes **10–15 minutes**. Watch for leftover ENIs or NLBs in the AWS console if destroy errors on dependencies; re-run `terraform destroy`.

![terraform-destroy.jpg](../images/terraform-destroy.jpg)

---

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| `StorageClass gp3 not found` | Install script ran before Terraform finished | Re-run `terraform apply`, then the install script |
| Nodes `NotReady` | CNI addon still coming up | Wait 2–3 minutes; `kubectl get pods -n kube-system` |
| `helm: command not found` | Helm not on PATH | Install Helm 3; use Git Bash |
| LoadBalancer / Gateway pending | NLB provisioning | Wait 3–5 minutes; `kubectl get gateway eg -n default` |
| Grafana 404 at `/grafana` | HTTPRoute or subpath missing | `kubectl get httproute -n observability` and confirm `values/kube-prometheus-stack.yaml` has `serve_from_sub_path` |
| Empty Grafana password | Secret not ready | Wait for Grafana pods Ready, then re-run the secret command |
| Prometheus targets empty for Envoy | ServiceMonitor labels | `kubectl get servicemonitor envoy-gateway -n observability -o yaml` |
| Helm release already exists | Partial previous run | `./scripts/uninstall-monitoring.sh` then install again |
| `terraform apply` IAM name clash | Old `AmazonEKS_EBS_CSI_Driver_Policy` in the account | Policy names are now `${cluster_name}-ebs-csi`; destroy the old lab or rename `cluster_name` |
| Namespace stuck Terminating | Finalizers on CRDs | List namespaced resources (command in step 9); remove finalizers only as a last resort |

---

## Do not commit

- `terraform/terraform.tfvars`
- `terraform/*.tfstate*`
- kubeconfig
- Grafana passwords
- AWS keys
