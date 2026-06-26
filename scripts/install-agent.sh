#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="${1:-$(pwd)}"
AGENT_SRC="$SOURCE_DIR/cmd/tunnelmod-agent/main.go"
AGENT_OUT="/usr/local/sbin/tunnelmod-agent"

if [[ ! -f "$AGENT_SRC" ]]; then
  echo "TunnelMod Go agent source not found; skipping."
  exit 0
fi

if ! command -v go >/dev/null 2>&1; then
  echo "Installing Go compiler for TunnelMod agent..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y golang-go
fi

echo "Building TunnelMod Go agent..."
(
  cd "$SOURCE_DIR"
  CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o "$AGENT_OUT" ./cmd/tunnelmod-agent
)
chmod 755 "$AGENT_OUT"
"$AGENT_OUT" traffic-stats >/dev/null || true
echo "TunnelMod Go agent installed: $AGENT_OUT"
