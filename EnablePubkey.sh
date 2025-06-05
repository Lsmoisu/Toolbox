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


SSHD_CONFIG="/etc/ssh/sshd_config"

# ================== 第一部分：配置SSH公钥 ==================
echo -e "${YELLOW}=== 开始配置SSH公钥认证 ===${NC}"

# 解密公钥
PUBLIC_KEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCk1UYH6SmDtRKwnEt2iJiTC/Si3HlMYwzDG9FlMNQNLQ9g8AOK1ZLDQgUjM+eugMVugLPz8aFT8waSV9QDudU+epRAsczIfd7pHKaApWSWo55oTHwzjt8kb7JY3XvcnqVb55wbwQWQiMpIyj4q8fBmJCCeMWLtIS4c68KhSg4ihz6YOQpuDtDclWXEByr1C1i0MQ7ymwhjJazrN3LThTATTqoP5Ho3b2FEuZcBaSRIQrDBWJYVzl15Fbq0RfQaleudl18j7BUN/1/SHUcyUbTb5H4XkHiLQhOutf+mMqX0wZPSOy6q+GRP8Fi3bKHFXR/6+/HIyz0ocx9FQY5ir46v chunyu.he20@tendcloud.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDnZIlWIWpvgbvmmZ5+chyYWWTZXmXMTIbZV5REoLNhOeFRmoNq2gjVy/emCxHI0nweMP1M4jKJiqNaTK9+Vo7wv+uRiLQLkI6DNcZdYQx7t+L8z4GaWUfoR2w15gJtjxjJpLI+pev3LYRsTdyu5ZnQm2d0vi2O8Qahv5Q8RUHiARJ+72vPW8xp52TAGW14uIFym6Go5LAyppmvhOqHQhh+D8bJi/UKEm4LTyKcC2jm9MFUWBV1oQ4ZR1sl4h44/F4l8Dy4TFKdpXne/Ps42Nxkt4ECthoK3WcVNZvyna8m8NBOrj9D5rPMf7XAFLPWqP+N1rALf/bmDUu99iFOaZW1QkPafU5ozKsk8leu1npY5lWRfeEh2SL5mfLb/tXXB5QN/xPu2i9g79o2Qa+HvLmcVAJzbzNGgXoQmGQdOqWfEUIfYlzSdvnMGKzlyRe8amWUGBg4jX8mkvE8KxkVBV8iUCvw+dCvpHMBwQgGabvtcbGGbgQPRvkzehzj5p4fBBE= root@oracle-arm
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDQMB9evA8B2OV5IJPJVH7QdyzMP9qSRTq9ja/LCVqkdOxljRPl0Xhqh/gWIVpNMLRe4TALxIVs/gnVdNF5h98FfGUlNF/zLb4yvQE6ss7c0KkXrS6rTTRmVGBQKpe9cpmhhDViLPggeQ29Lt+fc1cXUYrle9NSVnXEU8TPnPVy3UKk1fuL0PYhqClXL5+MgjhWYFTjUVDaZdKGPWVhE3NRrqQtNrV2owrU+sVBdTkzRQ36vK9mhlmmv0SyA1Hxio1Un61h2nheKtVjpNDWQpRpbFglp3gfIUotplgJUw8JYPNMhwPC9/w1+wfiTYaJhASUYxbsrb9LBbs8ZxZkrgbgYA7FJkwPVH0ELcDwvbU/f4WIFbAVmj0O7E/lF8eGhNVLOg0UC1n6vmcBcxyC796bRLsaQ4EwyX9JKCIz30UTMDBXUrOS55TOHdLnUCMUNBLFiXMQLqn9DibPt8P/8L2rZFTC2KtrlgruI+qCD3jpvQHAsLgOXmA8fzXAR2Ta2e0= sprin@chunyu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVw/Lamb8wHXeLgCKGbumrocMvq+a6goVFBAuhYk/TVUoislrO1SrrH5YMFc7aQMZNP/mbubirIck8h0wT8hiU070OHO7HuaAyIGgFh4icIX/m7znhvWteG/evxJUN95ZWm4bk+UmGUbbAO4BkSEGub/ENJ3RGR9eJuDabgMha5fyzl9J9sm6jDeXVyGtLOy9NkYYHo/J0kUAwK1YOQ88rAXIhsJ04qsH7256VAdo6enO39Y0RG4NhK3hlRYP46f8NWyCaJFbcz4tpbHNdG9Xbqg7j/RSn7tO5bpB283m/wsZR7kM28x9dzyojJJYycEn9CTUzBjxcBBuKNa57Y+eoBo7q2KXx13ziMvO5k7Bl8GXknl0uguf49hjbPS95CThns+sqz7G3Px8a79BJ1rHEewlmMMJUa/kRY+NAcum0nVkWzZIpR6I2KWMP+8OaJLj97vIHgGydRP8y4I6IiiZBlOlshNJ3iI/XxsSWjWjdWxSHUZtHj4L1IaxclrX+QtU= root@gc-hk.asia-east2-c.c.annular-bucksaw-448504-h3.internal
'

# 检查
if [ -z "$PUBLIC_KEY" ]; then
    echo -e "${RED}检查失败${NC}"
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
