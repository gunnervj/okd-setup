#!/bin/bash

set -euo pipefail

OKD_DIR="$(dirname "$0")"
CONFIG_DIR="/mnt/okd-storage/cluster"
IGNITIONS=("bootstrap.ign" "master.ign" "worker.ign")


ls -l $CONFIG_DIR

for IGN in "${IGNITIONS[@]}"; do
cp "$CONFIG_DIR/$IGN" "$CONFIG_DIR/$IGN"
  INPUT_PATH="$CONFIG_DIR/$IGN"
  OUTPUT_PATH="$CONFIG_DIR/patched-$IGN"
  echo "Creating bck file for $INPUT_PATH"
  cp "$INPUT_PATH" "$INPUT_PATH.bck"

  if [[ ! -f "$INPUT_PATH" ]]; then
    echo "$INPUT_PATH does not exist. Skipping..."
    continue
  fi

  echo "🔧 Patching $INPUT_PATH..."

  jq '
    .storage.files += [
      {
        "path": "/etc/NetworkManager/system-connections/okd-enp1s0.nmconnection",
        "mode": 384,
        "overwrite": true,
        "contents": {
          "source": "data:text/plain;charset=utf-8;base64,W2Nvbm5lY3Rpb25dCmlkPW9rZC1lbnAxczAKdHlwZT1ldGhlcm5ldAppbnRlcmZhY2UtbmFtZT1lbnAxczAKCltpcHY0XQptZXRob2Q9YXV0bwpkbnM9MTkyLjE2OC4xMjIuOTk7CmRucy1zZWFyY2g9bGFiLm9rZC5sb2NhbDsKCltpcHY2XQptZXRob2Q9aWdub3Jl"
        }
      },
      {
        "path": "/etc/systemd/resolved.conf.d/00-bootstrap-dns.conf",
        "mode": 420,
        "overwrite": true,
        "contents": {
          "source": "data:text/plain;charset=utf-8;base64,W1Jlc29sdmVdCkROUz0xOTIuMTY4LjEyMi45OQpGYWxsYmFja0ROUz0KRG9tYWlucz1sYWIub2tkLmxvY2FsCg=="
        }
      },
      {
        "path": "/etc/resolv.conf",
        "mode": 420,
        "overwrite": true,
        "contents": {
          "source": "data:text/plain;charset=utf-8;base64,bmFtZXNlcnZlciAxOTIuMTY4LjEyMi45OQo="
        }
      },
      {
        "path": "/etc/nsswitch.conf",
        "mode": 420,
        "overwrite": true,
        "contents": {
          "source": "data:text/plain;charset=utf-8;base64,cGFzc3dkOiAgICAgICAgZmlsZXMgYWx0ZmlsZXMgc3NzIHN5c3RlbWQKc2hhZG93OiAgICAgICBmaWxlcwpncm91cDogICAgICAgIGZpbGVzIGFsdGZpbGVzIHNzcyBzeXN0ZW1kCmhvc3RzOiAgICAgICAgZmlsZXMgbXlob3N0bmFtZSByZXNvbHZlIGRucwpzZXJ2aWNlczogICAgIGZpbGVzIHNzcwpuZXRncm91cDogIGZpbGVzIHNzcwphdXRvbW91bnQ6ICBmaWxlcyBzc3MKYWxpYXNlczogICAgIGZpbGVzCmV0aGVyczogICAgICBmaWxlcwpnc2hhZG93OiAgICAgIGZpbGVzCm5ldHdvcmtzOiAgICAgZmlsZXMgZG5zCnByb3RvY29sczogICAgZmlsZXMKcHVibGlja2V5OiAgZmlsZXMKcnBjOiAgICAgICAgIGZpbGVzCg=="
        }
      }
    ] |
    .systemd.units += [
      {
        "name": "override-dns.service",
        "enabled": true,
        "contents": "[Unit]\nDescription=Override DNS to use custom resolver\nAfter=network-online.target systemd-resolved.service\nWants=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/systemctl restart systemd-resolved\n\n[Install]\nWantedBy=multi-user.target"
      }
    ]
  ' "$INPUT_PATH" > "$OUTPUT_PATH"

  cp "$OUTPUT_PATH" "$INPUT_PATH"
  echo "Successfully patched and replaced: $INPUT_PATH"
done