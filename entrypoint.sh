#!/bin/bash
set -e

echo "=== Proxy Checker with GitHub Data Sync ==="

# 配置 git
git config --global user.name "ProxyChecker Bot"
git config --global user.email "bot@proxychecker.local"

if [ -n "$GIT_REPO_URL" ] && [ -n "$GIT_TOKEN" ]; then
    echo "GitHub 数据同步已启用 → $GIT_REPO_URL"

    # 处理带 token 的仓库地址
    if [[ $GIT_REPO_URL == https://github.com/* ]]; then
        AUTH_URL="https://${GIT_TOKEN}@${GIT_REPO_URL#https://}"
    else
        AUTH_URL=$GIT_REPO_URL
    fi

    # 使用子shell执行 git 操作，避免改变主进程工作目录
    (
        cd /data
        if [ ! -d ".git" ]; then
            echo "首次克隆仓库..."
            git clone --depth 1 "$AUTH_URL" . 2>/dev/null || {
                echo "仓库为空，初始化新仓库..."
                git init
                git remote add origin "$AUTH_URL"
                git checkout -b ${GIT_BRANCH:-main}
                git commit --allow-empty -m "Initial commit"
            }
        else
            echo "拉取最新数据..."
            git pull --rebase origin ${GIT_BRANCH:-main} || echo "拉取失败，使用本地数据"
        fi

        # 启动后台自动同步
        if [ "${GIT_AUTO_PUSH:-true}" = "true" ]; then
            echo "已启动后台自动同步（每 ${GIT_SYNC_INTERVAL:-300} 秒）..."
            (
                while true; do
                    sleep ${GIT_SYNC_INTERVAL:-300}
                    if [ -n "$(git status --porcelain)" ]; then
                        git add -A
                        git commit -m "Auto sync at $(date '+%Y-%m-%d %H:%M:%S UTC%z')" 2>/dev/null || true
                        git push origin ${GIT_BRANCH:-main} 2>/dev/null || echo "推送失败，下次重试"
                    fi
                done
            ) &
        fi
    )
else
    echo "未设置 GIT_REPO_URL 或 GIT_TOKEN，数据仅保存在本地"
fi

echo "启动 Proxy Checker..."
cd /app
exec python server.py
