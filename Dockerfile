FROM python:3.12-slim

# 安装 git
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    mkdir -p /data

# 默认环境变量
ENV PORT=8888 \
    AUTH_PASSWORD=linux.do \
    APP_TIMEZONE=Asia/Shanghai \
    GITHUB_BRANCH=main \
    GITHUB_SYNC_INTERVAL=180 \
    GITHUB_AUTO_PUSH=true

EXPOSE 8888
VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "server.py"]
