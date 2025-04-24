#!/bin/bash

# 功能：自动安装或卸载 Prometheus、Node Exporter、Grafana、Blackbox Exporter 和 Alertmanager，支持用户选择安装或卸载组件及指定版本或默认安装最新版本，适配系统架构
# 作者：Grok3
# 使用方法：chmod +x install_prometheus.sh && ./install_prometheus.sh

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root 用户或有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：请以 root 用户或使用 sudo 权限运行此脚本！${NC}"
    exit 1
fi

# 定义常量
INSTALL_DIR="/opt/prometheus"
DATA_DIR="/opt/prometheus/data"
SERVICE_FILE="/etc/systemd/system/prometheus.service"
NODE_EXPORTER_INSTALL_DIR="/opt/node_exporter"
NODE_EXPORTER_SERVICE_FILE="/etc/systemd/system/node-exporter.service"
GRAFANA_CONFIG_DIR="/etc/grafana"
GRAFANA_SERVICE_FILE="/etc/systemd/system/grafana-server.service"
BLACKBOX_INSTALL_DIR="/opt/blackbox_exporter"
BLACKBOX_DATA_DIR="/opt/blackbox_exporter/data"
BLACKBOX_SERVICE_FILE="/etc/systemd/system/blackbox-exporter.service"
ALERTMANAGER_INSTALL_DIR="/opt/alertmanager"
ALERTMANAGER_DATA_DIR="/opt/alertmanager/data"
ALERTMANAGER_SERVICE_FILE="/etc/systemd/system/alertmanager.service"

