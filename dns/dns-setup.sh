#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
VM_NAME="dns-vm"
BASE_IMG="${SCRIPT_DIR}/ubuntu-server.img"
VM_IMG="${SCRIPT_DIR}/${VM_NAME}.qcow2"
ISO_IMG="${SCRIPT_DIR}/${VM_NAME}.iso"
DEST_VM_IMG="/mnt/okd-storage/vms/${VM_NAME}.qcow2"
DEST_ISO_IMG="/mnt/okd-storage/images/${VM_NAME}.iso"
MAC_ADDRESS="52:54:00:00:00:99"
MEMORY=2048
VCPUS=2

for f in user-data.template meta-data do
  if [[ ! -f "${SCRIPT_DIR}/${f}" ]]; then
    echo "Required file missing: ${SCRIPT_DIR}/${f}"
    exit 1
  fi
done

if [[ -z "$SSH_PUB_KEY" ]]; then
  echo "SSH_PUB_KEY environment variable is not set."
  exit 1
fi

if ! command -v cloud-localds &>/dev/null; then
  echo "Installing cloud-image-utils..."
  sudo apt update && sudo apt install -y cloud-image-utils
fi

echo "Creating VM disk image..."
cp "${BASE_IMG}" "${VM_IMG}"
qemu-img resize "${VM_IMG}" 10G

echo "Generating user-data from template..."
envsubst '${SSH_PUB_KEY}' < "$SCRIPT_DIR/user-data.template" > "$SCRIPT_DIR/user-data"

echo " Generating cloud-init ISO..."
cloud-localds "${ISO_IMG}" "${SCRIPT_DIR}/user-data" "${SCRIPT_DIR}/meta-data"

echo " Copying disk and ISO to KVM directories..."
sudo cp "${VM_IMG}" "${DEST_VM_IMG}"
sudo cp "${ISO_IMG}" "${DEST_ISO_IMG}"

echo "Launching the VM..."
sudo virt-install \
  --name "${VM_NAME}" \
  --memory "${MEMORY}" \
  --vcpus "${VCPUS}" \
  --os-variant ubuntu22.04 \
  --disk path="${DEST_VM_IMG}",format=qcow2 \
  --disk path="${DEST_ISO_IMG}",device=cdrom \
  --import \
  --graphics none \
  --network network=default,mac="${MAC_ADDRESS}" \
  --console pty,target_type=serial \
  --boot cdrom,hd \
  --noautoconsole

echo "DNS VM '${VM_NAME}' installation initiated."
echo "Waiting 10 minutes for DNS VM to finish initialization..."
sleep 600