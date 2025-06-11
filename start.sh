#!/usr/bin/env sh
set -e

echo "🟢  starting backend & Nginx on port $PORT"

uvicorn backend.app:app --host 127.0.0.1 --port 8000 --log-level info &

envsubst '$PORT' < /etc/nginx/nginx.conf > /tmp/nginx.conf
mv /tmp/nginx.conf /etc/nginx/nginx.conf

exec nginx -g 'daemon off;'
