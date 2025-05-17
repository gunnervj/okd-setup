# Keycloak installation

```bash
oc create namespace identity

oc create secret generic keycloak-db-secret \
 --namespace identity \
 --from-literal=password='Aadumol1$'

oc create secret generic keycloak-admin-secret \
 --namespace identity \
 --from-literal=admin-password='Aadumol1$'
```

# Create database and give necessary previleges

```sql
DROP DATABASE keycloak;
CREATE DATABASE keycloak;

CREATE USER keycloak WITH PASSWORD '<PASSWORD>';
CREATE USER keycloak_admin WITH PASSWORD '<PASSWORD>';

GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
```

Login to the keycloak database and run the below commands

```sql
\c keycloak

GRANT USAGE ON SCHEMA public TO keycloak;
GRANT CREATE ON SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO keycloak;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak;
```

# Service Account

Create service account and add the SA to the custom SCC

```bash
oc create sa keycloak-sa -n identity
oc apply -f keycloak-scc.yaml
oc adm policy add-scc-to-user keycloak-scc -n identity -z keycloak-sa
```

Run the helm for the keycloak installation

```bash
helm install keycloak bitnami/keycloak -n identity -f values.yaml
```

# Sidecar Injection(Envoy) Kuma

- Kuma uses sidecar injection to deploy an Envoy proxy alongside each pod
- This proxy intercepts all inbound/outbound traffic
- Labeling the namespace enables automatic injection for all pods in that namespace

```bash
oc adm policy add-scc-to-user kuma-sidecar-scc -z keycloak-sa -n identity
oc label namespace identity kuma.io/sidecar-injection=enabled
oc rollout restart statefulset keycloak -n identity
```

Verify by running below comman should give `keycloak-0: kuma-sidecar keycloak `

```bash
oc get pods -n identity -o jsonpath="{range .items[*]}{.metadata.name}{': '}{range .spec.containers[*]}{.name}{' '}{end}{'\n'}"
```

## Adding KumaGeway for mTLS to Keycloak

1. Create certificate by reuisng the cert form cert manager

```bash
oc get secret auth-tls -n identity -o yaml \
  | sed 's/name: auth-tls/name: auth-gateway-tls/' \
  | oc apply -f -
```

2. Define the Kuma MeshGateway (HTTPS listener)
