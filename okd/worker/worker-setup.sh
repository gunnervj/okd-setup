#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DEST_VMS_DIR="/mnt/okd-storage/vms"
DEST_IMAGES_DIR="/mnt/okd-storage/images"

BASE_ISO="${DEST_IMAGES_DIR}/worker.iso"
MEMORY=16384
VCPUS=4
DISK_SIZE=200G

# MAC address template base
BASE_MAC="52:54:00:00:00:2"

echo "********Creating worker.iso ********"
  export PATH="$HOME/.cargo/bin:$PATH"
  rm -fv /mnt/okd-storage/images/worker.iso

coreos-installer iso ignition embed \
    -i "$(dirname "$0")/worker-autoinstall.ign" \
    -o /mnt/okd-storage/images/worker.iso \
    "$(dirname "$0")/worker.iso"

echo "********Created worker.iso********"

echo " Starting creation of worker nodes..."

for i in 1 2 3; do
  VM_NAME="worker-${i}-vm"
  VM_IMG="${DEST_VMS_DIR}/worker-${i}.qcow2"
  MAC_ADDRESS="${BASE_MAC}${i}"

  echo "Creating disk image for ${VM_NAME}"
  sudo qemu-img create -f qcow2 "${VM_IMG}" "${DISK_SIZE}"

  echo " Creating ${VM_NAME} with MAC ${MAC_ADDRESS}"

  virt-install \
    --name "${VM_NAME}" \
    --ram "${MEMORY}" \
    --vcpus "${VCPUS}" \
    --os-variant fedora-coreos-stable \
    --disk path="${VM_IMG}" \
    --cdrom "${BASE_ISO}" \
    --network network=default,mac="${MAC_ADDRESS}" \
    --graphics vnc,listen=0.0.0.0 \
    --console pty,target_type=serial \
    --boot cdrom,hd \
    --noautoconsole

  echo " ${VM_NAME} launched. It will shutdown after fetching worker.ign"
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

done

echo " Sleeping for 60 minutes to allow workers to initialize..."
echo "To approve pending certificates, run 'oc get csr --no-headers | awk '/Pending/ {print $1}' | xargs -r oc adm certificate approve'"
echo "To check progress, run 'oc get mc'"
sleep 3600
echo " Done sleeping. Check cluster status."