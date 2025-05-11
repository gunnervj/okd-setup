# Keycloak installation

```bash
oc create namespace identity

oc create secret generic keycloak-db-secret \
 --namespace identity \
 --from-literal=password='<PASSWORD>'

oc create secret generic keycloak-admin-secret \
 --namespace identity \
 --from-literal=admin-password='<PASSWORD>'
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
helm install keycloak bitnami/keycloak -n keycloak -f values.yaml
```
