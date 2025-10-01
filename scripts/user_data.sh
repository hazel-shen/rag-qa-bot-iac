#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# ==== 基本更新 ====
dnf makecache
dnf -y upgrade

# ==== 必要工具（注意：不要裝 curl，AL2023 內建 curl-minimal 已可用） ====
dnf install -y git docker telnet python3-pip awscli jq

# Docker 開機自動 & 啟動
systemctl enable docker
systemctl start docker

# ==== SSM Agent（用官方套件庫，無需手動下載 rpm） ====
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# 等待 SSM Agent 啟動
for i in {1..10}; do
  sleep 3
  systemctl is-active --quiet amazon-ssm-agent && break || true
done

# ==== 資料夾與權限 ====
mkdir -p /opt/rag-qa-bot/data
# 你容器內預計使用 uid/gid=10001，這樣 chown 沒問題（就算宿主沒這個帳號）
chown -R 10001:10001 /opt/rag-qa-bot/data

# ==== Swap 2GB（保險） ====
if ! swapon --show | grep -q swapfile; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
  sysctl --system
fi

# ==== 從 S3 同步資料（需EC2角色具備 s3:GetObject 權限） ====
S3_BUCKET="rag-faq-bot-7882a6"
S3_PREFIX="tmp/"
echo "Downloading from s3://$S3_BUCKET/$S3_PREFIX ..."
aws s3 cp "s3://$S3_BUCKET/$S3_PREFIX" /opt/rag-qa-bot/data/ --recursive || true
echo "S3 download completed."

# ==== 安裝 Miniforge（aarch64） ====
CONDA_DIR=/opt/miniforge3
if [ ! -d "$CONDA_DIR" ]; then
  curl -fsSL https://github.com/conda-forge/miniforge/releases/download/25.3.1-0/Miniforge3-25.3.1-0-Linux-aarch64.sh -o /tmp/miniforge3.sh
  chmod +x /tmp/miniforge3.sh
  /tmp/miniforge3.sh -b -p ${CONDA_DIR}
  echo "export PATH=${CONDA_DIR}/bin:\$PATH" > /etc/profile.d/conda.sh
  chmod +x /etc/profile.d/conda.sh
  # 立即生效給本腳本使用
  export PATH=${CONDA_DIR}/bin:$PATH
  conda --version || true
fi

# ==== 安裝 cloudflared（aarch64 rpm） ====
# 也可改成下載靜態 binary：curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared
curl -fsSL -o /tmp/cloudflared.rpm https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-aarch64.rpm
dnf install -y /tmp/cloudflared.rpm || true

echo "User-data completed."
