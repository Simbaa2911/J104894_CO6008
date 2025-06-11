#!/usr/bin/env sh
set -e

export PORT="${PORT:-80}"
echo "🚀  PORT=$PORT"

# render template
envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
nginx -t

# show files for debug
echo "── index files present:"
find /usr/share/nginx/html -maxdepth 2 -name 'index.html' -print | sed 's/^/   /'

# start backend
uvicorn backend.app:app \
       --host 0.0.0.0 \
       --port 8000 \
       --log-level info &

# start nginx
exec nginx -g 'daemon off;'
