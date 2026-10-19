#!/bin/bash
# ============================================================
# Supabase 香港中转代理 - 一键安装脚本 v2
# 用法: sudo bash setup_server_v2.sh sb.你的域名.com
# 适用: Ubuntu 22.04 / 24.04 / 26.04
# 内容: nginx 反代 Supabase（REST/Storage/Realtime WebSocket 全支持）
#       + Let's Encrypt 自动 HTTPS + 本地防火墙放行 + 代理自检
# ============================================================
set -e

SUPABASE_HOST="zzuwpanihewhqtyywhny.supabase.co"
SUPABASE_ANON_KEY="eyGrrNoqEbYZKkV9HtFcSlM0aBP5WbeZLEB1.piFhf9CrNvVdpHEqZxJtJMGcHyOaIpF3Ypr5jKyyCU1ffLM6tWH8lRp1qZ68Ebnkif0mYNW1ZwMtd60jBWEqTOMxYkA0Qck4YRs7QOyvBwJ8qFW4BkS1OrZ9IErzFX7.IWbNYYZbuPqi2spzofiRkSbrQaywiyuSN3EUwnBeSS2"
EMAIL="450106595@qq.com"

DOMAIN=$1
if [ -z "$DOMAIN" ]; then
  echo "用法: sudo bash setup_server_v2.sh sb.你的域名.com"
  exit 1
fi

echo "==> [0/6] 检查域名解析..."
SERVER_IP=$(curl -4 -s --max-time 8 https://ifconfig.me || curl -4 -s --max-time 8 https://api.ipify.org)
RESOLVED=$(getent hosts "$DOMAIN" | awk '{print $1}' | head -1)
echo "    本机公网 IP : ${SERVER_IP}"
echo "    域名解析到  : ${RESOLVED:-（未解析）}"
if [ -z "$RESOLVED" ]; then
  echo "❌ 域名未解析。请先到域名控制台添加 A 记录: ${DOMAIN%%.*} → ${SERVER_IP}，等 1~10 分钟生效后重跑。"
  exit 1
fi
if [ "$RESOLVED" != "$SERVER_IP" ]; then
  echo "⚠️  域名解析 IP 与本机不一致（可能刚改还没生效）。证书签发可能失败，可稍后重跑。"
fi

echo "==> [1/6] 安装 nginx 和 certbot..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx curl

echo "==> [2/6] 放行本地防火墙 80/443..."
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null
  echo "    ufw 已放行"
else
  echo "    ufw 未启用，跳过（腾讯云防火墙需在控制台放行 80/443）"
fi

echo "==> [3/6] 写入 nginx 反代配置..."
cat > /etc/nginx/conf.d/supabase-proxy.conf <<EOF
# WebSocket 升级映射（Realtime 实时比分必需）
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    # 头像等 Storage 上传（默认 1m 会 413）
    client_max_body_size 25m;

    location / {
        proxy_pass https://${SUPABASE_HOST};
        proxy_http_version 1.1;

        # 关键：Host 必须是 Supabase 原域名，否则 Supabase 不路由
        proxy_set_header Host ${SUPABASE_HOST};
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # 与 Supabase(AWS) 建 TLS 必须带 SNI
        proxy_ssl_server_name on;
        proxy_ssl_name ${SUPABASE_HOST};
        proxy_ssl_protocols TLSv1.2 TLSv1.3;

        # Realtime WebSocket 长连接 + 弱网容错
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_connect_timeout 10s;
        proxy_buffering off;

        # 大响应（Storage 文件下载）流式转发
        proxy_request_buffering off;
    }
}
EOF
nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx

echo "==> [4/6] 签发 HTTPS 证书 + 开启 HTTP/2..."
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL}" --redirect --hsts || {
  echo "❌ 证书签发失败（通常是 DNS 未生效/80 端口被墙）。修复后重跑: certbot --nginx -d ${DOMAIN}"
  exit 1
}

echo "==> [5/6] 代理链路自检..."
sleep 2
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${DOMAIN}/rest/v1/")
echo "    https://${DOMAIN}/rest/v1/            → HTTP ${CODE}（401/200 均正常）"

CODE2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 \
  -H "apikey: ${SUPABASE_ANON_KEY}" -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  "https://${DOMAIN}/rest/v1/games?select=id&limit=1")
echo "    带 apikey 查询 games 表                    → HTTP ${CODE2}（200 正常，401 说明 key 不匹配）"

CODE3=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${DOMAIN}/realtime/v1/")
echo "    https://${DOMAIN}/realtime/v1/        → HTTP ${CODE3}（401/426 都算通）"

echo "==> [6/6] 延迟对比（本机 → 代理 vs 本机 → Supabase 直连）..."
P=0; D=0
for i in 1 2 3; do
  T=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "https://${DOMAIN}/rest/v1/")
  P=$(awk "BEGIN{print $P+$T}")
  T=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "https://${SUPABASE_HOST}/rest/v1/")
  D=$(awk "BEGIN{print $D+$T}")
done
echo "    经中转平均: $(awk "BEGIN{printf \"%.3f\", $P/3}")s"
echo "    直连平均  : $(awk "BEGIN{printf \"%.3f\", $D/3}")s"

echo ""
echo "✅ 服务器端配置完成。域名: https://${DOMAIN}"
echo "   接下来: 在前端把 VITE_SUPABASE_URL 改成 https://${DOMAIN} 并重新部署。"
