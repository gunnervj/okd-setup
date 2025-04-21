#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
  echo "X Please run this script as root or with sudo"
  exit 1
fi

export SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)"

ask_step() {
  local prompt="$1"
  read -p "$prompt [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

if ask_step "Install and configure KVM + libvirt packages?"; then
  echo "******** SETTING UP PACKAGES 📦 📦 📦 *************"

  apt update && apt upgrade -y
  apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager cpu-checker

  kvm-ok || { echo " KVM is not supported on this system"; exit 1; }

  systemctl enable --now libvirtd
  systemctl start libvirtd

  echo "******** PACKAGE SETUP COMPLETED *************"

  echo "******** ADDING CURRENT USER 🧍🏻 ($SUDO_USER) TO libvirt AND kvm GROUPS ********"

  usermod -aG libvirt,kvm "$SUDO_USER"
  echo "Please log out and log back in or run 'newgrp libvirt' to apply group changes."

else
  echo "Skipping package setup"
fi

if ask_step "📁 Create and set permissions for directories under /mnt/okd-storage?"; then
  echo "******** SETTING UP DIRECTORIES 📁 for KVM ********"

  BASE_DIR="/mnt/okd-storage"
  SUBDIRS=("cluster" "ignition" "images" "vms")
  LIBVIRT_GROUP="libvirt-qemu"

  if ! mount | grep -q "$BASE_DIR"; then
    echo "$BASE_DIR is not mounted. Please mount the storage volume and try again."
    exit 1
  fi

  for dir in "${SUBDIRS[@]}"; do
    full_path="$BASE_DIR/$dir"
    if [[ ! -d "$BASE_DIR/$dir" ]]; then
      mkdir -p "$BASE_DIR/$dir"
      echo "Created : $BASE_DIR/$dir"
      echo " Now Changing Permissions"
      chown -R root:$LIBVIRT_GROUP "$full_path"
      chmod -R 770 "$full_path"
      echo " Permissions set: owner=root, group=$LIBVIRT_GROUP, mode=770"
    else
      echo " Already exists: $BASE_DIR/$dir"
    fi


    if command -v getenforce &>/dev/null && [[ "$(getenforce)" != "Disabled" ]]; then
      chcon -R --type=virt_image_t "$full_path"
      echo " SELinux context set: virt_image_t"
    fi
  done
  echo "******** DIRECTORY SETUP COMPLETED *************"
else
  echo "Skipping directory creation"
fi

if ask_step "Setup libvirt network now?"; then
  echo "******** SETTING UP NETWORK ********"
  bash "$(dirname "$0")/network/setup-libvirt-network.sh"
  echo "********NETWORK SETUP COMPLETED ********"
else
  echo "Skipping network setup"
fi

if ask_step "Setup DNS now?"; then
  echo "******** SETTING UP DNS ********"
  bash "$(dirname "$0")/dns/dns-setup.sh"
  echo "******** DNS SETUP COMPLETED ********"
else
  echo "Skipping dns setup"
fi

if ask_step "Setup okd-services now?"; then
  echo "******** SETTING UP okd-services ⚙️ ********"
  bash "$(dirname "$0")/okd-services/okd-services-setup.sh"
  echo "********okd-services SETUP COMPLETED ********"
else
  echo "Skipping okd-services setup"
fi

if ask_step "Restart services now?"; then
  echo "********Shutting down dns-vm ********"
  virsh destroy dns-vm
  sleep 30
  echo "********Shutting okd-services ********"
  virsh destroy okd-services
  sleep 30
  echo "********Shutdown complete ********"

  echo "********Shutting down network ********"
  virsh net-destroy default
  sleep 60
  echo "********Network shutdown complete ********"

  echo "********Starting network ********"
  virsh net-start default
  sleep 30
  echo "********Network started ********"

  echo "******** ⚙️ Starting dns ********"
  virsh start dns-vm
  sleep 60
  echo "********dns started ********"

  echo "********Starting okd-services ********"
  virsh start okd-services
  sleep 60
  echo "********okd-services started ********"
fi

echo "********  SETTING UP OKD ENVIRONMENT ********"

if ask_step "Generate OKD Configs and Ignitions?"; then
  bash "$(dirname "$0")/okd/okd_setup.sh"
  echo "******** Generated configurations and ignitions. Bootstrap, Master and Compute Nodes needs to be set manually ********"
else
  echo "Skipping OKD Configs and Ignitions generation.."
fi

if ask_step "Create Bootstrap VM ?"; then
  echo "INITIALIZING BOOTSTRAP SETUP....."
  echo " VM will shutdown after initial ignition fetch. Manual Restart is reguired."
  bash "$(dirname "$0")/okd/bootstrap/bootstrap-setup.sh"
  echo " BOOTSTRAPING MUST BE COMPLETED before continuing."
  echo " Check status using 'sudo journalctl -u bootkube -f' "
  echo " Check if port is open by running 'sudo ss -tuln | grep 22623' " 
else
  echo "Skipping bootstrap VM creation"
fi

if ask_step "Create Matser VM ?"; then
  echo "INITIALIZING MASTER SETUP....."
  bash "$(dirname "$0")/okd/master/master-setup.sh"
else
  echo "Skipping Master/ControlPlane VM creation"
fi

if ask_step "Create Worker VM ?"; then
  echo "INITIALIZING WORKER SETUP....."
  bash "$(dirname "$0")/okd/worker/worker-setup.sh"
else
  echo "Skipping Worker VM creation"
fi



echo "********  SETTING UP OKD ENVIRONMENT COMPLETED ********"

