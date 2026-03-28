#!/bin/bash
set -euo pipefail

BASE_URL="https://scagnozz.com/cli"
VERSION="0.1.0"
INSTALL_DIR="${SCAGNOZZ_BIN_DIR:-$HOME/.local/bin}"

detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    linux)  os="linux" ;;
    darwin) os="darwin" ;;
    *)      echo "Sistema operativo non supportato: $os" >&2; exit 1 ;;
  esac

  case "$arch" in
    x86_64|amd64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)             echo "Architettura non supportata: $arch" >&2; exit 1 ;;
  esac

  echo "${os}-${arch}"
}

main() {
  local platform binary_name url

  echo "Installazione Scagnozz CLI v${VERSION}..."
  echo

  platform="$(detect_platform)"
  binary_name="scagnozz-${platform}"
  url="${BASE_URL}/${binary_name}"

  echo "  Piattaforma: ${platform}"
  echo "  Download: ${url}"
  echo "  Installazione in: ${INSTALL_DIR}"
  echo

  mkdir -p "$INSTALL_DIR"

  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "${INSTALL_DIR}/scagnozz"
  elif command -v wget &>/dev/null; then
    wget -qO "${INSTALL_DIR}/scagnozz" "$url"
  else
    echo "Errore: curl o wget richiesto" >&2
    exit 1
  fi

  chmod +x "${INSTALL_DIR}/scagnozz"

  echo "Scagnozz CLI installato in ${INSTALL_DIR}/scagnozz"
  echo

  # Check PATH
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo "Aggiungi ${INSTALL_DIR} al tuo PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
  fi

  echo "Esegui 'scagnozz setup' per configurare."
}

main
