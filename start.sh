#!/usr/bin/env sh
set -e

# 1 – Default to 80; honour Railway’s $PORT if it’s set manually
export PORT="${PORT:-80}"
echo "Container booting; PORT=$PORT"

# 2 – Render template
envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# 3 – Config sanity-check (prints error + exits 1 if bad)
nginx -t

# 4 – Start Uvicorn (bind on all interfaces!)
uvicorn backend.app:app \
       --host 0.0.0.0 \
       --port 8000 \
       --log-level debug \
       --access-log &        # shows each request

# 5 – Foreground Nginx
echo "Contents of /usr/share/nginx/html:"
find /usr/share/nginx/html -maxdepth 2 -type f | sed 's/^/   /'
exec nginx -g 'daemon off;'
