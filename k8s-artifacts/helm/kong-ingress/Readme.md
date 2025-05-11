# Kong Ingress Installation

#### Helm Repo

helm repo add kong https://charts.konghq.com

## Create Kong database

Kong needs a database for persistant storage.

```sql
psql -h 192.168.122.101 -U postgres -d postgres
create user kong with password '';
create database kong;
GRANT ALL PRIVILEGES ON DATABASE kong TO kong;
\q
psql -h 192.168.122.101 -U postgres -d kong
GRANT USAGE ON SCHEMA public TO kong;
GRANT CREATE ON SCHEMA public TO kong;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO kong;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO kong;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO kong;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO kong;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO kong;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO kong;
```

## Create Namespace

```bash
oc create namespace kong-ingress
```

## Create Secrets

```bash
oc create secret generic kong-db-secret \
 --namespace kong-ingress \
 --from-literal=password=''
```

## Create SCC

Kong needs special priveleges to run in OKD.

```bash
oc apply -f kong-scc.yaml
```

## Service Account

Create service account and add to the scc.

```bash
oc create serviceaccount kong-ingress-sa -n kong-ingress
oc adm policy add-scc-to-user kong-ingress-scc -z kong-ingress-sa -n kong-ingress
oc adm policy add-scc-to-user anyuid system:serviceaccount:kong-ingress:kong-ingress-sa

```

## Run Helm

```bash
helm install kong kong/kong -f values.yaml -n kong-ingress --create-namespace --set ingressController.installCRDs=false
```

## Kong Manager

Kong will also install kong manager.