# 卸载函数
uninstall_components() {
    echo -e "${YELLOW}请选择要卸载的组件：${NC}"
    echo -e "${YELLOW}1. Grafana${NC}"
    echo -e "${YELLOW}2. Prometheus${NC}"
    echo -e "${YELLOW}3. Node Exporter${NC}"
    echo -e "${YELLOW}4. Blackbox Exporter${NC}"
    echo -e "${YELLOW}5. Alertmanager${NC}"
    echo -e "${YELLOW}请输入要卸载的组件编号（用空格分隔多个选项，例如：1 3）：${NC}"
    read -r UNINSTALL_SELECTION

    # 初始化卸载标志
    UNINSTALL_GRAFANA="n"
    UNINSTALL_PROMETHEUS="n"
    UNINSTALL_NODE_EXPORTER="n"
    UNINSTALL_BLACKBOX="n"
    UNINSTALL_ALERTMANAGER="n"

    # 解析用户输入的选择
    for SELECTED in $UNINSTALL_SELECTION; do
        case $SELECTED in
            1)
                UNINSTALL_GRAFANA="y"
                echo -e "${GREEN}将卸载 Grafana。${NC}"
                ;;
            2)
                UNINSTALL_PROMETHEUS="y"
                echo -e "${GREEN}将卸载 Prometheus。${NC}"
                ;;
            3)
                UNINSTALL_NODE_EXPORTER="y"
                echo -e "${GREEN}将卸载 Node Exporter。${NC}"
                ;;
            4)
                UNINSTALL_BLACKBOX="y"
                echo -e "${GREEN}将卸载 Blackbox Exporter。${NC}"
                ;;
            5)
                UNINSTALL_ALERTMANAGER="y"
                echo -e "${GREEN}将卸载 Alertmanager。${NC}"
                ;;
            *)
                echo -e "${RED}警告：无效选项 $SELECTED，已忽略。${NC}"
                ;;
        esac
    done

    # 如果没有选择卸载任何组件，则退出
    if [ "$UNINSTALL_PROMETHEUS" != "y" ] && [ "$UNINSTALL_NODE_EXPORTER" != "y" ] && [ "$UNINSTALL_GRAFANA" != "y" ] && [ "$UNINSTALL_BLACKBOX" != "y" ] && [ "$UNINSTALL_ALERTMANAGER" != "y" ]; then
        echo -e "${RED}错误：未选择卸载任何组件，脚本退出！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在卸载已选择的组件...${NC}"

    # 卸载 Prometheus
    if [ "$UNINSTALL_PROMETHEUS" == "y" ]; then
        # 检查服务是否存在并执行操作
        if systemctl list-units --full -all | grep -q "prometheus.service"; then
            if systemctl is-active --quiet prometheus; then
                echo -e "${YELLOW}正在停止 Prometheus 服务...${NC}"
                systemctl stop prometheus
            fi
            if systemctl is-enabled --quiet prometheus; then
                echo -e "${YELLOW}正在禁用 Prometheus 服务...${NC}"
                systemctl disable prometheus
            fi
        fi
        if [ -f "$SERVICE_FILE" ]; then
            echo -e "${YELLOW}正在删除 Prometheus systemd 服务文件...${NC}"
            rm -f "$SERVICE_FILE"
            systemctl daemon-reload
            systemctl reset-failed
        fi

        # 删除安装目录和数据目录
        if [ -d "$INSTALL_DIR" ]; then
            echo -e "${YELLOW}正在删除 Prometheus 安装目录 ($INSTALL_DIR)...${NC}"
            rm -rf "$INSTALL_DIR"
        fi
        if [ -d "$DATA_DIR" ]; then
            echo -e "${YELLOW}正在删除 Prometheus 数据目录 ($DATA_DIR)...${NC}"
            rm -rf "$DATA_DIR"
        fi

        # 删除用户和组
        if id prometheus &> /dev/null; then
            echo -e "${YELLOW}正在删除 Prometheus 用户和组...${NC}"
            userdel prometheus || true
        fi
        if getent group prometheus &> /dev/null; then
            groupdel prometheus || true
        fi
        echo -e "${GREEN}Prometheus 已成功卸载！${NC}"
    fi

    # 卸载 Node Exporter
    if [ "$UNINSTALL_NODE_EXPORTER" == "y" ]; then
        # 检查服务是否存在并执行操作
        if systemctl list-units --full -all | grep -q "node-exporter.service"; then
            if systemctl is-active --quiet node-exporter; then
                echo -e "${YELLOW}正在停止 Node Exporter 服务...${NC}"
                systemctl stop node-exporter
            fi
            if systemctl is-enabled --quiet node-exporter; then
                echo -e "${YELLOW}正在禁用 Node Exporter 服务...${NC}"
                systemctl disable node-exporter
            fi
        fi
        if [ -f "$NODE_EXPORTER_SERVICE_FILE" ]; then
            echo -e "${YELLOW}正在删除 Node Exporter systemd 服务文件...${NC}"
            rm -f "$NODE_EXPORTER_SERVICE_FILE"
            systemctl daemon-reload
            systemctl reset-failed
        fi

        # 删除安装目录
        if [ -d "$NODE_EXPORTER_INSTALL_DIR" ]; then
            echo -e "${YELLOW}正在删除 Node Exporter 安装目录 ($NODE_EXPORTER_INSTALL_DIR)...${NC}"
            rm -rf "$NODE_EXPORTER_INSTALL_DIR"
        fi

        # 删除用户和组
        if id node_exporter &> /dev/null; then
            echo -e "${YELLOW}正在删除 Node Exporter 用户和组...${NC}"
            userdel node_exporter || true
        fi
        if getent group node_exporter &> /dev/null; then
            groupdel node_exporter || true
        fi
        echo -e "${GREEN}Node Exporter 已成功卸载！${NC}"
    fi

    # 卸载 Grafana
    if [ "$UNINSTALL_GRAFANA" == "y" ]; then
        # 检查服务是否存在并执行操作
        if systemctl list-units --full -all | grep -q "grafana-server.service"; then
            if systemctl is-active --quiet grafana-server; then
                echo -e "${YELLOW}正在停止 Grafana 服务...${NC}"
                systemctl stop grafana-server
            fi
            if systemctl is-enabled --quiet grafana-server; then
                echo -e "${YELLOW}正在禁用 Grafana 服务...${NC}"
                systemctl disable grafana-server
            fi
        fi
        if [ -f "$GRAFANA_SERVICE_FILE" ] || command -v grafana-server &> /dev/null; then
            echo -e "${YELLOW}正在删除 Grafana systemd 服务文件...${NC}"
            rm -f "$GRAFANA_SERVICE_FILE"
            systemctl daemon-reload
            systemctl reset-failed
        fi

        # 删除配置目录
        if [ -d "$GRAFANA_CONFIG_DIR" ]; then
            echo -e "${YELLOW}正在删除 Grafana 配置目录 ($GRAFANA_CONFIG_DIR)...${NC}"
            rm -rf "$GRAFANA_CONFIG_DIR"
        fi

        # 卸载 Grafana 包（如果通过包管理器安装）
        if command -v apt &> /dev/null; then
            apt remove -y grafana || true
        elif command -v yum &> /dev/null; then
            yum remove -y grafana || true
        fi
        echo -e "${GREEN}Grafana 已成功卸载！${NC}"
    fi

    # 卸载 Blackbox Exporter
    if [ "$UNINSTALL_BLACKBOX" == "y" ]; then
        # 检查服务是否存在并执行操作
        if systemctl list-units --full -all | grep -q "blackbox-exporter.service"; then
            if systemctl is-active --quiet blackbox-exporter; then
                echo -e "${YELLOW}正在停止 Blackbox Exporter 服务...${NC}"
                systemctl stop blackbox-exporter
            fi
            if systemctl is-enabled --quiet blackbox-exporter; then
                echo -e "${YELLOW}正在禁用 Blackbox Exporter 服务...${NC}"
                systemctl disable blackbox-exporter
            fi
        fi
        if [ -f "$BLACKBOX_SERVICE_FILE" ]; then
            echo -e "${YELLOW}正在删除 Blackbox Exporter systemd 服务文件...${NC}"
            rm -f "$BLACKBOX_SERVICE_FILE"
            systemctl daemon-reload
            systemctl reset-failed
        fi

        # 检查并删除配置文件
        if [ -f "$BLACKBOX_INSTALL_DIR/config.yml" ]; then
            echo -e "${YELLOW}正在删除 Blackbox Exporter 配置文件...${NC}"
            rm -f "$BLACKBOX_INSTALL_DIR/config.yml"
        fi

        # 删除安装目录和数据目录
        if [ -d "$BLACKBOX_INSTALL_DIR" ]; then
            echo -e "${YELLOW}正在删除 Blackbox Exporter 安装目录 ($BLACKBOX_INSTALL_DIR)...${NC}"
            rm -rf "$BLACKBOX_INSTALL_DIR"
        fi
        if [ -d "$BLACKBOX_DATA_DIR" ]; then
            echo -e "${YELLOW}正在删除 Blackbox Exporter 数据目录 ($BLACKBOX_DATA_DIR)...${NC}"
            rm -rf "$BLACKBOX_DATA_DIR"
        fi

        # 删除用户和组
        if id blackbox &> /dev/null; then
            echo -e "${YELLOW}正在删除 Blackbox Exporter 用户和组...${NC}"
            userdel blackbox || true
        fi
        if getent group blackbox &> /dev/null; then
            groupdel blackbox || true
        fi
        echo -e "${GREEN}Blackbox Exporter 已成功卸载！${NC}"
    fi

    # 卸载 Alertmanager
    if [ "$UNINSTALL_ALERTMANAGER" == "y" ]; then
        # 检查服务是否存在并执行操作
        if systemctl list-units --full -all | grep -q "alertmanager.service"; then
            if systemctl is-active --quiet alertmanager; then
                echo -e "${YELLOW}正在停止 Alertmanager 服务...${NC}"
                systemctl stop alertmanager
            fi
            if systemctl is-enabled --quiet alertmanager; then
                echo -e "${YELLOW}正在禁用 Alertmanager 服务...${NC}"
                systemctl disable alertmanager
            fi
        fi
        if [ -f "$ALERTMANAGER_SERVICE_FILE" ]; then
            echo -e "${YELLOW}正在删除 Alertmanager systemd 服务文件...${NC}"
            rm -f "$ALERTMANAGER_SERVICE_FILE"
            systemctl daemon-reload
            systemctl reset-failed
        fi

        # 删除安装目录和数据目录
        if [ -d "$ALERTMANAGER_INSTALL_DIR" ]; then
            echo -e "${YELLOW}正在删除 Alertmanager 安装目录 ($ALERTMANAGER_INSTALL_DIR)...${NC}"
            rm -rf "$ALERTMANAGER_INSTALL_DIR"
        fi
        if [ -d "$ALERTMANAGER_DATA_DIR" ]; then
            echo -e "${YELLOW}正在删除 Alertmanager 数据目录 ($ALERTMANAGER_DATA_DIR)...${NC}"
            rm -rf "$ALERTMANAGER_DATA_DIR"
        fi

        # 删除用户和组
        if id alertmanager &> /dev/null; then
            echo -e "${YELLOW}正在删除 Alertmanager 用户和组...${NC}"
            userdel alertmanager || true
        fi
        if getent group alertmanager &> /dev/null; then
            groupdel alertmanager || true
        fi
        echo -e "${GREEN}Alertmanager 已成功卸载！${NC}"
    fi

    echo -e "${GREEN}所选组件卸载完成！${NC}"
    exit 0
}

