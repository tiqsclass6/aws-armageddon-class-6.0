# Task 1 (Prometheus + Envoy + Grafana)

[![Kubernetes](https://img.shields.io/badge/Kubernetes-Production--Ready-blue?logo=kubernetes)](https://kubernetes.io)
[![Helm Chart](https://img.shields.io/badge/Helm-kube--prometheus--stack-blue?logo=helm)](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboard-yellow?logo=grafana)](https://grafana.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-orange?logo=prometheus)](https://prometheus.io)
[![Last Updated](https://img.shields.io/badge/Updated-October%2019%2C%202025%2012:45%20AM%20PDT-informational)](https://github.com/tiqsclass6/kubectl-assignments/tree/assignment-06072025)

This guide outlines the steps to deploy, manage, and remove a Kubernetes monitoring stack using the `kube-prometheus-stack` Helm chart in the `observability` namespace. It includes Helm setup, installation, access instructions, validation, and teardown.

---

## Demo Video

[![Task 1 Demo](https://img.youtube.com/vi/Ur_WtZtClqc/0.jpg)](https://www.youtube.com/watch?v=Ur_WtZtClqc)

---

## 📁 Project Structure

```plaintext
├── ARMAGEDDON 6.0
│   ├── terraform
│   │   ├── .gitignore
│   │   ├── 0-var.tf
│   │   ├── 1-auth.tf
│   │   ├── 2-vpc.tf
│   │   ├── 3-subnets.tf
│   │   ├── 4-igw.tf
│   │   ├── 5-nat.tf
│   │   ├── 6-rtb.tf
│   │   ├── 7-eks.tf
│   │   ├── 8-node.tf
│   │   ├── 9-runtime.tf
│   │   ├── 10-iam-oidc.tf
│   │   ├── 11a-storage-iam.tf
│   │   ├── 11b-storage-helm.tf
│   │   ├── 12-output.tf
│   └── install-kubernetes-monitoring.sh
│   └── uninstall-kubernetes-monitoring.sh
│   └── helm-envoy-grafana.mp4
│   ├── DEPLOY.md
│   └── README.md
```

---

## ✅ Prerequisites

- A Kubernetes cluster (e.g., AWS EKS) with Helm and `kubectl` installed.
- The `gp2` storage class available.
- A cloud provider supporting `LoadBalancer`.

---

## ⬇️ Step 1: Add Helm Repository

```bash
# Add Prometheus Community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update Helm repository metadata
helm repo update
```

- The first command adds the Prometheus Community repository.
- The second command refreshes metadata for all configured Helm repositories.

---

## 🚀 Step 2: Install Monitoring Stack

```bash
# Install kube-prometheus-stack Helm chart
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName="gp2" \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage="50Gi" \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.service.type=LoadBalancer \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.storageClassName="gp2" \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName="gp2" \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage="10Gi"
```

- **Deploys**: Prometheus (metrics collection), Grafana (visualization), Alertmanager (alert handling), and Node Exporter (node metrics).
- **Storage**: Configures persistent storage with the `gp2` storage class:
  - Prometheus: 50 GiB volume.
  - Alertmanager: 10 GiB volume.
  - Grafana: Persistent storage enabled (default size unless overridden).
- **External Access**: Exposes Prometheus and Grafana via `LoadBalancer` Services for external access.
- **Namespace**: Creates and uses the `observability` namespace.

---

## 🌐 Step 3: Install Envoy Gateway

```bash
# Install Envoy Gateway Helm chart
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.5.3 \
  --namespace envoy-gateway-system \
  --create-namespace

# Wait for Envoy Gateway deployment to be available
kubectl wait --timeout=5m \
  --namespace envoy-gateway-system \
  --for=condition=Available \
  deployment/envoy-gateway

# Apply Envoy Gateway quickstart configuration
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.5.3/quickstart.yaml \
  --namespace default

# Create ServiceMonitor for Envoy Gateway metrics
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: envoy-gateway
  namespace: observability
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: envoy-gateway
  namespaceSelector:
    matchNames:
    - envoy-gateway-system
  endpoints:
  - port: metrics
    path: /stats/prometheus
    interval: 15s
EOF
```

- **Deploys**: Envoy Gateway for managing ingress traffic.
- **Namespace**: Creates and uses the `envoy-gateway-system` namespace.
- **Quickstart**: Applies a sample configuration for testing Envoy Gateway.
- **ServiceMonitor**: Configures Prometheus to scrape Envoy Gateway metrics from the `/stats/prometheus` endpoint on the `metrics` port, enabling visualization in Grafana.

---

## 🔍 Step 4: Verify Resources

Check the status of the deployed resources in the `observability` namespace.

### Pods

List pods associated with the `monitoring` Helm release:

```bash
# List pods for the monitoring release
kubectl get pods \
  --namespace observability \
  --selector release=monitoring
```

- Displays pod names, status (e.g., `Running`, `Pending`), restarts, age, and other details for components like Prometheus, Grafana, Alertmanager, and Node Exporter.

### StatefulSets

List StatefulSets for stateful components (Prometheus and Alertmanager):

```bash
# List StatefulSets in observability namespace
kubectl get statefulsets \
  --namespace observability
```

- Shows names, ready replicas (e.g., `1/1`), and age of StatefulSets managing Prometheus and Alertmanager with persistent storage.

### DaemonSets

List DaemonSets for node-level metrics collection:

```bash
# List DaemonSets in observability namespace
kubectl get daemonsets \
  --namespace observability
```

- Displays the Prometheus Node Exporter DaemonSet, showing desired, current, up-to-date, and available pod counts across all nodes, along with age.

### Services

```bash
# List Services in observability namespace
kubectl get services \
  --namespace observability
```

- Shows Service names, types (`ClusterIP` or `LoadBalancer`), cluster IPs, external IPs (for `LoadBalancer`), ports, and age.
- Prometheus and Grafana Services have external IPs for access; others (e.g., Alertmanager, Node Exporter) use `ClusterIP` for internal communication.

---

## 🌐 Step 5: Access UIs

Retrieve credentials and URLs to access the Grafana and Prometheus UIs.

### Get Grafana Admin Password

Get the Grafana admin password:

```bash
# Retrieve Grafana admin password
kubectl get secret \
  --namespace observability \
  monitoring-grafana \
  --output jsonpath="{.data.admin-password}" | base64 -d; echo
```

- Outputs the plain-text password for the `admin` user (default username: `admin`, default password: `prom-operator` unless overridden).
- Use this to log into the Grafana UI.
  ![prometheus-password](Screenshots/prometheus-password.jpg)

  ```plaintext
  Username: admin
  Password: prom-operator
  ```

### Grafana URL

Get the external URL for the Grafana dashboard:

```bash
# Get Grafana service URL
echo "http://$(kubectl get service monitoring-grafana \
  --namespace observability \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):80"
```

- Outputs a URL (e.g., `http://<external-hostname>:80`) for accessing Grafana in a browser.

  ```plaintext
  http://<grafana-hostname>:80
  ```

### Prometheus URL

Get the external URL for the Prometheus server:

```bash
# Get Prometheus service URL
echo "http://$(kubectl get service monitoring-kube-prometheus-prometheus \
  --namespace observability \
  --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):9090"
```

- Outputs a URL (e.g., `http://<prometheus-hostname>:9090`) for accessing the Prometheus UI.

  ```plaintext
  http://<prometheus-hostname>:9090
  ```

### UI Screenshots

- **Grafana**: Use `http://<grafana-hostname>:80` with username `admin` and the retrieved password.
- **Prometheus**: Use `http://<prometheus-hostname>:9090` (no authentication by default).
- Ensure `LoadBalancer` Services are fully provisioned (check `kubectl get svc -n observability` for external IPs/hostnames).

- **Grafana Homepage:**
  
  ```plaintext
  http://<grafana-hostname>:80
  ```

- **Prometheus Homepage:**
  
  ```plaintext
  http://<prometheus-hostname>:9090
  ```

---

## 🧹 Step 6: Cleanup

Remove the monitoring stack, Envoy Gateway, and associated namespaces when no longer needed.

### `AB-uninstall-kubernetes-monitoring`

```bash
# Delete Envoy Gateway quickstart configuration
kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.5.3/quickstart.yaml \
  --namespace default \
  --ignore-not-found=true

# Delete ServiceMonitor for Envoy Gateway
kubectl delete servicemonitor envoy-gateway \
  --namespace observability \
  --ignore-not-found=true

# Uninstall Envoy Gateway
helm uninstall eg \
  --namespace envoy-gateway-system

# Delete envoy-gateway-system namespace
kubectl delete namespace envoy-gateway-system \
  --ignore-not-found=true

# Uninstall monitoring stack
helm uninstall monitoring \
  --namespace observability

# Delete observability namespace
kubectl delete namespace observability \
  --ignore-not-found=true
```

- **Monitoring Stack**: Deletes all resources created by the `kube-prometheus-stack` chart (Pods, StatefulSets, DaemonSets, Services, Secrets, ConfigMaps, PVCs).
- **Envoy Gateway**: Removes the Helm release, quickstart configuration, and ServiceMonitor.
- **Namespaces**: Deletes the `observability` and `envoy-gateway-system` namespaces.
- **Persistent Volumes**: PVs may persist if the `gp2` storage class has a `Retain` reclaim policy. Manually delete PVCs (`kubectl delete pvc -n observability -l "release=monitoring"`) or PVs (`kubectl get pv` and `kubectl delete pv <pv-name>`) if needed.

---

## 🛠️ Troubleshooting

- **No Resources Found**: Verify the namespace (`kubectl get ns`) and Helm release (`helm list -n observability`).
- **Pending LoadBalancer**: Wait for the cloud provider to assign external IPs/hostnames (`kubectl get svc -n observability`).
- **Stuck Namespace Deletion**: Check for finalizers or stuck resources (`kubectl describe namespace observability`) and force deletion if needed (`kubectl delete namespace observability --force --grace-period=0`).
- **Persistent Volumes**: If PVs remain, verify the `gp2` storage class reclaim policy and manually delete unneeded PVs.

---

## 🔒 Security Notes

- **Grafana**: Change the default admin password after logging in to secure the dashboard.
- **Prometheus**: Add authentication or network policies for the `LoadBalancer` Service to restrict public access.
- **Secrets**: Avoid exposing the Grafana admin password in logs or public terminals.

---

## ✍️ Authors & Acknowledgments

- **Author:** T.I.Q.S.
- **Group Leader:** John Sweeney

### 🙏 Inspiration

With guidance from:

- Sensei **"Darth Malgus" Theo**
- Mr **A-A-Ron**
- Sir **Rob**
- Jedi Master **Derrick**
- Lord **Beron**

---
