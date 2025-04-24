#!/bin/bash
# 脚本名称：setup_locale_vim_chinese.sh
# 功能：设置系统语言环境和Vim配置以解决中文乱码问题
# 适用系统：Debian/Ubuntu

echo "开始设置系统语言环境和Vim配置以解决中文乱码问题..."

# 检测系统类型
if [ -f /etc/debian_version ]; then
    SYSTEM_TYPE="debian"
    echo "检测到的系统类型：debian"
else
    echo "不支持的系统类型！此脚本仅适用于Debian/Ubuntu系统。"
    exit 1
fi

# 检查并安装语言包
echo "检查并安装语言包..."
sudo apt update
sudo apt install -y locales

# 生成zh_CN.UTF-8语言环境
echo "生成zh_CN.UTF-8语言环境..."
if [ -f /etc/locale.gen ]; then
    sudo sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
else
    sudo bash -c 'echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen'
fi
sudo locale-gen

# 设置系统默认语言环境为zh_CN.UTF-8
echo "设置系统默认语言环境为zh_CN.UTF-8..."
sudo bash -c 'echo "LANG=zh_CN.UTF-8" > /etc/default/locale'
sudo bash -c 'echo "LANGUAGE=zh_CN:zh" >> /etc/default/locale'
sudo bash -c 'echo "LC_CTYPE=zh_CN.UTF-8" >> /etc/default/locale'

# 更新当前会话环境变量
echo "更新当前会话环境变量..."
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_CTYPE=zh_CN.UTF-8
unset LC_ALL

# 检查当前语言环境设置
echo "当前语言环境设置如下："
locale

# 检查语言环境是否可用
echo "检查可用语言环境列表："
locale -a

# 检查vim是否已安装
echo "检查vim是否已安装..."
if command -v vim &> /dev/null; then
    echo "vim已安装，跳过安装步骤。"
else
    echo "vim未安装，正在安装..."
    sudo apt install -y vim
fi

# 配置vim支持中文编码
echo "配置vim支持中文编码..."
VIMRC="/etc/vim/vimrc"
if [ -f "$VIMRC" ]; then
    if grep -q "set fileencodings=utf-8" "$VIMRC"; then
        echo "vim编码配置已存在，跳过添加。"
    else
        sudo bash -c 'cat >> "$VIMRC" << EOF
" 设置编码支持中文
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
set termencoding=utf-8
set encoding=utf-8
EOF'
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

# 清理包管理缓存
echo "清理包管理缓存..."
sudo apt autoremove -y
sudo apt autoclean

echo "脚本执行完成！"
echo "注意：如果通过SSH连接，请确保终端客户端（如PuTTY、iTerm2）字符编码设置为UTF-8。"
echo "如果中文仍显示乱码，请重新登录shell或重启系统以应用语言环境更改。"
echo "如有问题，请提供以下信息："
echo "1. locale 命令输出"
echo "2. vim $TEST_FILE 时中文是否乱码"
echo "3. 使用的终端类型（本地或SSH客户端）"
