#!/bin/sh

# 生成所有存活节点
yq -o=yaml eval-all '.' /tmp/bestsub_temp_proxies.json > /app/output/alive-all.yaml