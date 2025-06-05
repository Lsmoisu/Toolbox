#!/bin/bash
#添加公钥并配置ssh免密登录

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
    echo "此脚本需要以root权限运行，请使用sudo或切换到root用户"
    exit 1
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#ENCRYPTED_KEY="U2FsdGVkX1/oUblppLtZwhOEcBI+mKBcOna10SHSJ5Jq2ZbSeyDj12WnXB4UxOH4EHsQeWhyus4apPYsWelvu+gmhwbeN8xh0yNZcipBZR0rEUehsOBFZ6Y3uegbpRHYedJXFp8ufqPGrom7w0dIyn7zMxPZzXnD4zS8MvaQMqa+XqeepfIfFUJJGR8kVxPON9EKco5XRKhsa0piyFIuWd68QnEpiArN7MUaiFY5jpLJT0hlixL4rp+oJPKWJN3jrGeuvUg1tPkgiJKXHy/WUHSdf9yH0CZQfj+V3Ax/MKVEiwXjpkXurpawpwAKdH0aliyw4mtU/oN1oRpFqpddstcgNzOEWBp27FkgsGobkEFSNmYdpLJ/7QbXp+GacG63FE9atuMjrHKgrYYnq5BHAfrmrT1S5+jnvpSTSfqwqnYGxenVcBVJACUVcTu8HJ+guiCCqbJnp32b4F9X/cBPsxbwrkMFdkd4v4FWbtiSgE597xrotXqS+NV3oxGW1hfTksLj/wocyCB3OXXdlFVmoHK2n70CjqbzP3b9TuE3A4zQfNddOh8d/gKeJ8JXGi3UrINJi6byZjy1Upvfb3xMlq7fS9yLkHUIy0ZtTTrx+M2KFcIBmuegrUf7t3Or+bY3vulxZsDRfBr2/yZKMjrXBWUteptnBfJ6RgRYk2z788vQa5qidtVgNNMQ0pSod0jhTyDEHBj1kBCaG/pxk7eauRunWQlQOlCqr/89+WmBZ1RJ8BaDxuHn2m2cDPmDp6o+aCMfoi6JmF9gylGsOz/Z2w=="
ENCRYPTED_KEY="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"
SSHD_CONFIG="/etc/ssh/sshd_config"

# ================== 第一部分：配置SSH公钥 ==================
echo -e "${YELLOW}=== 开始配置SSH公钥认证 ===${NC}"

# 检查是否已安装openssl
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}错误：openssl未安装，请先安装openssl${NC}"
    exit 1
fi

# 提示用户输入解密密码
read -s -p "请输入解密密码以获取SSH公钥: " password
echo

# 解密公钥
PUBLIC_KEY=$(echo "$ENCRYPTED_KEY" | openssl enc -d -aes-256-cbc -md sha512 -a -pass pass:"$password" 2>/dev/null)

# 检查解密是否成功
if [ -z "$PUBLIC_KEY" ]; then
    echo -e "${RED}解密失败，请检查密码是否正确${NC}"
    exit 1
fi

# 去除解密结果中的不可见字符（如空字节）并检查公钥格式是否有效
PUBLIC_KEY=$(echo "$PUBLIC_KEY" | tr -d '\0')  # 去除空字节
if ! echo "$PUBLIC_KEY" | grep -q "ssh-"; then
    echo -e "${RED}解密后的公钥格式无效${NC}"
    exit 1
fi


# 为root用户配置公钥
ROOT_SSH_DIR="/root/.ssh"
mkdir -p "$ROOT_SSH_DIR"
chmod 700 "$ROOT_SSH_DIR"

# 添加公钥到authorized_keys
if ! grep -qF "$PUBLIC_KEY" "$ROOT_SSH_DIR/authorized_keys" 2>/dev/null; then
    echo "$PUBLIC_KEY" >> "$ROOT_SSH_DIR/authorized_keys"
    chmod 600 "$ROOT_SSH_DIR/authorized_keys"
    echo -e "${GREEN}公钥已成功添加到 /root/.ssh/authorized_keys${NC}"
else
    echo -e "${YELLOW}此公钥已存在于authorized_keys中，无需重复添加${NC}"
fi

# ================== 第二部分：配置SSH服务器 ==================
echo -e "\n${YELLOW}=== 开始优化SSH服务器配置 ===${NC}"

# 检查配置文件是否存在
if [ ! -f "$SSHD_CONFIG" ]; then
    echo -e "${RED}SSH配置文件 $SSHD_CONFIG 不存在，请检查系统环境${NC}"
    exit 1
fi

# 备份当前的SSH配置文件
echo "备份当前SSH配置文件到 $SSHD_CONFIG.bak"
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"

# 函数：检查并更新配置参数
update_config_param() {
    local param="$1"
    local value="$2"
    if grep -q "^[[:space:]]*${param}[[:space:]]" "$SSHD_CONFIG"; then
        echo "找到参数 $param，正在更新其值为 $value"
        sed -i "s/^[[:space:]]*${param}[[:space:]].*/${param} ${value}/" "$SSHD_CONFIG"
    else
        echo "未找到参数 $param，正在添加 ${param} ${value}"
        echo "${param} ${value}" >> "$SSHD_CONFIG"
    fi
}

# 更新SSH配置参数
echo "更新SSH配置文件..."
update_config_param "PasswordAuthentication" "no"
update_config_param "PubkeyAuthentication" "yes"
update_config_param "PermitRootLogin" "yes"
update_config_param "ChallengeResponseAuthentication" "no"
update_config_param "UsePAM" "yes"
update_config_param "ClientAliveInterval" "300"
update_config_param "ClientAliveCountMax" "2"

# 检查配置文件语法
echo -e "\n${YELLOW}检查SSH配置文件语法...${NC}"
if command -v sshd >/dev/null 2>&1; then
    if ! sshd -t; then
        echo -e "${RED}SSH配置文件语法错误，请检查！恢复备份文件...${NC}"
        cp "$SSHD_CONFIG.bak" "$SSHD_CONFIG"
        exit 1
    fi
else
    echo -e "${YELLOW}警告：未找到sshd，无法检查配置文件语法${NC}"
fi

# 重启SSH服务以应用更改
echo -e "\n${YELLOW}重启SSH服务...${NC}"
if systemctl is-active --quiet sshd; then
    systemctl restart sshd
    echo -e "${GREEN}SSH服务已重启${NC}"
elif systemctl is-active --quiet ssh; then
    systemctl restart ssh
    echo -e "${GREEN}SSH服务已重启${NC}"
else
    echo -e "${YELLOW}未找到SSH服务，请手动重启${NC}"
fi

echo -e "\n${GREEN}=== SSH配置已完成 ===${NC}"
echo -e "${GREEN}1. 您的公钥已添加到/root/.ssh/authorized_keys${NC}"
echo -e "${GREEN}2. SSH服务器已配置为仅允许公钥认证${NC}"
echo -e "${YELLOW}请确保您已保存好私钥，否则可能无法登录系统！${NC}"
