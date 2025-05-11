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

## Prepare a Disk for NFS Storage

#### Partition and Format

````bash
sudo apt update
sudo apt install -y nfs-kernel-server
```bash

Use `lsblk` to identify the disk to be mounted

Partition the disk using Globally Unique Identifiers Partition Tables (GPT) Format. With GPT, you get up to 128 partitions by default and can choose to have many more.Once partitioned it needs to be formatted.

> [!TIP]
> Here we have 1 single partition. /dev/sdb is a 4Tb NAS Harddrive.

```bash
sudo parted /dev/sdb -- mklabel gpt
sudo parted -a optimal /dev/sdb -- mkpart primary ext4 0% 100%
sudo mkfs.ext4 /dev/sdb1 -L okd-nfs

sudo mkdir -p /srv/nfs/okd
sudo mount /dev/sdb1 /srv/nfs/okd
````

#### Mounting the disk and ownership

To make it permanent, add this to /etc/fstab:

```bash
echo '/dev/sdb1 /srv/nfs/okd ext4 defaults 0 2' | sudo tee -a /etc/fstab

sudo chown nobody:nogroup /srv/nfs/okd
sudo chmod 777 /srv/nfs/okd
```

#### NFS Configuration

```bash
echo '/srv/nfs/okd 192.168.122.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
sudo exportfs -rav
sudo systemctl restart nfs-server || sudo systemctl restart nfs-kernel-server
```

#### Mounting NFS in Workers

ssh into each worker and run

```bash
sudo mkdir -p /mnt/okd-nfs
sudo mount 192.168.122.1:/srv/nfs/okd /mnt/okd-nfs
echo '192.168.122.1:/srv/nfs/okd  /mnt/okd-nfs  nfs  defaults  0  0' | sudo tee -a /etc/fstab
```

> [!TIP]
> 192.168.122.1 - IP address of your Ubuntu host on the libvirt (KVM) network . To confirm it run 'ip addr show virbr0' an verify ip.
