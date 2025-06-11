#!/usr/bin/env sh
set -e

export PORT="${PORT:-80}"
echo "PORT inside container = $PORT"

# render template
envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# launch components
#uvicorn backend.app:app --host 127.0.0.1 --port 8000 &
uvicorn backend.app:app --host 127.0.0.1 --port 8000 \ --log-level debug &
exec nginx -g 'daemon off;'
