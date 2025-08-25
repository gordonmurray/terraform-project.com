#!/bin/bash
set -euo pipefail

RDS_ENDPOINT="${rds_endpoint}"
DB_USER="${db_user}"
DB_PASS='${db_pass}'
DB_NAME="${db_name}"

yum update -y
yum install -y docker amazon-ssm-agent
systemctl enable --now docker
systemctl enable --now amazon-ssm-agent
usermod -a -G docker ec2-user
# Add ssm-user to docker group when it gets created
echo 'usermod -a -G docker ssm-user 2>/dev/null || true' >> /etc/rc.local
chmod +x /etc/rc.local

# Install and configure Ollama
curl -fsSL https://ollama.com/install.sh | sh
# Create a systemd override to make Ollama listen on all interfaces
mkdir -p /etc/systemd/system/ollama.service.d
cat <<EOF > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
systemctl daemon-reload
systemctl restart ollama

sudo dnf install -y mariadb105

# Wait for RDS to accept connections (up to ~5 min)
for i in {1..60}; do
  if mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

# Seed schema
mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASS" <<'SQL'
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) UNIQUE NOT NULL,
  hashed_password VARCHAR(128) NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(100) NOT NULL,
  stored_name VARCHAR(255) NOT NULL,
  size_bytes INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username, hashed_password) VALUES ('admin','$2b$12$O1LVToXW/8W/ZQhfDs1ViezYGC.PX0Nn5cdV1d4GSdTYOyF/U7CAy');
SQL