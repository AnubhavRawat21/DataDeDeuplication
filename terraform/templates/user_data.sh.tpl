#!/bin/bash
set -uxo pipefail

# ── CloudSieve Pro EC2 Bootstrap Script (ap-southeast-2) ──
echo "[CloudSieve] Starting automated provisioning..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ── 1. Create Swap Space (2 GB) ──
if [ ! -f /swapfile ]; then
    echo "[CloudSieve] Configuring 2GB swap space..."
    fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ── 2. Install Prerequisites ──
apt-get install -y ca-certificates curl gnupg lsb-release git unzip jq

# ── 3. Install Docker Engine & Docker Compose Plugin ──
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)

echo "deb [arch=$${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# ── 4. Optional Amazon CloudWatch Unified Agent ──
if [ "${enable_cloudwatch_logs}" = "true" ] && [ -n "${log_group_name}" ]; then
    echo "[CloudSieve] Installing Amazon CloudWatch Unified Agent..."
    CW_AGENT_URL="https://s3.${aws_region}.amazonaws.com/amazoncloudwatch-agent-${aws_region}/ubuntu/$${ARCH}/latest/amazon-cloudwatch-agent.deb"
    curl -fsSL "$${CW_AGENT_URL}" -o /tmp/amazon-cloudwatch-agent.deb || true
    dpkg -i -E /tmp/amazon-cloudwatch-agent.deb || true

    cat <<CW_EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CloudSieve/EC2",
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "resources": [
          "/"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}-syslog"
          },
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}-cloud-init"
          }
        ]
      }
    }
  }
}
CW_EOF

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json || true
fi

# ── 5. Prepare Application Directories & Clone Repository ──
mkdir -p /opt/cloudsieve
mkdir -p /var/cloudsieve/uploads /var/cloudsieve/outputs
chmod -R 777 /var/cloudsieve

echo "[CloudSieve] Cloning repository ${github_repo_url} (branch: ${github_branch})..."
git clone -b "${github_branch}" "${github_repo_url}" /opt/cloudsieve/app

cd /opt/cloudsieve/app/docker

# ── 6. Build and Launch Containers via Docker Compose ──
echo "[CloudSieve] Building and launching containers..."
docker compose up -d --build

# ── 7. Configure Systemd Service for Persistence on Boot ──
cat <<SERVICE_EOF > /etc/systemd/system/cloudsieve.service
[Unit]
Description=CloudSieve Pro Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/opt/cloudsieve/app/docker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable cloudsieve.service

echo "[CloudSieve] Bootstrap complete! Application is running on port 80."
