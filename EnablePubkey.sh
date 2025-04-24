#!/bin/bash

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
    echo "此脚本需要以root权限运行，请使用sudo或切换到root用户"
    exit 1
fi

# 定义SSH配置文件路径
SSHD_CONFIG="/etc/ssh/sshd_config"

# 检查配置文件是否存在
if [ ! -f "$SSHD_CONFIG" ]; then
    echo "SSH配置文件 $SSHD_CONFIG 不存在，请检查系统环境"
    exit 1
fi

# 备份当前的SSH配置文件
echo "备份当前SSH配置文件到/etc/ssh/sshd_config.bak"
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
update_config_param "PasswordAuthentication" "yes"
update_config_param "RSAAuthentication" "yes"
update_config_param "PubkeyAuthentication" "yes"
update_config_param "PermitRootLogin" "yes"
update_config_param "ChallengeResponseAuthentication" "yes"
update_config_param "UsePAM" "yes"

# 检查配置文件语法
echo "检查SSH配置文件语法..."
if command -v sshd >/dev/null 2>&1; then
    sshd -t
    if [ $? -ne 0 ]; then
        echo "SSH配置文件语法错误，请检查！恢复备份文件..."
        cp "$SSHD_CONFIG.bak" "$SSHD_CONFIG"
        exit 1
    fi
else
    echo "警告：未找到sshd，无法检查配置文件语法"
fi

# 重启SSH服务以应用更改
echo "重启SSH服务..."
if systemctl is-active --quiet sshd; then
    systemctl restart sshd
    echo "SSH服务已重启"
elif systemctl is-active --quiet ssh; then
    systemctl restart ssh
    echo "SSH服务已重启"
else
    echo "未找到SSH服务，请手动重启"
fi

echo "SSH相关配置已更新！"
echo "请确保已设置好公钥认证或密码认证以便登录。"
