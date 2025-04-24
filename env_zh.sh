#!/bin/bash
# 脚本目的：设置系统语言环境为中文（zh_CN.UTF-8），解决vim中文乱码问题，并确保vim已安装，适配不同Linux发行版

echo "开始设置系统语言环境和vim配置以解决中文乱码问题..."

# 步骤1：检测系统类型
echo "检测系统类型..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
elif [ -f /etc/redhat-release ]; then
    DISTRO="centos"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
else
    echo "无法确定系统类型，脚本可能不兼容您的系统。"
    exit 1
fi
echo "检测到的系统类型：$DISTRO"

# 步骤2：安装必要的语言包
echo "检查并安装语言包..."
case "$DISTRO" in
    "ubuntu"|"debian")
        if ! dpkg -l | grep -q locales; then
            apt update
            apt install -y locales
        fi
        ;;
    "centos"|"rhel"|"fedora")
        if ! rpm -q glibc-langpack-zh &> /dev/null; then
            yum install -y glibc-langpack-zh || dnf install -y glibc-langpack-zh
        fi
        ;;
    *)
        echo "不支持的系统类型：$DISTRO，无法安装语言包。"
        exit 1
        ;;
esac

# 步骤3：生成zh_CN.UTF-8语言环境
echo "生成zh_CN.UTF-8语言环境..."
case "$DISTRO" in
    "ubuntu"|"debian")
        if ! grep -q "^zh_CN.UTF-8 UTF-8" /etc/locale.gen; then
            sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
        fi
        locale-gen
        ;;
    "centos"|"rhel"|"fedora")
        # CentOS/RHEL/Fedora 系统语言环境通常已预生成，只需确保存在
        if ! locale -a | grep -q "zh_CN.utf8"; then
            echo "zh_CN.UTF-8 语言环境未找到，尝试生成..."
            localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8
        fi
        ;;
    *)
        echo "不支持的系统类型：$DISTRO，无法生成语言环境。"
        exit 1
        ;;
esac

# 步骤4：设置系统默认语言环境为zh_CN.UTF-8
echo "设置系统默认语言环境为zh_CN.UTF-8..."
case "$DISTRO" in
    "ubuntu"|"debian")
        echo "LANG=zh_CN.UTF-8" > /etc/default/locale
        echo "LANGUAGE=zh_CN:zh" >> /etc/default/locale
        echo "LC_CTYPE=zh_CN.UTF-8" >> /etc/default/locale
        sed -i '/LC_ALL/d' /etc/default/locale 2>/dev/null || true
        ;;
    "centos"|"rhel"|"fedora")
        echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
        echo "LC_CTYPE=zh_CN.UTF-8" >> /etc/locale.conf
        sed -i '/LC_ALL/d' /etc/locale.conf 2>/dev/null || true
        ;;
    *)
        echo "不支持的系统类型：$DISTRO，无法设置语言环境。"
        exit 1
        ;;
esac

# 步骤5：更新当前会话的环境变量
echo "更新当前会话环境变量..."
unset LC_ALL 2>/dev/null || true
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_CTYPE=zh_CN.UTF-8

# 步骤6：检查语言环境是否正确设置
echo "当前语言环境设置如下："
locale

# 步骤7：检查vim是否已安装，如果未安装则进行安装
echo "检查vim是否已安装..."
if ! command -v vim &> /dev/null; then
    echo "vim未安装，正在安装vim..."
    case "$DISTRO" in
        "ubuntu"|"debian")
            apt update
            apt install -y vim
            ;;
        "centos"|"rhel"|"fedora")
            yum install -y vim-enhanced || dnf install -y vim-enhanced
            ;;
        *)
            echo "不支持的系统类型：$DISTRO，无法安装vim。"
            exit 1
            ;;
    esac
    if [ $? -eq 0 ]; then
        echo "vim安装成功。"
    else
        echo "vim安装失败，请检查网络或软件源设置。"
        exit 1
    fi
else
    echo "vim已安装，跳过安装步骤。"
fi

# 步骤8：配置vim支持中文编码
echo "配置vim支持中文编码..."
VIMRC="/etc/vimrc"
if [ ! -f "$VIMRC" ]; then
    VIMRC="/etc/vim/vimrc"
fi
if [ -f "$VIMRC" ]; then
    # 检查是否已配置编码设置，避免重复添加
    if ! grep -q "set encoding=utf-8" "$VIMRC"; then
        cat >> "$VIMRC" << 'EOF'

" 设置编码为UTF-8以支持中文
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
set termencoding=utf-8
EOF
        echo "vim编码配置已添加到 $VIMRC"
    else
        echo "vim编码配置已存在，跳过添加。"
    fi
else
    echo "警告：$VIMRC 文件不存在，尝试为root用户创建 ~/.vimrc"
    echo -e "set encoding=utf-8\nset fileencoding=utf-8\nset fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1\nset termencoding=utf-8" > ~/.vimrc
fi

# 步骤9：测试中文显示
echo "测试vim中文显示..."
echo "测试中文显示 - Test Chinese Display" > /tmp/test_chinese.txt
echo "请在vim中打开 /tmp/test_chinese.txt 检查中文是否正常显示。"
echo "命令：vim /tmp/test_chinese.txt"

# 步骤10：清理
echo "清理包管理缓存..."
case "$DISTRO" in
    "ubuntu"|"debian")
        apt clean
        ;;
    "centos"|"rhel"|"fedora")
        yum clean all || dnf clean all
        ;;
    *)
        echo "不支持的系统类型：$DISTRO，跳过清理。"
        ;;
esac

echo "脚本执行完成！"
echo "注意：如果通过SSH连接，请确保终端客户端（如PuTTY、iTerm2）字符编码设置为UTF-8。"
echo "如果中文仍显示乱码，请重新登录shell或重启系统以应用语言环境更改。"
echo "如有问题，请提供以下信息："
echo "1. locale 命令输出"
echo "2. vim /tmp/test_chinese.txt 时中文是否乱码"
echo "3. 使用的终端类型（本地或SSH客户端）"
