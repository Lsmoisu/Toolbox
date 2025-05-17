#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 检查 /opt/socks.txt 文件是否存在
if [ -f "/opt/socks.txt" ]; then
    echo -e "${RED}Error: /opt/socks.txt already exists. Script will exit to avoid overwriting existing configuration.${NC}"
    echo -e "${RED}If you want to re-run the script, please remove /opt/socks.txt first.${NC}"
    exit 1
fi

# 检查是否为 root 用户或通过 sudo 运行
if [ "$EUID" -ne 0 ]; then
    if [ -z "$SUDO_USER" ]; then
        echo -e "${RED}Error: This script must be run as root or with sudo!${NC}"
        echo -e "${RED}Please run: sudo $0${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Starting SSH and Gost configuration...${NC}"

# 1. 配置 SSH 允许 root 登录和公钥认证
echo -e "${GREEN}Configuring SSH to allow root login and public key authentication...${NC}"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
# 确保 authorized_keys 文件路径正确
sed -i 's/#AuthorizedKeysFile .ssh\/authorized_keys/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
# 创建 SSH 目录和文件（如果不存在）
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
# 重启 SSH 服务
systemctl restart sshd
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SSH configuration completed and service restarted.${NC}"
    echo -e "${GREEN}SSH is now configured to allow root login and public key authentication.${NC}"
    echo -e "${GREEN}To enable passwordless login, add your public key to /root/.ssh/authorized_keys.${NC}"
else
    echo -e "${RED}Failed to restart SSH service.${NC}"
    exit 1
fi

# 2. 安装 Gost
echo -e "${GREEN}Installing Gost...${NC}"
# 获取最新版本号
LATEST_VERSION=$(curl -s https://api.github.com/repos/ginuerzh/gost/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}Failed to fetch the latest Gost version.${NC}"
    exit 1
fi

# 下载最新版本的 Gost
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/${LATEST_VERSION}/gost_${LATEST_VERSION#v}_linux_amd64.tar.gz"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/${LATEST_VERSION}/gost_${LATEST_VERSION#v}_linux_arm64.tar.gz"
else
    echo -e "${RED}Unsupported architecture: $ARCH${NC}"
    exit 1
fi

# 下载文件
wget -O gost.tar.gz "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download Gost.${NC}"
    exit 1
fi

# 解压到临时目录并移动到目标位置
mkdir -p /tmp/gost
tar -xzf gost.tar.gz -C /tmp/gost
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to extract Gost.${NC}"
    rm -rf gost.tar.gz /tmp/gost
    exit 1
fi

# 查找解压后的 gost 可执行文件并移动到 /usr/local/bin/
GOST_BIN=$(find /tmp/gost -type f -name "gost" | head -n 1)
if [ -z "$GOST_BIN" ]; then
    echo -e "${RED}Failed to find Gost binary in extracted files.${NC}"
    rm -rf gost.tar.gz /tmp/gost
    exit 1
fi

mv "$GOST_BIN" /usr/local/bin/gost
chmod +x /usr/local/bin/gost
rm -rf gost.tar.gz /tmp/gost

if ! command -v gost &> /dev/null; then
    echo -e "${RED}Gost installation failed.${NC}"
    exit 1
fi
echo -e "${GREEN}Gost installed successfully.${NC}"

# 3. 生成随机用户名和密码
USERNAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
PORT=12333

# 4. 创建 Gost 配置文件（适用于 v2.12.0）
echo -e "${GREEN}Creating Gost configuration...${NC}"
mkdir -p /etc/gost
cat > /etc/gost/config.json <<EOF
{
    "ServeNodes": [
        "socks5://:$PORT?username=$USERNAME&password=$PASSWORD"
    ]
}
EOF

# 5. 创建 Gost 系统服务
echo -e "${GREEN}Creating Gost systemd service...${NC}"
cat > /etc/systemd/system/gost.service <<EOF
[Unit]
Description=Gost Proxy Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/gost
ExecStart=/usr/local/bin/gost -C /etc/gost/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动并启用 Gost 服务
systemctl daemon-reload
systemctl enable gost
systemctl start gost
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Gost service started and enabled on boot.${NC}"
else
    echo -e "${RED}Failed to start Gost service.${NC}"
    exit 1
fi

# 7. 获取本机公网 IP
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s ipinfo.io/ip)
fi
if [ -z "$PUBLIC_IP" ]; then
    echo -e "${RED}Failed to get public IP address.${NC}"
    exit 1
fi

# 8. 输出 Socks5 连接信息到文件
SOCKS_URL="socks5://$PUBLIC_IP:$PORT:$USERNAME:$PASSWORD"
echo "$SOCKS_URL" > /opt/socks.txt
echo -e "${GREEN}Socks5 connection info saved to /opt/socks.txt${NC}"
echo -e "${GREEN}Connection URL: $SOCKS_URL${NC}"

echo -e "${GREEN}All tasks completed successfully!${NC}"
