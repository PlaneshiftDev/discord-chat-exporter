#!/usr/bin/env bash
# Install DiscordChatExporter.Cli + the `dce` wrapper + a token env template.
# Idempotent: re-running upgrades the CLI in place and leaves your token file alone.
#
#   ./install.sh                 # latest upstream release, auto-detected platform
#   DCE_VERSION=2.48 ./install.sh
#   DCE_PLATFORM=linux-arm64 ./install.sh
#   DCE_HOME=/opt/dce ./install.sh
set -euo pipefail

DCE_HOME="${DCE_HOME:-$HOME/discord-chat-exporter}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
ENV_FILE="${ENV_FILE:-$HOME/.config/dce/env}"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

detect_platform() {
  local os arch
  os="$(uname -s)"; arch="$(uname -m)"
  case "$os" in
    Linux)  case "$arch" in
              x86_64|amd64) if ldd --version 2>&1 | grep -qi musl; then echo linux-musl-x64; else echo linux-x64; fi ;;
              aarch64|arm64) echo linux-arm64 ;;
              armv7l|armv6l) echo linux-arm ;;
              *) echo "unsupported arch: $arch" >&2; exit 1 ;;
            esac ;;
    Darwin) case "$arch" in
              arm64) echo osx-arm64 ;;
              x86_64) echo osx-x64 ;;
              *) echo "unsupported arch: $arch" >&2; exit 1 ;;
            esac ;;
    *) echo "unsupported OS: $os (Windows: download the .zip from the releases page)" >&2; exit 1 ;;
  esac
}

PLATFORM="${DCE_PLATFORM:-$(detect_platform)}"

command -v curl >/dev/null || { echo "missing dependency: curl" >&2; exit 1; }
# unzip is missing on minimal images (Debian cloud / LXC templates); python3 rarely is.
if command -v unzip >/dev/null; then
  extract() { unzip -q -o "$1" -d "$2"; }
elif command -v python3 >/dev/null; then
  extract() { python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$1" "$2"; }
else
  echo "missing dependency: unzip (or python3 as a fallback)" >&2; exit 1
fi

if [[ -n "${DCE_VERSION:-}" ]]; then
  URL="https://github.com/Tyrrrz/DiscordChatExporter/releases/download/${DCE_VERSION}/DiscordChatExporter.Cli.${PLATFORM}.zip"
else
  URL="https://github.com/Tyrrrz/DiscordChatExporter/releases/latest/download/DiscordChatExporter.Cli.${PLATFORM}.zip"
fi

echo "==> Installing DiscordChatExporter.Cli (${PLATFORM}) to ${DCE_HOME}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# -sS: quiet but still reports errors. Never use a progress bar here — agent shells and CI
# logs buffer \r redraws into one enormous line.
curl -sSL --fail -o "$TMP/dce.zip" "$URL"
mkdir -p "$DCE_HOME"
extract "$TMP/dce.zip" "$DCE_HOME"
chmod +x "$DCE_HOME/DiscordChatExporter.Cli"

echo "==> Installing wrapper to ${BIN_DIR}/dce"
mkdir -p "$BIN_DIR"
install -m 0755 "$REPO_DIR/bin/dce" "$BIN_DIR/dce"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> Creating token file ${ENV_FILE} (mode 600)"
  mkdir -p "$(dirname "$ENV_FILE")"
  install -m 0600 "$REPO_DIR/config/env.example" "$ENV_FILE"
else
  echo "==> Token file ${ENV_FILE} already exists — leaving it alone"
fi
chmod 600 "$ENV_FILE" 2>/dev/null || true

echo
echo "Installed: $("$DCE_HOME/DiscordChatExporter.Cli" --version 2>/dev/null || echo '(version check failed)')"
echo
echo "Next steps:"
echo "  1. Put your token in ${ENV_FILE}   (DISCORD_TOKEN=...)"
echo "  2. Ensure ${BIN_DIR} is on your PATH"
echo "  3. Verify:  dce guilds"
