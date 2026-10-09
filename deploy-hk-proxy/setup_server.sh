#!/bin/bash
# ============================================================
# Supabase 香港中转代理 - 服务器一键安装脚本
# 用法: 在香港服务器上执行  sudo bash setup_server.sh sb.你的域名.com
# 适用: Ubuntu 22.04 / 24.04
# 功能: 安装 nginx + certbot，配置反代 Supabase（含 Realtime WebSocket），
#       自动签发 Let's Encrypt HTTPS 证书
# ============================================================
set -e

# ⚠️ 改成你的 Supabase 项目地址（当前生产项目）
SUPABASE_HOST="zzuwpanihewhqtyywhny.supabase.co"
# 证书通知邮箱
EMAIL="450106595@qq.com"

DOMAIN=$1
if [ -z "$DOMAIN" ]; then
  echo "用法: sudo bash setup_server.sh sb.你的域名.com"
  exit 1
fi

echo "==> [1/4] 安装 nginx 和 certbot..."
apt update -y
apt install -y nginx certbot python3-certbot-nginx

echo "==> [2/4] 写入 nginx 反代配置..."
cat > /etc/nginx/sites-available/supabase-proxy <<EOF
# WebSocket 升级映射（Realtime 实时比分必需）
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass https://${SUPABASE_HOST};
        proxy_http_version 1.1;

        # 关键：Host 必须是 Supabase 原域名，否则 Supabase 不路由
        proxy_set_header Host ${SUPABASE_HOST};
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        # 需要 SNI 才能与 Supabase (AWS) 建立 TLS
        proxy_ssl_server_name on;
        proxy_ssl_name ${SUPABASE_HOST};

        # Realtime WebSocket 长连接 + 慢网络容错
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/supabase-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo "==> [3/4] 签发 HTTPS 证书（前提: 域名已解析到本机 IP）..."
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL}" --redirect

echo "==> [4/4] 验证..."
sleep 2
CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/rest/v1/")
echo "测试 https://${DOMAIN}/rest/v1/ 返回: HTTP ${CODE} (401 即为正常，说明代理已通)"
echo ""
echo "✅ 全部完成！把域名告诉 AI，改前端环境变量即可切换。"
