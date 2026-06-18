#!/usr/bin/env bash
# Collector VM bootstrap — RHEL 9 / Rocky Linux 9
# Run as root on a fresh VM.
set -euo pipefail

INSTALL_DIR=/opt/ot-monitoring/telegraf

echo "=== [1/5] System update ==="
dnf update -y --quiet

echo "=== [2/5] Install packages ==="
dnf install -y --quiet podman git chrony

echo "=== [3/5] Configure NTP (chrony) ==="
systemctl enable --now chronyd
timedatectl set-ntp true

echo "=== [4/5] Install project files ==="
mkdir -p "$INSTALL_DIR"
cp telegraf/telegraf.conf       "$INSTALL_DIR/telegraf.conf"
cp telegraf/telegraf-vlan-low.conf "$INSTALL_DIR/telegraf-vlan-low.conf"
cp .env.example                "$INSTALL_DIR/.env"
echo "Edit $INSTALL_DIR/.env with real credentials before starting the service."

echo "=== [5/5] Install & enable systemd unit ==="
cp systemd/telegraf-podman.service /etc/systemd/system/telegraf-podman.service
systemctl daemon-reload
systemctl enable telegraf-podman

# Pull image before first start
podman pull telegraf:1.30

echo ""
echo "Done. Edit $INSTALL_DIR/.env then: systemctl start telegraf-podman"
echo "Status: systemctl status telegraf-podman"
echo "Logs:   journalctl -u telegraf-podman -f"
