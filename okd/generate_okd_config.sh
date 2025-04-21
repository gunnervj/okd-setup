set -euo pipefail

OKD_DIR="$(dirname "$0")"
TEMPLATE_FILE="$OKD_DIR/install-config.template"
CONFIG_DIR="/mnt/okd-storage/cluster"
INSTALL_CONFIG="$CONFIG_DIR/install-config.yaml"

if [[ -z "${SSH_PUB_KEY:-}" ]]; then
  echo "SSH_PUB_KEY environment variable is not set."
  exit 1
fi

if [[ -z "${OKD_PULL_SECRET:-}" ]]; then
  echo "OKD_PULL_SECRET environment variable is not set."
  exit 1
fi

sudo rm -r "$CONFIG_DIR"
echo "Deleted $CONFIG_DIR"
sudo mkdir -p "$CONFIG_DIR"
echo "Re-Created $CONFIG_DIR"
export SSH_PUB_KEY OKD_PULL_SECRET
envsubst < "$TEMPLATE_FILE" > "$INSTALL_CONFIG"

echo "install-config.yaml generated at $INSTALL_CONFIG"

cp "$INSTALL_CONFIG" "$INSTALL_CONFIG.bak"

openshift-install create manifests --dir="$CONFIG_DIR"

echo "Manifests created"

openshift-install create ignition-configs --dir="$CONFIG_DIR"

echo "Ignition configs created"

ls -lh "$CONFIG_DIR"/*.ign

echo "******** Patching Ignitions ********"
bash "$(dirname "$0")/patch-ignitions.sh"
echo "********  Patching Ignitions Complete********"