# 主菜单：选择安装或卸载
echo -e "${YELLOW}请选择操作：${NC}"
echo -e "${YELLOW}1. 安装组件${NC}"
echo -e "${YELLOW}2. 卸载组件${NC}"
echo -e "${YELLOW}请输入操作编号（1 或 2）：${NC}"
read -r OPERATION

case $OPERATION in
    1)
        echo -e "${GREEN}选择了安装操作。${NC}"
        ;;
    2)
        echo -e "${GREEN}选择了卸载操作。${NC}"
        uninstall_components
        ;;
    *)
        echo -e "${RED}错误：无效选项 $OPERATION，脚本退出！${NC}"
        exit 1
        ;;
esac

# 获取系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        PROM_ARCH="linux-amd64"
        ;;
    aarch64|arm64)
        PROM_ARCH="linux-arm64"
        ;;
    *)
        echo -e "${RED}错误：不支持的系统架构 ($ARCH)！${NC}"
        exit 1
        ;;
esac
echo -e "${GREEN}检测到系统架构：$ARCH，使用 Prometheus 架构：$PROM_ARCH${NC}"

# 检查 wget 是否安装
if ! command -v wget &> /dev/null; then
    echo -e "${YELLOW}wget 未安装，正在安装...${NC}"
    if command -v apt &> /dev/null; then
        apt update && apt install -y wget
    elif command -v yum &> /dev/null; then
        yum install -y wget
    else
        echo -e "${RED}错误：无法确定包管理器，无法安装 wget！${NC}"
        exit 1
    fi
