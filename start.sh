#!/usr/bin/env sh
set -e

export PORT="${PORT:-8080}"
# 1) Render nginx.conf
envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# 2) Start Uvicorn in the background
uvicorn backend.app:app --host 127.0.0.1 --port 8000 &

# 3) Start Nginx in the foreground
exec nginx -g 'daemon off;'
