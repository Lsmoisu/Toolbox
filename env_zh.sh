#!/bin/bash

# 步骤0: 检测操作系统
OS_ID=""
if [ -f /etc/os-release ]; then
    source /etc/os-release  # 加载 OS 变量
    OS_ID=$ID
fi

echo "检测到的操作系统: $OS_ID"

# 步骤1: 更新系统（根据 OS 使用不同的包管理器）
echo "步骤1: 更新系统..."
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    sudo apt update && sudo apt upgrade -y
elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
    if command -v dnf &> /dev/null; then  # CentOS 8+
        sudo dnf update -y
    elif command -v yum &> /dev/null; then  # CentOS 7
        sudo yum update -y
    else
        echo "错误: 未找到包管理器 (yum 或 dnf)。脚本无法继续。"
        exit 1
    fi
else
    echo "错误: 不支持的操作系统 ($OS_ID)。仅支持 Ubuntu/Debian 和 CentOS/RHEL。"
    exit 1
fi

if [ $? -ne 0 ]; then
    echo "错误: 系统更新失败。请检查网络或权限。"
    exit 1
fi

# 步骤1.5: 设置时区为东八区 (Asia/Shanghai)
echo "步骤1.5: 设置时区为东八区 (Asia/Shanghai)..."
if command -v timedatectl &> /dev/null; then  # 检查 timedatectl 是否可用
    sudo timedatectl set-timezone Asia/Shanghai
    if [ $? -eq 0 ]; then
        echo "成功: 时区已设置为 Asia/Shanghai。"
        timedatectl  # 显示当前时区以验证
    else
        echo "警告: 时区设置失败。请手动运行 'sudo timedatectl set-timezone Asia/Shanghai'。"
    fi
else
    echo "警告: timedatectl 命令不可用。时区设置跳过。请手动配置时区。"
fi

# 步骤2: 安装必要工具和包
echo "步骤2: 安装中文相关包..."
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    sudo apt install -y locales fonts-wqy-zenhei manpages-zh  # 移除 language-pack-zh-hans
    if [ $? -ne 0 ]; then
        echo "警告: 某些包安装失败 (如 language-pack-zh-hans 不可用)。将继续执行其他步骤。"
    fi
elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
    # 先安装 EPEL 仓库
    if command -v dnf &> /dev/null; then
        sudo dnf install -y epel-release
        sudo dnf install -y glibc-common wqy-zenhei-fonts
    elif command -v yum &> /dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y glibc-common wqy-zenhei-fonts
    fi
    if [ $? -ne 0 ]; then
        echo "错误: EPEL 或包安装失败。请手动检查。"
        exit 1  # CentOS 分支保持严格
    fi
fi

# 步骤2.5: 检测并安装 Vim，并修复中文乱码
echo "步骤2.5: 检测并安装 Vim，并修复中文乱码..."
if ! command -v vim &> /dev/null; then  # 检查 Vim 是否已安装
    echo "Vim 未安装，正在安装..."
    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
        sudo apt install -y vim
    elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
        if command -v dnf &> /dev/null; then
            sudo dnf install -y vim
        elif command -v yum &> /dev/null; then
            sudo yum install -y vim
        fi
    fi
    if [ $? -ne 0 ]; then
        echo "警告: Vim 安装失败。请手动安装 (sudo apt/yum/dnf install vim)。"
    else
        echo "成功: Vim 已安装。"
    fi
else
    echo "Vim 已安装。"
fi

# 修复 Vim 中文乱码：修改 ~/.vimrc
if command -v vim &> /dev/null; then  # 确保 Vim 已可用
    VIMRC_FILE=~/.vimrc
    if [ ! -f "$VIMRC_FILE" ]; then  # 如果文件不存在，创建它
        touch "$VIMRC_FILE"
        echo "\" 新创建的 Vim 配置文件" > "$VIMRC_FILE"
    fi
    # 添加或更新配置
    if grep -q "set encoding=utf-8" "$VIMRC_FILE"; then
        echo "Vim 配置中已包含 encoding 设置。"
    else
        echo "set encoding=utf-8" >> "$VIMRC_FILE"
        echo "set fileencodings=utf-8,ucs-bom,gbk,gb18030,gb2312,big5" >> "$VIMRC_FILE"
        echo "成功: 已添加 Vim 中文支持配置。"
    fi
    if [ $? -ne 0 ]; then
        echo "警告: Vim 配置修改失败。请手动编辑 ~/.vimrc。"
    fi
else
    echo "警告: Vim 不可用，无法修复中文乱码。"
fi

# 步骤3: 生成和配置 Locale
echo "步骤3: 生成中文 Locale..."
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    sudo locale-gen zh_CN.UTF-8
    sudo update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8
elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
    sudo localedef -i zh_CN -f UTF-8 zh_CN.UTF-8
    if [ $? -eq 0 ]; then
        echo "export LANG=zh_CN.UTF-8" | sudo tee -a /etc/locale.conf
        echo "export LC_ALL=zh_CN.UTF-8" | sudo tee -a /etc/locale.conf
    else
        echo "错误: Locale 生成失败。"
        exit 1
    fi
fi

if [ $? -ne 0 ]; then
    echo "错误: 更新系统 Locale 失败。"
    exit 1
fi

# 步骤4: 设置用户环境变量
echo "步骤4: 配置用户环境变量..."
echo 'export LANG=zh_CN.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=zh_CN.UTF-8' >> ~/.bashrc
source ~/.bashrc  # 立即应用更改
if [ $? -ne 0 ]; then
    echo "警告: 环境变量设置可能未完全生效。请重新登录 SSH。"
fi

# 步骤5: 验证配置
echo "步骤5: 验证中文语言环境、时区和 Vim 配置..."
locale  # 显示当前 Locale 设置
timedatectl  # 显示当前时区设置
if locale | grep -q "zh_CN.UTF-8"; then
    echo "成功: 中文语言环境配置完成！"
else
    echo "警告: 配置可能未完全成功。请检查输出并手动验证。"
fi

echo "提示: 请重新登录 SSH 会话以确保所有变化生效，包括时区和 Vim 设置。"

echo "脚本执行完毕。如果有问题，请查看系统日志 (e.g., sudo cat /var/log/syslog | grep locale 或 sudo cat /var/log/messages | grep vim)。"
