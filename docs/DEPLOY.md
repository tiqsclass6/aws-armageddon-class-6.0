# Task 1 operations runbook

Use the root [README](../README.md) for the assignment narrative. This file is the operator checklist.

## Order of operations

1. Restrict `eks_public_access_cidrs` in `terraform/terraform.tfvars`.
2. `terraform apply` from `terraform/`.
3. Confirm nodes: `kubectl get nodes`.
4. `./scripts/install-monitoring.sh`.
5. Capture screenshots of:
   - `kubectl get pods -n observability`
   - `kubectl get pods -n envoy-gateway-system`
   - Grafana at `http://<envoy>/grafana/`
   - Prometheus via port-forward
6. `./scripts/uninstall-monitoring.sh` then `terraform destroy` when the lab is done.

## Why Grafana is not a LoadBalancer

The original scripts exposed Grafana and Prometheus with `service.type=LoadBalancer` on HTTP with no network restriction. Prometheus had **no authentication**. That is not least privilege.

Grafana is now ClusterIP and published through Envoy (`HTTPRoute` path `/grafana`). Prometheus stays on the cluster network; use port-forward for screenshots.

## Helm values

| File | Purpose |
| --- | --- |
| `scripts/values/kube-prometheus-stack.yaml` | ClusterIP services, probes, resources, encrypted gp3 PVCs, Grafana HA without RWO persistence |
| `scripts/values/envoy-gateway.yaml` | Two Envoy control-plane replicas and resource limits |

Grafana persistence is **off** on purpose. EBS `gp3` is ReadWriteOnce, so two Grafana replicas cannot share one volume. Dashboards still load from Prometheus Operator ConfigMaps.

## Teardown leftovers

If a namespace sits in `Terminating`, list remaining APIs:

```bash
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n 1 kubectl get -n observability
```

PVCs from Prometheus may remain if a reclaim policy is Retain. Delete them explicitly after uninstall if you do not need the data.

## Do not commit

- `terraform.tfvars`
- Grafana passwords
- kubeconfig
- `*.tfstate`
