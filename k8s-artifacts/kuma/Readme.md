## Create Kuma Namespace and Service Accounts

```bash
kubectl create namespace kuma-system
kubectl create sa kuma-control-plane -n kuma-system
kubectl create sa kuma-cni -n kube-system
```

## Create Custom SCC for Kuma

```bash
oc apply -f kuma-scc.yaml
```

### Patch Kuma CNI DaemonSet to Allow Privileged Mode

```bash
oc patch daemonset kuma-cni-node -n kube-system --type=json -p='[{
  "op": "add",
  "path": "/spec/template/spec/containers/0/securityContext/privileged",
  "value": true
}]'
```

### Generate the kuma files

Kuma artifcats yaml can be generated using the kumactl tool.

```bash
curl -L https://kuma.io/installer.sh | sh

kumactl install control-plane \
  --cni-enabled \
  --namespace kuma-system \
  > kuma-cp.yaml
```

Apply the file

```bash
oc apply -f kuma-cp.yaml
```

### Untaint Worker Nodes (if scheduling is blocked)

```bash
kubectl taint nodes <worker-node-name> NodeReadiness:NoSchedule-
```

### Expose Kuma GUI via Kong

```bash
oc apply -f kuma-ingress.yaml
```

### Enable mTLS and Allow Traffic

```bash
kubectl apply -f kuma-mtls.yaml
kubectl apply -f kuma-trafficpermission.yaml
```
