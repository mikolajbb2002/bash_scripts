#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="/opt/payment-api-lab"
SERVICE_NAME="payment-api.service"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "[ERROR] This lab requires Linux with systemd; macOS is not supported." >&2
  echo "[ERROR] Run setup_lab.sh inside a Linux VM with systemd or on a Linux host." >&2
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
  echo "[ERROR] This lab requires a Linux system running systemd." >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Run this installer as root: sudo bash setup_lab.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] Creating lab directory: ${LAB_DIR}"
mkdir -p "${LAB_DIR}"

echo "[INFO] Copying app.py"
cp "${SCRIPT_DIR}/app.py" "${LAB_DIR}/app.py"
chmod +x "${LAB_DIR}/app.py"

echo "[INFO] Installing systemd service"
cp "${SCRIPT_DIR}/payment-api.service" "/etc/systemd/system/${SERVICE_NAME}"

echo "[INFO] Reloading systemd"
systemctl daemon-reload

echo "[INFO] Enabling service"
systemctl enable payment-api

echo "[INFO] Starting service"
systemctl restart payment-api

echo "[INFO] Current service status:"
systemctl --no-pager --full status payment-api || true

echo "[INFO] Health check:"
curl -s http://localhost:8080/health || true

echo "[INFO] Lab setup complete."
