#!/bin/bash
set -e

echo "=== Proxy Checker with GitHub Data Sync (Optimized v2) ==="
echo "启动时间: $(date '+%Y-%m-%d %H:%M:%S')"

# Git 配置
git config --global user.name "ProxyChecker Bot"
git config --global user.email "bot@proxychecker.local"

# 创建立即同步脚本（供 Python 调用，实现“保存到云端”后立刻推送）
cat > /sync.sh << 'EOF'
#!/bin/bash
cd /data
echo "[$(date '+%H:%M:%S')] === 执行立即同步 ==="

if [ -n "$(git status --porcelain)" ]; then
    echo "[$(date '+%H:%M:%S')] 检测到文件变更，正在提交..."
    git add -A
    git commit -m "Cloud Save from UI at $(date '+%Y-%m-%d %H:%M:%S UTC%z')" 2>&1
    if git push origin ${GIT_BRANCH:-main} 2>&1; then
        echo "[$(date '+%H:%M:%S')] ✅ 成功推送到 GitHub"
    else
        echo "[$(date '+%H:%M:%S')] ❌ 推送失败（检查 Token 或网络）"
        git pull --rebase origin ${GIT_BRANCH:-main} 2>/dev/null || true
        git push origin ${GIT_BRANCH:-main} 2>&1
    fi
else
    echo "[$(date '+%H:%M:%S')] 没有检测到文件变化"
fi
EOF
chmod +x /sync.sh
echo "已创建立即同步脚本 /sync.sh（可被 Python 调用）"

if [ -n "$GIT_REPO_URL" ] && [ -n "$GIT_TOKEN" ]; then
    echo "GitHub 数据同步已启用 → $GIT_REPO_URL"

    if [[ $GIT_REPO_URL == https://github.com/* ]]; then
        AUTH_URL="https://${GIT_TOKEN}@${GIT_REPO_URL#https://}"
    else
        AUTH_URL=$GIT_REPO_URL
    fi

    # Git 操作全部放在子shell中，避免影响主进程目录
    (
        cd /data
        if [ ! -d ".git" ]; then
            echo "首次克隆仓库..."
            git clone --depth 1 "$AUTH_URL" . 2>/dev/null || {
                echo "仓库为空，初始化新仓库..."
                git init -b ${GIT_BRANCH:-main}
                git remote add origin "$AUTH_URL"
                git commit --allow-empty -m "Initial commit"
                git push -u origin ${GIT_BRANCH:-main}
            }
        else
            echo "拉取最新云端数据..."
            git pull --rebase origin ${GIT_BRANCH:-main} || echo "拉取失败，使用本地数据"
        fi
    )

    echo "已启动后台自动同步（每 ${GIT_SYNC_INTERVAL:-60} 秒检查一次）..."
    (
        while true; do
            sleep ${GIT_SYNC_INTERVAL:-60}
            /sync.sh
        done
    ) &
else
    echo "未配置 GIT_REPO_URL 或 GIT_TOKEN，仅本地保存"
fi

echo "启动 Proxy Checker..."
cd /app
exec python server.py
