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

# 步骤2: 安装必要工具和包
echo "步骤2: 安装中文相关包..."
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    sudo apt install -y locales language-pack-zh-hans fonts-wqy-zenhei manpages-zh
elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
    # 先安装 EPEL 仓库
    if command -v dnf &> /dev/null; then
        sudo dnf install -y epel-release
        sudo dnf install -y glibc-common wqy-zenhei-fonts  # manpages-zh 可能不可用，跳过
    elif command -v yum &> /dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y glibc-common wqy-zenhei-fonts  # manpages-zh 可能不可用，跳过
    fi
    if [ $? -ne 0 ]; then
        echo "错误: EPEL 或包安装失败。请手动检查。"
        exit 1
    fi
fi

if [ $? -ne 0 ]; then
    echo "错误: 包安装失败。请手动检查包管理器错误日志。"
    exit 1
fi

# 步骤3: 生成和配置 Locale
echo "步骤3: 生成中文 Locale..."
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    sudo locale-gen zh_CN.UTF-8
    sudo update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8
elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
    sudo localedef -i zh_CN -f UTF-8 zh_CN.UTF-8  # 生成 Locale
    if [ $? -eq 0 ]; then
        echo "export LANG=zh_CN.UTF-8" | sudo tee -a /etc/locale.conf  # 设置系统级 Locale
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
echo "步骤5: 验证中文语言环境..."
locale  # 显示当前 Locale 设置
if locale | grep -q "zh_CN.UTF-8"; then
    echo "成功: 中文语言环境配置完成！"
    echo "提示: 请重新登录 SSH 会话以确保所有变化生效。"
else
    echo "警告: 配置可能未完全成功。请检查输出并手动验证。"
fi

# 检查vim是否已安装
echo "检查vim是否已安装..."
if command -v vim &> /dev/null; then
    echo "vim已安装，跳过安装步骤。"
else
    echo "vim未安装，正在安装..."
    if [ "$SYSTEM_TYPE" = "debian" ]; then
        sudo apt install -y vim
    elif [ "$SYSTEM_TYPE" = "centos" ]; then
        sudo yum install -y vim-enhanced
    fi
fi

# 配置vim支持中文编码
echo "配置vim支持中文编码..."
VIMRC="/etc/vimrc"
if [ "$SYSTEM_TYPE" = "debian" ]; then
    VIMRC="/etc/vim/vimrc"
fi
if [ -f "$VIMRC" ]; then
    if grep -q "set fileencodings=utf-8" "$VIMRC"; then
        echo "vim编码配置已存在，跳过添加。"
    else
        sudo bash -c "cat >> '$VIMRC' << EOF
\" 设置编码支持中文
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
set termencoding=utf-8
set encoding=utf-8
EOF"
        echo "vim编码配置已添加。"
    fi
else
    echo "vim配置文件 $VIMRC 不存在，请检查vim安装。"
fi

# 测试vim中文显示
echo "测试vim中文显示..."
TEST_FILE="/tmp/test_chinese.txt"
echo "测试中文显示 - Test Chinese Display" > "$TEST_FILE"
echo "请在vim中打开 $TEST_FILE 检查中文是否正常显示。"
echo "命令：vim $TEST_FILE"

echo "脚本执行完毕。如果有问题，请查看系统日志 (e.g., sudo cat /var/log/messages | grep locale) 或运行 'locale' 命令。"
