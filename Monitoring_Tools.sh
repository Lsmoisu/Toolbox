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