fi

# 交互式选择安装的组件
echo -e "${YELLOW}请选择要安装的组件：${NC}"
echo -e "${YELLOW}1. Grafana${NC}"
echo -e "${YELLOW}2. Prometheus${NC}"
echo -e "${YELLOW}3. Node Exporter${NC}"
echo -e "${YELLOW}4. Blackbox Exporter${NC}"
echo -e "${YELLOW}5. Alertmanager${NC}"
echo -e "${YELLOW}请输入要安装的组件编号（用空格分隔多个选项，例如：1 3）：${NC}"
read -r SELECTION

# 初始化安装标志
INSTALL_GRAFANA="n"
INSTALL_PROMETHEUS="n"
INSTALL_NODE_EXPORTER="n"
INSTALL_BLACKBOX="n"
INSTALL_ALERTMANAGER="n"

# 解析用户输入的选择
for SELECTED in $SELECTION; do
    case $SELECTED in
        1)
            INSTALL_GRAFANA="y"
            echo -e "${GREEN}将安装 Grafana。${NC}"
            ;;
        2)
            INSTALL_PROMETHEUS="y"
            echo -e "${GREEN}将安装 Prometheus。${NC}"
            ;;
        3)
            INSTALL_NODE_EXPORTER="y"
            echo -e "${GREEN}将安装 Node Exporter。${NC}"
            ;;
        4)
            INSTALL_BLACKBOX="y"
            echo -e "${GREEN}将安装 Blackbox Exporter。${NC}"
            ;;
        5)
            INSTALL_ALERTMANAGER="y"
            echo -e "${GREEN}将安装 Alertmanager。${NC}"
            ;;
        *)
            echo -e "${RED}警告：无效选项 $SELECTED，已忽略。${NC}"
            ;;
    esac
done

# 如果没有选择安装任何组件，则退出
if [ "$INSTALL_PROMETHEUS" != "y" ] && [ "$INSTALL_NODE_EXPORTER" != "y" ] && [ "$INSTALL_GRAFANA" != "y" ] && [ "$INSTALL_BLACKBOX" != "y" ] && [ "$INSTALL_ALERTMANAGER" != "y" ]; then
    echo -e "${RED}错误：未选择安装任何组件，脚本退出！${NC}"
    exit 1
fi

