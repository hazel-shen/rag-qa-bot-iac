#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# 更新套件索引 & 系統更新（安全性）
dnf makecache
dnf -y upgrade

# 安裝必要工具
dnf install -y git docker telnet pip

# 啟動 Docker
systemctl enable docker
systemctl start docker

# 安裝 SSM Agent（針對 ARM64 / x86_64）
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm
else
    dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
fi

# 啟用並啟動 Agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# 等待 SSM Agent 確認啟動
for i in {1..10}; do
    sleep 3
    systemctl is-active amazon-ssm-agent && break
done

# 建立應用目錄
mkdir -p /opt/ragqa
chown ec2-user:ec2-user /opt/ragqa

## 下載 conda
# 下載 Miniforge3 最新版本（ARM64）
curl -fsSL https://github.com/conda-forge/miniforge/releases/download/25.3.1-0/Miniforge3-25.3.1-0-Linux-aarch64.sh -o /tmp/miniforge3.sh

# 讓安裝檔可執行
chmod +x /tmp/miniforge3.sh

# 靜默安裝到指定目錄
/tmp/miniforge3.sh -b -p ${CONDA_DIR}

# 設 PATH
echo "export PATH=${CONDA_DIR}/bin:\$PATH" > /etc/profile.d/conda.sh
chmod +x /etc/profile.d/conda.sh
source /etc/profile.d/conda.sh

# 驗證
${CONDA_DIR}/bin/conda --version
