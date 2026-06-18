#!/usr/bin/env bash
# Monitoring VM bootstrap — RHEL 9 / Rocky Linux 9 (Prometheus + Grafana)
# Run as root on a fresh VM.
set -euo pipefail

INSTALL_DIR=/opt/ot-monitoring/monitoring

echo "=== [1/4] Install packages ==="
dnf update -y --quiet
dnf install -y --quiet podman podman-compose git

echo "=== [2/4] Copy project files ==="
mkdir -p "$INSTALL_DIR"
cp -r . "$INSTALL_DIR/"

echo "=== [3/4] Configure & start stack ==="
cd "$INSTALL_DIR"
cp .env.example .env
echo "Edit $INSTALL_DIR/.env with real credentials."

echo "=== [4/4] Pull images ==="
podman pull prom/prometheus:v2.52.0
podman pull grafana/grafana:11.0.0

echo ""
echo "Done. Edit .env then: podman-compose up -d"
