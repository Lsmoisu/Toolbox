#!/bin/bash

# 颜色定义，用于美化输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 函数：检查 GOST 进程或文件是否存在
check_gost() {
    if pgrep gost > /dev/null; then
        echo -e "${YELLOW}警告：GOST 进程正在运行。${NC}"
        return 1  # 存在进程
    fi
    if [ -f /usr/local/bin/gost ]; then
        echo -e "${YELLOW}警告：GOST 文件已存在。${NC}"
        return 1  # 存在文件
    fi
    return 0  # 不存在
}

# 函数：获取 GOST 最新版本
get_latest_version() {
    latest_info=$(curl -s https://api.github.com/repos/ginuerzh/gost/releases/latest)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：无法获取最新版本信息，从参考版本回退（v2.12.0）。${NC}"
        echo "v2.12.0"  # 回退到参考版本
    else
        echo "$latest_info" | grep -oP '"tag_name":\s*"\K(.*)(?=")'  # 解析 tag_name
    fi
}

# 生成随机密码
generate_random_password() {
    generated_password=$(</dev/urandom tr -dc 'A-Za-z0-9' | head -c 10)
    echo "$generated_password"
}

# 主菜单
echo -e "${GREEN}请选择操作：${NC}"
echo -e "${YELLOW}1. 安装 GOST 并启用 SOCKS5 (以 root 用户运行)${NC}"
echo -e "${YELLOW}2. 卸载 GOST${NC}"
read -p "输入选项 (1 或 2): " choice

case $choice in
    1)
        # 安装逻辑
        if ! check_gost; then
            echo -e "${RED}检测到 GOST 相关进程或文件，请先卸载或停止。${NC}"
            exit 1
        fi

        read -p "输入用户名 [默认: bigbigboom]: " username
        if [ -z "$username" ]; then
            username="bigbigboom"  # 如果不输入，使用默认用户名
        fi

        default_password=$(generate_random_password)  # 生成随机密码
        read -s -p "输入密码 [默认: $default_password]: " password  # 使用 -s 隐藏输入
        if [ -z "$password" ]; then
            password="$default_password"  # 如果不输入，使用随机密码
        fi
        echo  # 换行

        read -p "输入端口 [默认: 12333]: " port
        if [ -z "$port" ]; then
            port="12333"  # 如果不输入，使用默认端口
        fi

        # 验证端口是否为数字（简单检查）
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo -e "${RED}错误：端口必须是 1-65535 之间的数字。${NC}"
            exit 1
        fi

        latest_version=$(get_latest_version)
        cleaned_version=${latest_version#v}
        asset_url="https://github.com/ginuerzh/gost/releases/download/${latest_version}/gost_${cleaned_version}_linux_amd64.tar.gz"

        echo -e "${GREEN}正在下载 GOST 版本 (${latest_version}) ...${NC}"
        if ! command -v wget > /dev/null; then
            curl -s -L -o gost.tar.gz "$asset_url"  # 使用 -s 隐藏输出
        else
            wget -q -O gost.tar.gz "$asset_url"  # 使用 -q 隐藏输出
        fi

        if [ $? -ne 0 ]; then
            echo -e "${RED}错误：下载失败。${NC}"
            exit 1
        fi

        tar -xzf gost.tar.gz -C /tmp/
        gost_file=$(find /tmp/ -name "gost" -type f | head -n 1)
        if [ -z "$gost_file" ]; then
            echo -e "${RED}错误：未找到 gost 文件。${NC}"
            rm -f gost.tar.gz
            exit 1
        fi

        mv "$gost_file" /usr/local/bin/gost
        chmod +x /usr/local/bin/gost
        rm -f gost.tar.gz
        rm -rf /tmp/*gost*

        # 创建 systemd 服务文件，并设置 User=root (无注释)
        cat > /etc/systemd/system/gost.service << EOF
[Unit]
Description=GOST Proxy Service
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/gost -L "socks5://${username}:${password}@:${port}"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable gost
        systemctl start gost

        # 自动检测服务状态
        echo -e "${GREEN}正在检测服务状态...${NC}"
        service_status=$(systemctl is-active gost)  # 检查服务是否 active
        if [ "$service_status" = "active" ]; then
            echo -e "${GREEN}GOST 安装成功 (端口: ${port})。服务已启动。${NC}"
            echo "管理命令："
            echo "  systemctl status gost  - 查看状态"
            echo "  systemctl stop gost    - 停止服务"
            echo "  systemctl restart gost - 重启服务"

            # 获取公网 IP 并输出 SOCKS5 链接
            public_ip=$(curl -s icanhazip.com)
            if [ $? -eq 0 ] && [ -n "$public_ip" ]; then
                socks5_link="socks5://${username}:${password}@${public_ip}:${port}"
                echo -e "${GREEN}SOCKS5 链接: ${socks5_link}${NC}"
            else
                echo -e "${YELLOW}警告：无法获取公网 IP，SOCKS5 链接无法生成。${NC}"
            fi
        else
            echo -e "${RED}错误：服务启动失败或未运行正常。请检查日志 (journalctl -u gost)。${NC}"
            exit 1  # 退出脚本
        fi
        ;;

    2)
        # 卸载逻辑
        sudo systemctl stop gost
        sudo systemctl disable gost
        sudo rm /etc/systemd/system/gost.service
        sudo rm /usr/local/bin/gost
        sudo systemctl daemon-reload
        echo -e "${GREEN}GOST 已卸载。${NC}"
        ;;

    *)
        echo -e "${RED}无效选项，请输入 1 或 2。${NC}"
        exit 1
        ;;
esac
