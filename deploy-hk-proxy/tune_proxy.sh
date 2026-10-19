#!/bin/bash
# 优化版反代配置：upstream 长连接池（消除每请求 TLS 握手）+ WebSocket 兼容
cat > /etc/nginx/conf.d/supabase-proxy.conf <<'EOF'
upstream supabase_backend {
    server zzuwpanihewhqtyywhny.supabase.co:443;
    keepalive 64;          # 长连接池：复用 TLS，省掉每请求握手
    keepalive_timeout 300s;
}

# WebSocket 升级映射：非升级请求用空 Connection（这样 keepalive 才生效）
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      '';
}

server {
    listen 80;
    listen [::]:80;
    server_name sb.119.28.32.62.sslip.io;

    client_max_body_size 25m;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name sb.119.28.32.62.sslip.io;

    ssl_certificate     /etc/letsencrypt/live/sb.119.28.32.62.sslip.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sb.119.28.32.62.sslip.io/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    client_max_body_size 25m;

    location / {
        proxy_pass https://supabase_backend;
        proxy_http_version 1.1;

        proxy_set_header Host zzuwpanihewhqtyywhny.supabase.co;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_ssl_server_name on;
        proxy_ssl_name zzuwpanihewhqtyywhny.supabase.co;
        proxy_ssl_protocols TLSv1.2 TLSv1.3;
        proxy_ssl_session_reuse on;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_connect_timeout 10s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF
nginx -t && systemctl reload nginx && echo "RELOADED"
echo "--- 服务器本地 5 次采样（经代理）---"
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w "  %{time_total}s\n" --max-time 15 \
    -H "apikey: $1" "https://sb.119.28.32.62.sslip.io/rest/v1/games?select=id&limit=1"
done
echo "--- WebSocket 握手测试（Realtime）---"
curl -s -o /dev/null -w "  握手 HTTP %{http_code}（101 即正常）\n" --max-time 10 -i -N \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  "https://sb.119.28.32.62.sslip.io/realtime/v1/websocket?apikey=$1&vsn=1.0.0" 2>/dev/null | tail -1
