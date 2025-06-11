#!/usr/bin/env sh
set -e

# Railway sets no PORT for Docker images; default to 80
export PORT="${PORT:-80}"
echo "▶︎ Booting container — PORT=$PORT"

# Render nginx.conf with the actual port
envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Sanity-check config
nginx -t

# Start FastAPI (Uvicorn) in the background
uvicorn backend.app:app \
       --host 0.0.0.0 \
       --port 8000 \
       --log-level info &

# Show what reached the image (helps future debug)
echo "── /usr/share/nginx/html contains:"
find /usr/share/nginx/html -maxdepth 2 -name 'index.html' -print | sed 's/^/   /'

# Foreground Nginx
exec nginx -g 'daemon off;'
