# Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
 --namespace cert-manager \
 --create-namespace \
 --set installCRDs=true

```
