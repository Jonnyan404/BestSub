#!/bin/sh

# 安装依赖
command -v yq >/dev/null 2>&1 || {
    echo "需要安装yq工具来解析YAML文件"
    echo "正在尝试安装yq..."

    # 检查是否为 Alpine Linux
    if command -v apk >/dev/null 2>&1; then
        echo "检测到 Alpine Linux, 使用 apk 安装 yq 和 jq"
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
        apk add --no-cache yq jq curl
    # 检查是否为 Debian/Ubuntu
    elif command -v apt-get >/dev/null 2>&1; then
        echo "检测到 Debian/Ubuntu, 使用 apt-get 安装 yq 和 jq"
        # 替换 apt 源为国内镜像
        if grep -q "mirrors.aliyun.com" /etc/apt/sources.list; then
            echo "apt 源已配置为阿里云镜像"
        else
            echo "替换 apt 源为阿里云镜像"
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            cat > /etc/apt/sources.list <<EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.aliyun.com/debian/ bookworm main contrib non-free
# deb-src https://mirrors.aliyun.com/debian/ bookworm main contrib non-free

deb https://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free
# deb-src https://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free

deb https://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free
# deb-src https://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free

deb https://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free
# deb-src https://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free
EOF
        fi
        apt-get update
        apt-get install -y yq jq curl
    else
        echo "未检测到支持的 Linux 发行版，请手动安装 yq curl: https://github.com/mikefarah/yq"
        exit 1
    fi
}

# 生成所有存活节点
if yq -o=yaml  /tmp/bestsub_temp_proxies.json > /app/output/alive-all.yaml; then
    echo "alpine: 生成所有存活节点成功"
else
    yq -y  /tmp/bestsub_temp_proxies.json > /app/output/alive-all.yaml
    echo "ubuntu: 生成所有存活节点成功"
fi