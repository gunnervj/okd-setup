#!/bin/bash

set -e

NETWORK_NAME="default"
NETWORK_XML="/tmp/${NETWORK_NAME}.xml"

echo "🔧 Destroying and undefining existing network: $NETWORK_NAME"
virsh net-destroy "$NETWORK_NAME" 2>/dev/null || true
virsh net-undefine "$NETWORK_NAME" 2>/dev/null || true

echo "Writing custom network config to $NETWORK_XML"

cat > "$NETWORK_XML" <<EOF
<network>
  <name>default</name>
  <uuid>952167da-1549-4de2-bbac-05d17aaa1b7a</uuid>
  <forward mode='route'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:97:b2:72'/>
  <dns>
    <forwarder addr='192.168.122.99'/>
  </dns>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <host mac='52:54:00:00:00:02' name='okd-services' ip='192.168.122.2'/>
      <host mac='52:54:00:00:00:10' name='bootstrap' ip='192.168.122.10'/>
      <host mac='52:54:00:00:00:11' name='master-1' ip='192.168.122.11'/>
      <host mac='52:54:00:00:00:12' name='master-2' ip='192.168.122.12'/>
      <host mac='52:54:00:00:00:13' name='master-3' ip='192.168.122.13'/>
      <host mac='52:54:00:00:00:21' name='worker-1' ip='192.168.122.21'/>
      <host mac='52:54:00:00:00:22' name='worker-2' ip='192.168.122.22'/>
      <host mac='52:54:00:00:00:23' name='worker-3' ip='192.168.122.23'/>
      <host mac='52:54:00:00:00:99' name='dns-vm' ip='192.168.122.99'/>
    </dhcp>
  </ip>
</network>
EOF

echo "Defining new libvirt network..."
virsh net-define "$NETWORK_XML"

echo "Starting network: $NETWORK_NAME"
virsh net-start "$NETWORK_NAME"

echo "Autostart enabled for network: $NETWORK_NAME"
virsh net-autostart "$NETWORK_NAME"

echo "Network '$NETWORK_NAME' has been recreated and started successfully!"