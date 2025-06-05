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
ENCRYPTED_KEY="U2FsdGVkX1/p9wZuaFseD8iwt3ywDk+rmTESLCFpaiOvVPxcYS0hIfpaizoHyRMu0DmCUXf7qa9k+EpkHy75k95oY7tBKOjymjt0igbJtzdGYq9qIwsk0kQjxbpwG/+/2fT77+GFEyGA5oSzK4T/cKCozsfuNsWZgWlKB1wKf6CQUmy/QonMaBPDXFXM0rYnpoq+/QksSqRsDqO9L8jB3UR77qB5pYsLxEJWSDdBHmrvdfJoRuo6N4QoxzwhrDrYJrvxRUeEO3DA5ThoIG3lN/FyE7+fHQzp0G7+nuXg7v0WXwtu8MdJdmwENcy1FpLF7/CPlKkEK5z+cTE9UJTXy/xm4IPmdSYtUpClhHjSNbfqjRZsPjC9AQ4MeZn15H7N30gpCwQA63adRA5vP0wc6gTl5Rv4UAXTh0jmKNuQCD/AaEyKKuyqWxZSW6j3oRi9Gu09Wz1lPM091elhAMl9yjKjBrEUFF+mhb9RxaigrxCxkX75Lutnzr31Vgu5eo54VTZt6ghoVwXbzeqWUgK9TV9C30VQewkjSVTp7MAn8SDREemwuaoh4zTXyA8vJIshxyiOb8Pn3HR/euV57j1goDLeiN3j0hsPNXs0XYlcyy/RQVQ9C0Mr8EZu66dJPHG9nyD4NGm1DSmNxH5wzulqWBZJmmwfKGP2RwsD3fNoQt+waLh1g64nNc2HgCNiKW7Ea8b8mIgCGgdiJuabIXj+YQ+NwxjirNIaAqYRgvdbnoRzFDFQaRFiHtT/x1qD/rOBy9vVddYVcJ7D/Skagaj/ap90qmptoe5IWCLaHZiKUMon20YO+RDlZaN5C8qfkJ4A4gM8lf7+mpjEcwbAiLQ4RuUkC7YAKW3B4WQAoXAL9JyyrqZepbkiBaOVxOC+9fzXwS034ps7wNdIPmqhQOnqhaW3T3o0MrBrhhNlHOSa+3n8tu2E3f8fDNDO9n9AR5JsRcg+Uk1NA5EAsA2w5Jr8nPokZuUFqJjHLAncOFAPTkIou3Raq+gRtI6OVWNuwdL4G8vW9RFg3rzpwIeIhJ76dE3e+RaDjG30/WYol7r77HX8HHIbqM3vkC8BWXIR9XgXHeK46uUoMaL0zYP8KfpwouLwByiFWgPHApDVppx+44fiIHROEVilIhXVH/vRhzs/zbNmotlGbKt5XdZ69jLPGXM+oKma3mftE6dVjqowOOv7eYyRdXaZ8GCbjFohT2CLg6hfCBrdI1cfbqMXEJm5mj+3ZRILHcTwAlgUtY3v5hwDBll1xD5j7QuoLHdMHVcWCDVN9a9tW2q8V3Q4z6ip1ye5DM2inS/UIphtn7YyZKYEupCF3zZ3xjxlt60Ch2jQ7oyfQFxjlgkTKVenNsTBuHiMauIXkLWq4nnb9nxWPRbKVN1XqcTgnrnb2yHq19PJmJhV3ofPczTbuoFFS0iJkBKs+JjyU8eP3MO8oO8i1ASYok3FdhRKLrRD587u92PsWgqC0ZyZCHWO9SDymQWr6jjPovNHGy7m0HJYVUGgcDe8WXBx00kSGQCrKm5ABmFr0l9NS/sLuaiL40RLuAcNeuVv/wCizziHEGzLoeF+OxBH3ibwvIN9B+KW3Av1HM6s5cmQGSAssmAU0ufbvgd5aEYO7cR3PxO1CuhqjKuL7lsq2tBQef8DA6/nicP1K8bTzxnMv6LoBMpfNccpKvORdEugjfCKYM19VrQEYM2axiAMj3N5g24N1fhcNUq/LgD3h6AobakIJy0o5ZoWhTdrNubwVUMkWuoez24ddVH2lnLVKFBckF0RgPg1ZqL/hSD5wqrAtew8UJINxyVqyl7u608KCfeHm1MNpCyf4O6S0zwVs6c8HnDJ6Y5cYf6oqLFSx1GYtPUK+VV7kMJaPOeN1kpfEL5k6ezGlRKJ+uQu6ufW0R8Fm0XBMtctTqTg+UYL98GT/0OPFcNkANX5AqBSH+qXux6WYL/vLjlkc1t9yQDKy5Q2OjJbYsUhobF97Wz40tXpiUpFm52gDWLck7YhXDkH4hdNx9MDH4aiI7Jt3fci99wQSevPGHRY+c6LTfI4Rbe4KfBWBrHM4DBLhPuaHxtE9scx5lRsw0dxMhU+MkygjHjINlaBwXbO3NRTRotSemlpQRGZn70C67ge/23GmiI+IVs9LoCwD4pGZdSQz7pQFB/7d8HtL5PfHMztk1unPkFM0zA169GPQjAsSC7Hzs1G7aYTgY0cQP0GGBZNxiGA7te50K4vsihHU1UeMOEb40s4qYKnABpGf8FF/aWXakKuX8VQ9QwbD5/vqCa+0t1UFIQ7txG4LWgrlaKbltJpmHK4alYXmkxjAqpV4USxH079is7yQScrbEwZedHjEYNljFswoe8QZCE8V/GURd+5l+3xyMNCWn3KgL/t48rOrBmEQ41SE73/bPbzgSQFHSPUFYUUOeKPZlmfxAo9BoqprX+8YkFrD4Wa23RGYEwFyqzxqsTKG0zW8q55xu9/HV0lN/Tj+Ij4TiurzwY6knBgbt2A1stn4mK+QhKQX7HA6e1aQeoh1wWLqLY3ZwIHhaFHTOopdINjzmiuTLOIXaWXGOaFsrnFFKFBgD2T7fPffo49N5vfRM4kb8PWLwKiSVCWWDi5ap23p8uocDqIDxWFwagWmgMxfmoXwZYR+zSfw33+6/V6e0rY4BtOfF4QAhdIzg4TMT2A1C0DnQviCtyZwSY1sSfV7lwKRzU+ZagxdlLOmaLK63aeSEzgueWqfDCLXQ7qaukegcpX4AqcxFjqYnAsgVmoIEA91imSBDPJaz6bKMS5nuH0ew27SBI16yaPDSRZbWEeQ/D+Js6qpc/qb+feCkEoKftMjQlsdIBkUvCJnntIDEq6qFWRl5YKT2AO4SX4XFQMxQhBfnIV/MPR14xruYy5hbYsSClCdsCsGA=="

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
