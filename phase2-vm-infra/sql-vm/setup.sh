#!/usr/bin/env bash
# SQL VM bootstrap — installs SQL Server 2022 on RHEL 9 / Rocky Linux 9.
# Run as root on a fresh VM.
set -euo pipefail

echo "=== [1/4] Add Microsoft SQL Server repo ==="
curl -o /etc/yum.repos.d/mssql-server.repo \
  https://packages.microsoft.com/config/rhel/9/mssql-server-2022.repo
curl -o /etc/yum.repos.d/msprod.repo \
  https://packages.microsoft.com/config/rhel/9/prod.repo

echo "=== [2/4] Install SQL Server ==="
dnf install -y mssql-server
/opt/mssql/bin/mssql-conf setup   # interactive: set SA password + edition

echo "=== [3/4] Install sqlcmd ==="
ACCEPT_EULA=Y dnf install -y mssql-tools18 unixODBC-devel
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/profile.d/mssql.sh
source /etc/profile.d/mssql.sh

echo "=== [4/4] Firewall ==="
firewall-cmd --permanent --add-port=1433/tcp
firewall-cmd --reload

echo ""
echo "SQL Server installed. Run the schema scripts:"
echo "  sqlcmd -S localhost -U SA -P '<password>' -i /opt/ot-monitoring/sql/01_create_tables.sql"
echo "  sqlcmd -S localhost -U SA -P '<password>' -i /opt/ot-monitoring/sql/02_seed_downtime_reasons.sql"
echo "  sqlcmd -S localhost -U SA -P '<password>' -i /opt/ot-monitoring/sql/03_create_views.sql"
