#!/bin/bash
set -euo pipefail

#export KEYCLOAK_DB_PASSWORD='password'
#export KEYCLOAK_ADMIN_PASSWORD='password'
#export PGHOST=pghost   # or your DB host
#export PGUSER=postgres    # your DB superuser
#export PGPASSWORD=supersecret   # password for PGUSER
#export PGPORT=5432        # optional, default is 5432

: "${KEYCLOAK_DB_PASSWORD:?Need to set KEYCLOAK_DB_PASSWORD}"
: "${KEYCLOAK_ADMIN_PASSWORD:?Need to set KEYCLOAK_ADMIN_PASSWORD}"

# SQL for DB and user setup
psql <<EOF
DROP DATABASE IF EXISTS keycloak;
CREATE DATABASE keycloak;

DROP USER IF EXISTS keycloak;
DROP USER IF EXISTS keycloak_admin;

CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
CREATE USER keycloak_admin WITH PASSWORD '${KEYCLOAK_ADMIN_PASSWORD}';

GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
EOF

# Connect to the newly created DB and apply schema grants
psql -d keycloak <<EOF
GRANT USAGE ON SCHEMA public TO keycloak;
GRANT CREATE ON SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO keycloak;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak;
EOF

echo "Keycloak - Install Started."
oc create namespace identity --dry-run=client -o yaml | oc apply -f -
oc create secret generic keycloak-db-secret \
  --namespace identity \
  --from-literal=password="${KEYCLOAK_DB_PASSWORD}" \
  --dry-run=client -o yaml | oc apply -f -
oc create secret generic keycloak-admin-secret \
  --namespace identity \
  --from-literal=admin-password="${KEYCLOAK_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | oc apply -f -

oc create sa keycloak-sa -n identity
oc apply -f keycloak-scc.yaml
oc adm policy add-scc-to-user keycloak-scc -n identity -z keycloak-sa

helm install keycloak bitnami/keycloak -n identity -f values.yaml

oc adm policy add-scc-to-user kuma-sidecar-scc -z keycloak-sa -n identity
oc label namespace identity kuma.io/sidecar-injection=enabled
oc rollout restart statefulset keycloak -n identity

oc apply -f keycloak-cert.yaml

mkdir certs

kubectl get secret auth-tls -n identity -o jsonpath='{.data.tls\.crt}' | base64 -d > certs\tls.crt
kubectl get secret auth-tls -n identity -o jsonpath='{.data.tls\.key}' | base64 -d > cers\tls.key

cat certs\tls.key certs\tls.crt > certs\tls-combined.pem

kubectl create secret tls kuma-auth-tls \                                                                                                             
  --cert=tls.crt \
  --key=tls.key \
  -n identity

oc apply -f mesh-traffic-permission.yaml
oc apply -f keycloak-kuma-gateway.yaml
oc apply -f keycloak-message-gatewayinstance.yaml
oc apply -f keycloak-gateway-route.yaml
oc apply -f keycloak-ingress.yaml

echo "Keycloak installed. Access it from https://auth.blocksafe.home"