# 安装 Prometheus 的逻辑
if [ "$INSTALL_PROMETHEUS" == "y" ]; then
    echo -e "${YELLOW}正在获取 Prometheus 最新版本...${NC}"
    VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "$VERSION" ]; then
        echo -e "${RED}错误：无法获取 Prometheus 最新版本，请检查网络！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Prometheus 最新版本为：$VERSION${NC}"
    DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${VERSION}/prometheus-${VERSION}.${PROM_ARCH}.tar.gz"

    # 检查 Prometheus 下载链接是否有效
    echo -e "${YELLOW}正在验证 Prometheus 下载链接...${NC}"
    HTTP_STATUS=$(curl -s -I "$DOWNLOAD_URL" | grep -i "HTTP/" | awk '{print $2}' | head -1)
    if [[ "$HTTP_STATUS" != "200" && "$HTTP_STATUS" != "302" ]]; then
        echo -e "${RED}错误：无效的 Prometheus 下载链接 ($DOWNLOAD_URL)！${NC}"
        echo -e "${YELLOW}HTTP 状态码：$HTTP_STATUS${NC}"
        exit 1
    fi
    echo -e "${GREEN}Prometheus 下载链接有效，HTTP 状态码：$HTTP_STATUS${NC}"

    echo -e "${YELLOW}正在创建 Prometheus 安装目录和数据目录...${NC}"
    mkdir -p "$INSTALL_DIR" "$DATA_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Prometheus 目录失败！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在下载 Prometheus v${VERSION}...${NC}"
    wget -O /tmp/prometheus.tar.gz "$DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：下载 Prometheus 失败，请检查网络！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在解压并安装 Prometheus...${NC}"
    tar -xzf /tmp/prometheus.tar.gz -C /tmp
    mv /tmp/prometheus-${VERSION}.${PROM_ARCH}/* "$INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：解压或移动 Prometheus 文件失败！${NC}"
        exit 1
    fi

    # 清理临时文件
    rm -rf /tmp/prometheus.tar.gz /tmp/prometheus-${VERSION}.${PROM_ARCH}

    # 创建 Prometheus 用户和组
    echo -e "${YELLOW}正在创建 Prometheus 用户和组...${NC}"
    useradd -M -s /bin/false prometheus || true
    chown -R prometheus:prometheus "$INSTALL_DIR" "$DATA_DIR"

    # 创建 Prometheus systemd 服务文件
    echo -e "${YELLOW}正在创建 Prometheus systemd 服务文件...${NC}"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=$INSTALL_DIR/prometheus --config.file $INSTALL_DIR/prometheus.yml --storage.tsdb.path $DATA_DIR

[Install]
WantedBy=multi-user.target
EOF
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Prometheus 服务文件失败！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Prometheus 安装完成！${NC}"
fi

# 安装 Node Exporter 的逻辑
if [ "$INSTALL_NODE_EXPORTER" == "y" ]; then
    echo -e "${YELLOW}正在获取 Node Exporter 最新版本...${NC}"
    NODE_EXPORTER_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "$NODE_EXPORTER_VERSION" ]; then
        echo -e "${RED}错误：无法获取 Node Exporter 最新版本，请检查网络！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Node Exporter 最新版本为：$NODE_EXPORTER_VERSION${NC}"
    NODE_EXPORTER_DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${PROM_ARCH}.tar.gz"

    # 检查 Node Exporter 下载链接是否有效
    echo -e "${YELLOW}正在验证 Node Exporter 下载链接...${NC}"
    HTTP_STATUS=$(curl -s -I "$NODE_EXPORTER_DOWNLOAD_URL" | grep -i "HTTP/" | awk '{print $2}' | head -1)
    if [[ "$HTTP_STATUS" != "200" && "$HTTP_STATUS" != "302" ]]; then
        echo -e "${RED}错误：无效的 Node Exporter 下载链接 ($NODE_EXPORTER_DOWNLOAD_URL)！${NC}"
        echo -e "${YELLOW}HTTP 状态码：$HTTP_STATUS${NC}"
        exit 1
    fi
    echo -e "${GREEN}Node Exporter 下载链接有效，HTTP 状态码：$HTTP_STATUS${NC}"

    echo -e "${YELLOW}正在创建 Node Exporter 安装目录...${NC}"
    mkdir -p "$NODE_EXPORTER_INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Node Exporter 目录失败！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在下载 Node Exporter v${NODE_EXPORTER_VERSION}...${NC}"
    wget -O /tmp/node_exporter.tar.gz "$NODE_EXPORTER_DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：下载 Node Exporter 失败，请检查网络！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在解压并安装 Node Exporter...${NC}"
    tar -xzf /tmp/node_exporter.tar.gz -C /tmp
    mv /tmp/node_exporter-${NODE_EXPORTER_VERSION}.${PROM_ARCH}/* "$NODE_EXPORTER_INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：解压或移动 Node Exporter 文件失败！${NC}"
        exit 1
    fi

    # 清理临时文件
    rm -rf /tmp/node_exporter.tar.gz /tmp/node_exporter-${NODE_EXPORTER_VERSION}.${PROM_ARCH}

    # 创建 Node Exporter 用户和组
    echo -e "${YELLOW}正在创建 Node Exporter 用户和组...${NC}"
    useradd -M -s /bin/false node_exporter || true
    chown -R node_exporter:node_exporter "$NODE_EXPORTER_INSTALL_DIR"

    # 创建 Node Exporter systemd 服务文件
    echo -e "${YELLOW}正在创建 Node Exporter systemd 服务文件...${NC}"
    cat > "$NODE_EXPORTER_SERVICE_FILE" <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=$NODE_EXPORTER_INSTALL_DIR/node_exporter

[Install]
WantedBy=multi-user.target
EOF
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Node Exporter 服务文件失败！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Node Exporter 安装完成！${NC}"
fi

# 安装 Grafana 的逻辑
if [ "$INSTALL_GRAFANA" == "y" ]; then
    echo -e "${YELLOW}正在安装 Grafana...${NC}"
    if command -v apt &> /dev/null; then
        apt update
        apt install -y software-properties-common
        add-apt-repository -y "deb https://packages.grafana.com/oss/deb stable main"
        curl -s https://packages.grafana.com/gpg.key | apt-key add -
        apt update
        apt install -y grafana
    elif command -v yum &> /dev/null; then
        cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
        yum install -y grafana
    else
        echo -e "${RED}错误：无法确定包管理器，无法安装 Grafana！${NC}"
        exit 1
    fi
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：安装 Grafana 失败！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Grafana 安装完成！${NC}"
fi

# 安装 Blackbox Exporter 的逻辑
if [ "$INSTALL_BLACKBOX" == "y" ]; then
    echo -e "${YELLOW}正在获取 Blackbox Exporter 最新版本...${NC}"
    BLACKBOX_VERSION=$(curl -s https://api.github.com/repos/prometheus/blackbox_exporter/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "$BLACKBOX_VERSION" ]; then
        echo -e "${RED}错误：无法获取 Blackbox Exporter 最新版本，请检查网络！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Blackbox Exporter 最新版本为：$BLACKBOX_VERSION${NC}"
    BLACKBOX_DOWNLOAD_URL="https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.${PROM_ARCH}.tar.gz"

    # 检查 Blackbox Exporter 下载链接是否有效
    echo -e "${YELLOW}正在验证 Blackbox Exporter 下载链接...${NC}"
    HTTP_STATUS=$(curl -s -I "$BLACKBOX_DOWNLOAD_URL" | grep -i "HTTP/" | awk '{print $2}' | head -1)
    if [[ "$HTTP_STATUS" != "200" && "$HTTP_STATUS" != "302" ]]; then
        echo -e "${RED}错误：无效的 Blackbox Exporter 下载链接 ($BLACKBOX_DOWNLOAD_URL)！${NC}"
        echo -e "${YELLOW}HTTP 状态码：$HTTP_STATUS${NC}"
        exit 1
    fi
    echo -e "${GREEN}Blackbox Exporter 下载链接有效，HTTP 状态码：$HTTP_STATUS${NC}"

    echo -e "${YELLOW}正在创建 Blackbox Exporter 安装目录和数据目录...${NC}"
    mkdir -p "$BLACKBOX_INSTALL_DIR" "$BLACKBOX_DATA_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Blackbox Exporter 目录失败！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在下载 Blackbox Exporter v${BLACKBOX_VERSION}...${NC}"
    wget -O /tmp/blackbox_exporter.tar.gz "$BLACKBOX_DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：下载 Blackbox Exporter 失败，请检查网络！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在解压并安装 Blackbox Exporter...${NC}"
    tar -xzf /tmp/blackbox_exporter.tar.gz -C /tmp
    mv /tmp/blackbox_exporter-${BLACKBOX_VERSION}.${PROM_ARCH}/* "$BLACKBOX_INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：解压或移动 Blackbox Exporter 文件失败！${NC}"
        exit 1
    fi

    # 清理临时文件
    rm -rf /tmp/blackbox_exporter.tar.gz /tmp/blackbox_exporter-${BLACKBOX_VERSION}.${PROM_ARCH}

    # 创建 Blackbox Exporter 用户和组
    echo -e "${YELLOW}正在创建 Blackbox Exporter 用户和组...${NC}"
    useradd -M -s /bin/false blackbox || true
    chown -R blackbox:blackbox "$BLACKBOX_INSTALL_DIR" "$BLACKBOX_DATA_DIR"

    # 创建 Blackbox Exporter 配置文件
    echo -e "${YELLOW}正在创建 Blackbox Exporter 配置文件...${NC}"
    cat > "$BLACKBOX_INSTALL_DIR/config.yml" <<EOF
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: [200, 201, 202, 203, 204]
      method: GET
  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: ip4
EOF
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Blackbox Exporter 配置文件失败！${NC}"
        exit 1
    fi
    chown blackbox:blackbox "$BLACKBOX_INSTALL_DIR/config.yml"

    # 创建 Blackbox Exporter systemd 服务文件
    echo -e "${YELLOW}正在创建 Blackbox Exporter systemd 服务文件...${NC}"
    cat > "$BLACKBOX_SERVICE_FILE" <<EOF
[Unit]
Description=Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=blackbox
Group=blackbox
Type=simple
ExecStart=$BLACKBOX_INSTALL_DIR/blackbox_exporter --config.file=$BLACKBOX_INSTALL_DIR/config.yml

[Install]
WantedBy=multi-user.target
EOF
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Blackbox Exporter 服务文件失败！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Blackbox Exporter 安装完成！${NC}"
fi

# 安装 Alertmanager 的逻辑
if [ "$INSTALL_ALERTMANAGER" == "y" ]; then
    echo -e "${YELLOW}正在获取 Alertmanager 最新版本...${NC}"
    ALERTMANAGER_VERSION=$(curl -s https://api.github.com/repos/prometheus/alertmanager/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "$ALERTMANAGER_VERSION" ]; then
        echo -e "${RED}错误：无法获取 Alertmanager 最新版本，请检查网络！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Alertmanager 最新版本为：$ALERTMANAGER_VERSION${NC}"
    ALERTMANAGER_DOWNLOAD_URL="https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.${PROM_ARCH}.tar.gz"

    # 检查 Alertmanager 下载链接是否有效
    echo -e "${YELLOW}正在验证 Alertmanager 下载链接...${NC}"
    HTTP_STATUS=$(curl -s -I "$ALERTMANAGER_DOWNLOAD_URL" | grep -i "HTTP/" | awk '{print $2}' | head -1)
    if [[ "$HTTP_STATUS" != "200" && "$HTTP_STATUS" != "302" ]]; then
        echo -e "${RED}错误：无效的 Alertmanager 下载链接 ($ALERTMANAGER_DOWNLOAD_URL)！${NC}"
        echo -e "${YELLOW}HTTP 状态码：$HTTP_STATUS${NC}"
        exit 1
    fi
    echo -e "${GREEN}Alertmanager 下载链接有效，HTTP 状态码：$HTTP_STATUS${NC}"

    echo -e "${YELLOW}正在创建 Alertmanager 安装目录和数据目录...${NC}"
    mkdir -p "$ALERTMANAGER_INSTALL_DIR" "$ALERTMANAGER_DATA_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Alertmanager 目录失败！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在下载 Alertmanager v${ALERTMANAGER_VERSION}...${NC}"
    wget -O /tmp/alertmanager.tar.gz "$ALERTMANAGER_DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：下载 Alertmanager 失败，请检查网络！${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在解压并安装 Alertmanager...${NC}"
    tar -xzf /tmp/alertmanager.tar.gz -C /tmp
    mv /tmp/alertmanager-${ALERTMANAGER_VERSION}.${PROM_ARCH}/* "$ALERTMANAGER_INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：解压或移动 Alertmanager 文件失败！${NC}"
        exit 1
    fi

    # 清理临时文件
    rm -rf /tmp/alertmanager.tar.gz /tmp/alertmanager-${ALERTMANAGER_VERSION}.${PROM_ARCH}

    # 创建 Alertmanager 用户和组
    echo -e "${YELLOW}正在创建 Alertmanager 用户和组...${NC}"
    useradd -M -s /bin/false alertmanager || true
    chown -R alertmanager:alertmanager "$ALERTMANAGER_INSTALL_DIR" "$ALERTMANAGER_DATA_DIR"

    # 创建 Alertmanager systemd 服务文件
    echo -e "${YELLOW}正在创建 Alertmanager systemd 服务文件...${NC}"
    cat > "$ALERTMANAGER_SERVICE_FILE" <<EOF
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=$ALERTMANAGER_INSTALL_DIR/alertmanager --config.file=$ALERTMANAGER_INSTALL_DIR/alertmanager.yml --storage.path=$ALERTMANAGER_DATA_DIR

[Install]
WantedBy=multi-user.target
EOF
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：创建 Alertmanager 服务文件失败！${NC}"
        exit 1
    fi
    echo -e "${GREEN}Alertmanager 安装完成！${NC}"
fi

# 重新加载 systemd 并启动服务
echo -e "${YELLOW}正在启动已安装的服务...${NC}"
systemctl daemon-reload
systemctl reset-failed

if [ "$INSTALL_PROMETHEUS" == "y" ]; then
    systemctl start prometheus
    systemctl enable prometheus
    if systemctl is-active --quiet prometheus; then
        echo -e "${GREEN}Prometheus 安装成功并已启动！${NC}"
        echo -e "${GREEN}访问 http://你的服务器IP:9090 查看 Prometheus Web UI。${NC}"
    else
        echo -e "${RED}错误：Prometheus 服务启动失败！${NC}"
        echo -e "${YELLOW}请检查日志：journalctl -u prometheus -f${NC}"
        exit 1
    fi
fi

if [ "$INSTALL_NODE_EXPORTER" == "y" ]; then
    if [ -f "$NODE_EXPORTER_SERVICE_FILE" ]; then
        systemctl start node-exporter
        systemctl enable node-exporter
        if systemctl is-active --quiet node-exporter; then
            echo -e "${GREEN}Node Exporter 安装成功并已启动！${NC}"
            echo -e "${GREEN}访问 http://你的服务器IP:9100/metrics 查看 Node Exporter 指标。${NC}"
        else
            echo -e "${RED}错误：Node Exporter 服务启动失败！${NC}"
            echo -e "${YELLOW}请检查日志：journalctl -u node-exporter -f${NC}"
            exit 1
        fi
    else
        echo -e "${RED}错误：Node Exporter 服务文件未找到 ($NODE_EXPORTER_SERVICE_FILE)！${NC}"
        exit 1
    fi
fi

if [ "$INSTALL_GRAFANA" == "y" ]; then
    systemctl start grafana-server
    systemctl enable grafana-server
    if systemctl is-active --quiet grafana-server; then
        echo -e "${GREEN}Grafana 安装成功并已启动！${NC}"
        echo -e "${GREEN}访问 http://你的服务器IP:3000 查看 Grafana Web UI（默认用户/密码：admin/admin）。${NC}"
    else
        echo -e "${RED}错误：Grafana 服务启动失败！${NC}"
        echo -e "${YELLOW}请检查日志：journalctl -u grafana-server -f${NC}"
        exit 1
    fi
fi

if [ "$INSTALL_BLACKBOX" == "y" ]; then
    systemctl start blackbox-exporter
    systemctl enable blackbox-exporter
    if systemctl is-active --quiet blackbox-exporter; then
        echo -e "${GREEN}Blackbox Exporter 安装成功并已启动！${NC}"
        echo -e "${GREEN}访问 http://你的服务器IP:9115/metrics 查看 Blackbox Exporter 指标。${NC}"
    else
        echo -e "${RED}错误：Blackbox Exporter 服务启动失败！${NC}"
        echo -e "${YELLOW}请检查日志：journalctl -u blackbox-exporter -f${NC}"
        exit 1
    fi
fi

if [ "$INSTALL_ALERTMANAGER" == "y" ]; then
    systemctl start alertmanager
    systemctl enable alertmanager
    if systemctl is-active --quiet alertmanager; then
        echo -e "${GREEN}Alertmanager 安装成功并已启动！${NC}"
        echo -e "${GREEN}访问 http://你的服务器IP:9093 查看 Alertmanager Web UI。${NC}"
    else
        echo -e "${RED}错误：Alertmanager 服务启动失败！${NC}"
        echo -e "${YELLOW}请检查日志：journalctl -u alertmanager -f${NC}"
        exit 1
    fi
fi

# 总结安装结果
echo -e "${GREEN}安装完成！${NC}"
if [ "$INSTALL_PROMETHEUS" == "y" ]; then
    echo -e "${GREEN}Prometheus 版本：v${VERSION}${NC}"
fi
if [ "$INSTALL_NODE_EXPORTER" == "y" ]; then
    echo -e "${GREEN}Node Exporter 版本：v${NODE_EXPORTER_VERSION}${NC}"
fi
if [ "$INSTALL_GRAFANA" == "y" ]; then
    echo -e "${GREEN}Grafana 已安装（版本由包管理器确定）${NC}"
fi
if [ "$INSTALL_BLACKBOX" == "y" ]; then
    echo -e "${GREEN}Blackbox Exporter 版本：v${BLACKBOX_VERSION}${NC}"
fi
if [ "$INSTALL_ALERTMANAGER" == "y" ]; then
    echo -e "${GREEN}Alertmanager 版本：v${ALERTMANAGER_VERSION}${NC}"
fi
