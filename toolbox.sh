#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 工具箱菜单
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}       欢迎使用运维工具箱v0.2.1${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "${YELLOW}请选择您需要的功能：${NC}"
echo -e "${BLUE}1. 启用免密登录${NC}"
echo -e "${BLUE}2. 安装Grafana+Prometheus+Node Exporter监控工具${NC}"
echo -e "${BLUE}3. 安装Hysteria2代理${NC}"
echo -e "${BLUE}4. 安装其他代理${NC}"
echo -e "${BLUE}5. VPS测试（融合怪测评脚本）${NC}"
echo -e "${BLUE}6. 修改系统环境为中文+东八区${NC}"
echo -e "${BLUE}7. 安装Docker和Docker Compose${NC}"
echo -e "${BLUE}8. 退出${NC}"
echo -e "${GREEN}=========================================${NC}"

# 读取用户输入
read -p "请输入选项 (1-8): " choice

case $choice in
    1)
        echo -e "${YELLOW}正在启用免密登录...${NC}"
        bash <(curl -fsSL https://github.com/Lsmoisu/Toolbox/raw/refs/heads/main/EnablePubkey.sh)
        ;;
    2)
        echo -e "${YELLOW}正在安装Grafana+Prometheus+Node Exporter监控工具...${NC}"
        bash <(curl -fsSL https://github.com/Lsmoisu/Toolbox/raw/refs/heads/main/Monitoring_Tools.sh)
        ;;
    3)
        echo -e "${YELLOW}正在安装Hysteria2代理...${NC}"
        bash <(curl -fsSL https://github.com/Lsmoisu/Toolbox/raw/refs/heads/main/hysteria2.sh)
        ;;
    4)
        echo -e "${YELLOW}正在安装其他代理...${NC}"
        wget -P /root -N --no-check-certificate https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh && chmod 700 /root/install.sh && /root/install.sh
        ;;
    5)
        echo -e "${YELLOW}正在测试机器IP信息...${NC}"
        export noninteractive=true && curl -L https://raw.githubusercontent.com/oneclickvirt/ecs/master/goecs.sh -o goecs.sh && chmod +x goecs.sh && bash goecs.sh env && bash goecs.sh install && goecs
        ;;
    6)
        echo -e "${YELLOW}正在修改系统环境为中文...${NC}"
        bash <(curl -fsSL https://github.com/Lsmoisu/Toolbox/raw/refs/heads/main/env_zh.sh)
        ;;
    7)
        echo -e "${YELLOW}正在安装Docker...${NC}"
        bash <(curl -fsSL https://get.docker.com)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Docker安装成功！${NC}"
        else
            echo -e "${RED}Docker安装失败，请检查网络或手动安装。${NC}"
        fi
        
        echo -e "${YELLOW}正在检测Docker Compose最新版本...${NC}"
        # 通过GitHub API获取最新版本号
        LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        if [ -n "$LATEST_VERSION" ]; then
            echo -e "${GREEN}Docker Compose最新版本为: $LATEST_VERSION${NC}"
            echo -e "${YELLOW}正在安装Docker Compose $LATEST_VERSION...${NC}"
            sudo curl -L "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            if [ $? -eq 0 ]; then
                sudo chmod +x /usr/local/bin/docker-compose
                echo -e "${GREEN}Docker Compose安装成功！${NC}"
                docker-compose --version
            else
                echo -e "${RED}Docker Compose安装失败，请检查网络或手动安装。${NC}"
            fi
        else
            echo -e "${RED}无法获取Docker Compose最新版本号，请检查网络或手动安装。${NC}"
        fi
        ;;
    8)
        echo -e "${GREEN}退出工具箱，感谢使用！${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}无效选项，请重新运行脚本并选择1-8之间的选项。${NC}"
        ;;
esac
