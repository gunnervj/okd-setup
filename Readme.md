# OKD Setup Script

### ENV Varibales

- OKD_PULL_SECRET: Need OKD Pull secret. This needs to be taken from your redhat account. Once acquired, set it in the environment variable by running.

```bash

export OKD_PULL_SECRET='<pull secret here>'

```

- SSH_PUB_KEY: Script will try to set this automatically from id_rsa.pub key in your user .ssh folder.

To start installation run `setup.sh`. This needs to be run as sudo and also pass in the environment variables.

```bash
sudo -E ./setup.sh

```

### Useful commands

#### Check status of bootstrapping from host machine.

```bash
sudo openshift-install --dir=/mnt/okd-storage/cluster wait-for bootstrap-complete --log-level=info
```

#### Approve pending certificates

```bash
oc get csr --no-headers | awk '/Pending/ {print $1}' | xargs -r oc adm certificate approve
```

#### Check the progress in bootstrap, maser and worker nodes after ssh into them.

```bash
sudo journalctl -f -u kubelet.service
```

#### Check the containers for bootstrap, master and worker nodes. Run inside the VM

```bash
sudo crictl ps -a
```

##### Describe machine configuration

```bash
oc describe machineconfigpool master
```

#### To get nodes, run

```bash
oc get nodes
```
