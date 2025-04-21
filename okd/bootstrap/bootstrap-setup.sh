#!/bin/bash

VM_NAME="bootstrap-vm"
VM_IMG="${SCRIPT_DIR}/bootstrap.qcow2"
DEST_VM_IMG="/mnt/okd-storage/vms/bootstrap.qcow2"
DEST_ISO_IMG="/mnt/okd-storage/images/bootstrap.iso"
MAC_ADDRESS="52:54:00:00:00:10"
MEMORY=8192
VCPUS=4
DISK_SIZE=100G

echo " CREATING BOOTSTRAP VM DISK : ${DISK_SIZE}"

sudo qemu-img create -f qcow2 /mnt/okd-storage/vms/bootstrap.qcow2 "${DISK_SIZE}"

echo " CREATING BOOTSTRAP VM"

echo "******** Creating bootstrap.iso ********"
export PATH="$HOME/.cargo/bin:$PATH"
rm -fv /mnt/okd-storage/images/bootstrap.iso
coreos-installer iso ignition embed \
  -i "$(dirname "$0")/bootstrap-autoinstall.ign" \
  -o /mnt/okd-storage/images/bootstrap.iso \
  "$(dirname "$0")/bootstrap.iso"

echo "********Created bootstrap.iso ********"

virt-install \
  --name "${VM_NAME}" \
  --ram "${MEMORY}" \
  --vcpus "${VCPUS}" \
  --os-variant fedora-coreos-stable \
  --disk path="${DEST_VM_IMG}" \
  --cdrom "${DEST_ISO_IMG}" \
  --network network=default,mac="${MAC_ADDRESS}" \
  --graphics vnc,listen=0.0.0.0 \
  --console pty,target_type=serial \
  --boot cdrom,hd \
  --noautoconsole

echo "CREATED BOOTSTRAP VM"
echo "BOOTSTRAP VM will shutdown soon. Start it manually by using 'virsh start ${VM_NAME}'"

while true; do
    STATUS=$(virsh dominfo "$VM_NAME" | grep -i "^State:" | awk '{print $2}')

    if [[ "$STATUS" == "shut" ]]; then
        echo "$VM_NAME is shut off. Starting it now..."
        virsh start "$VM_NAME"
        echo "$VM_NAME has been started after ignition fetch. Exiting."
        break
    fi

    sleep 5
done

sleep 1000


 