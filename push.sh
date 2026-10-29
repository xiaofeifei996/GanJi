#!/bin/bash
# 进入仓库目录
cd /var/mobile/Documents/GanJi
# 一键推送核心命令
git add . && git commit -m "自动推送: $(date '+%Y-%m-%d %H:%M:%S')" && git push -f origin main