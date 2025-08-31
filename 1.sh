#!/bin/sh

# OpenWRT Xray 一键安装脚本
# 支持大多数常见CPU架构（x86_64、arm、aarch64、mips等）
# 项目地址：https://github.com/XTLS/Xray-core

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检测系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)    ARCH="64" ;;
    armv7l)    ARCH="arm32-v7a" ;;
    aarch64)   ARCH="arm64-v8a" ;;
    mips)      ARCH="mips32" ;;
    mipsel)    ARCH="mips32el" ;;
    *)         echo -e "${RED}不支持的架构: $ARCH${NC}"; exit 1 ;;
esac

# 获取最新版本号
get_latest_version() {
    wget -qO- -t1 -T2 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | \
    grep "tag_name" | \
    head -n 1 | \
    awk -F ":" '{print $2}' | \
    sed 's/\"//g;s/,//g;s/ //g'
}

# 安装必要组件
install_dependencies() {
    echo -e "${YELLOW}安装必要依赖...${NC}"
    opkg update
    opkg install wget unzip ca-bundle
}

# 下载并安装Xray
install_xray() {
    VERSION=$(get_latest_version)
    if [ -z "$VERSION" ]; then
        echo -e "${RED}获取版本信息失败${NC}"
        exit 1
    fi

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip"

    echo -e "${YELLOW}下载Xray ${VERSION} (${ARCH})...${NC}"
    wget -O /tmp/xray.zip ${DOWNLOAD_URL}

    echo -e "${YELLOW}解压文件...${NC}"
    unzip -o /tmp/xray.zip -d /tmp/xray

    echo -e "${YELLOW}安装文件...${NC}"
    mv -f /tmp/xray/xray /usr/bin/xray
    chmod +x /usr/bin/xray

    # 创建配置文件目录
    mkdir -p /etc/xray

    # 创建示例配置文件
    if [ ! -f /etc/xray/config.json ]; then
        cat > /etc/xray/config.json << EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 1080,
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
    fi
}

# 创建init服务
create_service() {
    echo -e "${YELLOW}创建系统服务...${NC}"
    cat > /etc/init.d/xray << EOF
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/xray run -config /etc/xray/config.json
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall xray
}
EOF

    chmod +x /etc/init.d/xray
    /etc/init.d/xray enable
}

# 清理安装文件
cleanup() {
    rm -rf /tmp/xray /tmp/xray.zip
}

main() {
    echo -e "${GREEN}开始安装Xray...${NC}"
    install_dependencies
    install_xray
    create_service
    cleanup
    echo -e "${GREEN}安装完成！${NC}"
    echo -e "配置文件位置：/etc/xray/config.json"
    echo -e "使用命令：/etc/init.d/xray start 启动服务"
}

main "$@"
