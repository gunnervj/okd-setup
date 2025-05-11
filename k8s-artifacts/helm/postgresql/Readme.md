# Database - Postgres

- Create Secrets
- Create PV
- Create PVC
- Run helm chart

> [!NOTE]
> Service Account and SCC are part of the helm.

### Create Secrets.

We will create secrets to store the database passwords.

```bash
kubectl create secret generic apps-db-secret \
  --namespace databases \
  --from-literal=password=<password> \
  --from-literal=postgres-password=<password> \
  --from-literal=admin-password=<password> \
  --from-literal=repmgr-password=<password>
```

### Create PV

To create pv we need storage location for the database to store data and files. To create these folder locations run the commands. I am creating this in a NAS shared drive.

```bash
for i in 0 1 2; do   sudo rm -rf /srv/nfs/okd/data-apps-db-ha-postgresql-$i/*; done

sudo rm -rf /srv/nfs/okd/data-apps-db-ha-postgresql-*
sudo mkdir -p /srv/nfs/okd/data-apps-db-ha-postgresql-{0,1,2}
sudo chmod -R 777 /srv/nfs/okd/data-apps-db-ha-postgresql-*
sudo chown -R nobody:nogroup /srv/nfs/okd/data-apps-db-ha-postgresql-0
sudo chown -R nobody:nogroup /srv/nfs/okd/data-apps-db-ha-postgresql-1
sudo chown -R nobody:nogroup /srv/nfs/okd/data-apps-db-ha-postgresql-2
```

> [!NOTE]
> Make sure a storage class is defined. If not Create one using `nfs-storageclass.yaml`.

Once the folders are created, apply pv and pvc yaml.

```bash
oc create namespace databases
oc apply -f apps-db-pv.yaml
oc apply -f apps-db-pvc.yaml
helm install apps-db-ha bitnami/postgresql-ha -n databases -f values.yaml
```

If any update is required, we need to provide the upgrade command with db password. This can be achieved using below commands

```bash
export PASSWORD=$(kubectl get secret --namespace databases apps-db-secret -o jsonpath="{.data.password}" | base64 -d)
export REPMGR_PASSWORD=$(kubectl get secret --namespace databases apps-db-secret -o jsonpath="{.data.repmgr-password}" | base64 -d)
export ADMIN_PASSWORD=$(kubectl get secret --namespace databases apps-db-ha-pgpool -o jsonpath="{.data.admin-password}" | base64 -d)

helm upgrade apps-db-ha bitnami/postgresql-ha \
 -n databases \
 -f values.yaml \
 --set postgresql.password=$PASSWORD \
  --set postgresql.repmgrPassword=$REPMGR_PASSWORD \
 --set pgpool.adminPassword=$ADMIN_PASSWORD
```

Important Commands

#### Remove folders

```bash
for i in 0 1 2; do   sudo rm -rf /srv/nfs/okd/data-apps-db-ha-postgresql-$i/*; done
```

#### Remove app

```bash
helm uninstall apps-db-ha -n databases
```

#### Remove pvc

```bash
oc delete pvc -n databases -l app.kubernetes.io/instance=apps-db-ha
```

#### Remove pv

```bash
oc delete pv data-apps-db-ha-postgresql-{0,1,2}
```
