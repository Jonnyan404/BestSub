#!/bin/sh

# Telegram Bot配置
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
# 代理配置（可以通过环境变量传入）
# 例如: export HTTP_PROXY=http://192.168.1.100:7890
PROXY_ARGS=""
if [ -n "$HTTP_PROXY" ]; then
    PROXY_ARGS="-x $HTTP_PROXY"
    echo "使用HTTP代理: $HTTP_PROXY"
elif [ -n "$HTTPS_PROXY" ]; then
    PROXY_ARGS="-x $HTTPS_PROXY"
    echo "使用HTTPS代理: $HTTPS_PROXY"
elif [ -n "$SOCKS_PROXY" ]; then
    PROXY_ARGS="--socks5 $SOCKS_PROXY"
    echo "使用SOCKS5代理: $SOCKS_PROXY"
fi

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



# 函数：统计JSON文件中name字段出现的次数
count_json_names() {
    #json_file="$1"
    yaml_file="$1"
    
    if [ ! -f "$yaml_file" ]; then
        echo "错误：YAML文件不存在 - $yaml_file"
        return 0
    fi
    
    # 从JSON中提取所有name字段，然后统计
    #jq -r '..|.name? | select(. != null)' "$json_file" | sort | uniq -c|wc -l
    yq '.proxies[].name' "$yaml_file" | wc -l
}

# 函数：发送Telegram消息
send_telegram_message() {
    message="$1"
    parse_mode="${2:-HTML}"  # 默认使用HTML格式

    # 发送消息
    if [ -n "$PROXY_ARGS" ]; then
        curl $PROXY_ARGS -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID" \
            -d "text=$message" \
            -d "parse_mode=$parse_mode" \
            -d "disable_web_page_preview=true"
    else
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID" \
            -d "text=$message" \
            -d "parse_mode=$parse_mode" \
            -d "disable_web_page_preview=true"
    fi
}


#res=$(count_json_names /tmp/bestsub_temp_proxies.json)
res=$(count_json_names /app/output/speed.yaml)
if [ "$res" -eq 0 ]; then
    send_telegram_message "无节点可用，请检查日志"
    exit 1
else
    send_telegram_message "-已更新 $res 个节点"
    exit 0
fi
