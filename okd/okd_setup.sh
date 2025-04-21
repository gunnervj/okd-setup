#!/bin/bash

IGNITION_DIR="/mnt/okd-storage/cluster"
PORT=8080
HOST_IP=$(hostname -I | awk '{print $1}')
IGNITION_FILE="bootstrap.ign"
LOG_FILE="/tmp/ignition-server.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


bash "$SCRIPT_DIR/generate_okd_config.sh"

# Kill any existing python http.server processes on the same port
EXISTING_PID=$(lsof -ti tcp:$PORT)
if [[ -n "$EXISTING_PID" ]]; then
  echo "🔌 Shutting down existing server on port $PORT (PID: $EXISTING_PID)..."
  kill -9 $EXISTING_PID
else
  echo " No previous server detected on port $PORT."
fi

echo "🌐 Starting Python HTTP server to host Ignition files from $IGNITION_DIR on port $PORT..."
if [[ ! -d "$IGNITION_DIR" ]]; then
  echo " Ignition directory $IGNITION_DIR does not exist."
  exit 1
fi

cd "$IGNITION_DIR"
nohup python3 -m http.server "$PORT" --bind 0.0.0.0 > "$LOG_FILE" 2>&1 &

sleep 10

IGN_URL="http://$HOST_IP:$PORT/$IGNITION_FILE"


echo "Ignition server started in background. Logs: /tmp/ignition-server.log"


if curl -fsSL "$IGN_URL" > /dev/null; then
  echo "Ignition file is accessible!"
else
  echo "Failed to access Ignition file at $IGN_URL"
  echo "Check the server log: $LOG_FILE"
  exit 1
fi

echo "Completed OKD initial config setup...."