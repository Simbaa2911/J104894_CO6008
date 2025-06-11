#!/usr/bin/env sh
set -e

echo "🟢  starting backend & Nginx"

uvicorn backend.app:app --host 127.0.0.1 --port 8000 --log-level info &

exec nginx -g 'daemon off;'
