#!/usr/bin/env sh
set -e

# 1) Railway doesn’t pre-define PORT for Docker images.
export PORT="${PORT:-8080}"
echo "👋 Running with PORT=$PORT"

# 2) Render Nginx template
envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# 3) Sanity-check Nginx config (prints helpful errors then exits 0/1)
nginx -t

# 4) Start Uvicorn in background
uvicorn backend.app:app \
       --host 127.0.0.1 \
       --port 8000 \
       --log-level debug &

# 5) Start Nginx in foreground
exec nginx -g 'daemon off;'
