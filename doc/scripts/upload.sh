#!/bin/bash
# 功能: 将文件上传到GitHub Gist, WebDAV, 支持多种方式同时上传

# 配置文件路径
CONFIG_FILE="/app/config/config.yaml"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误: 配置文件 $CONFIG_FILE 不存在"
    exit 1
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

# 从配置文件获取GitHub token和Gist ID
GITHUB_TOKEN=$(yq '.save."github-token"' "$CONFIG_FILE")
GIST_ID=$(yq '.save."github-gist-id"' "$CONFIG_FILE")
GITHUB_API_MIRROR=$(yq '.save."github-api-mirror"' "$CONFIG_FILE")
WEBDAV_URL=$(yq '.save."webdav-url"' "$CONFIG_FILE")
WEBDAV_USERNAME=$(yq '.save."webdav-username"' "$CONFIG_FILE")
WEBDAV_PASSWORD=$(yq '.save."webdav-password"' "$CONFIG_FILE")

# 检查是否成功获取token和ID
if [ "$GITHUB_TOKEN" == "null" ] || [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" == '""' ]; then
    echo "错误: 配置文件中未找到GitHub令牌或令牌为空"
    #exit 1  # 不强制退出，允许只使用 WebDAV
fi

if [ "$GIST_ID" == "null" ] || [ -z "$GIST_ID" ] || [ "$GIST_ID" == '""' ]; then
    echo "错误: 配置文件中未找到Gist ID或ID为空"
    #exit 1  # 不强制退出，允许只使用 WebDAV
fi

if [ "$WEBDAV_URL" == "null" ] || [ -z "$WEBDAV_URL" ] || [ "$WEBDAV_URL" == '""' ]; then
    echo "错误: 配置文件中未找到WebDAV URL或URL为空"
    #exit 1 # 不强制退出，允许只使用 Gist
fi

if [ "$WEBDAV_USERNAME" == "null" ] || [ -z "$WEBDAV_USERNAME" ] || [ "$WEBDAV_USERNAME" == '""' ]; then
    echo "错误: 配置文件中未找到WebDAV 用户名或用户名为空"
    #exit 1 # 不强制退出，允许只使用 Gist
fi

if [ "$WEBDAV_PASSWORD" == "null" ] || [ -z "$WEBDAV_PASSWORD" ] || [ "$WEBDAV_PASSWORD" == '""' ]; then
    echo "错误: 配置文件中未找到WebDAV 密码或密码为空"
    #exit 1 # 不强制退出，允许只使用 Gist
fi

# 确定要使用的API URL
API_URL="https://api.github.com"
if [ "$GITHUB_API_MIRROR" != "null" ] && [ -n "$GITHUB_API_MIRROR" ] && [ "$GITHUB_API_MIRROR" != '""' ]; then
    API_URL="$GITHUB_API_MIRROR"
fi

# 检查命令行参数
if [ $# -lt 2 ]; then
    echo "用法: $0 <文件路径> <上传方式: gist,webdav,all,none> [描述]"
    echo "  上传方式: gist - 上传到 GitHub Gist"
    echo "           webdav - 上传到 WebDAV"
    echo "           all - 同时上传到 GitHub Gist 和 WebDAV"
    echo "           none - 不上传"
    exit 1
fi

FILE_PATH="$1"
UPLOAD_METHOD="$2"
DESCRIPTION="${3:-更新于 $(date '+%Y-%m-%d %H:%M:%S')}"

# 检查文件是否存在
if [ ! -f "$FILE_PATH" ]; then
    echo "错误: 文件 $FILE_PATH 不存在"
    exit 1
fi

# 定义上传函数
upload_to_gist() {
    echo "使用 GitHub Gist 上传..."
    # 获取文件名和内容
    FILE_NAME=$(basename "$FILE_PATH")
    FILE_CONTENT=$(cat "$FILE_PATH")

    # 构建JSON请求体
    JSON_DATA=$(cat <<EOF
{
  "description": "$DESCRIPTION",
  "files": {
    "$FILE_NAME": {
      "content": $(echo "$FILE_CONTENT" | jq -Rs .)
    }
  }
}
EOF
)

    echo "正在更新Gist ID: $GIST_ID 的文件: $FILE_NAME..."

    # 发送请求更新Gist
    RESPONSE=$(curl -s -X PATCH \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$JSON_DATA" \
        "$API_URL/gists/$GIST_ID")

    # 检查响应
    if echo "$RESPONSE" | grep -q '"html_url"'; then
        URL=$(echo "$RESPONSE" | grep -o '"html_url":"[^"]*' | sed 's/"html_url":"//')
        echo "上传成功! Gist URL: $URL"
    else
        echo "上传失败，API响应:"
        echo "$RESPONSE"
        return 1
    fi
    return 0
}

upload_to_webdav() {
    echo "使用 WebDAV 上传..."
    FILE_NAME=$(basename "$FILE_PATH")
    UPLOAD_URL="$WEBDAV_URL/$FILE_NAME"

    RESPONSE=$(curl -s -X PUT \
        -T "$FILE_PATH" \
        -u "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" \
        "$UPLOAD_URL")

    # 检查响应
    if [ "$?" -eq "0" ]; then
        echo "WebDAV 上传成功! URL: $UPLOAD_URL"
    else
        echo "WebDAV 上传失败，响应:"
        echo "$RESPONSE"
        return 1
    fi
    return 0
}

# 根据上传方式执行不同的操作
case "$UPLOAD_METHOD" in
    gist)
        if [ -z "$GITHUB_TOKEN" ] || [ -z "$GIST_ID" ]; then
            echo "缺少 GitHub Token 或 Gist ID，无法上传到 Gist"
            exit 1
        fi
        upload_to_gist
        ;;
    webdav)
        if [ -z "$WEBDAV_URL" ] || [ -z "$WEBDAV_USERNAME" ] || [ -z "$WEBDAV_PASSWORD" ]; then
            echo "缺少 WebDAV URL, 用户名或密码，无法上传到 WebDAV"
            exit 1
        fi
        upload_to_webdav
        ;;
    all)
        UPLOAD_SUCCESS=0
        if [ ! -z "$GITHUB_TOKEN" ] && [ ! -z "$GIST_ID" ]; then
            upload_to_gist || UPLOAD_SUCCESS=1
        else
            echo "缺少 GitHub Token 或 Gist ID，跳过 Gist 上传"
        fi

        if [ ! -z "$WEBDAV_URL" ] && [ ! -z "$WEBDAV_USERNAME" ] && [ ! -z "$WEBDAV_PASSWORD" ]; then
            upload_to_webdav || UPLOAD_SUCCESS=1
        else
            echo "缺少 WebDAV URL, 用户名或密码，跳过 WebDAV 上传"
        fi

        if [ "$UPLOAD_SUCCESS" -eq "1" ]; then
            echo "部分上传失败"
            exit 1
        fi
        ;;
    none)
        echo "不上传文件"
        exit 0
        ;;
    *)
        echo "错误: 不支持的上传方式: $UPLOAD_METHOD"
        exit 1
        ;;
esac