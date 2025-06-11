########################################
# 1 – BUILD STAGE
########################################
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ─── system libs RDKit needs for SVG ─────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# project code + data
COPY . .
RUN mkdir -p /drugbank_data && cp -r drugbank_data/* /drugbank_data


########################################
# 2 – RUNTIME STAGE
########################################
FROM python:3.10-slim AS final

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ─── Nginx + minimal X libs ─────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base && \
    rm -rf /var/lib/apt/lists/*

# remove only default vhost fragments (leave mime.types)
RUN rm -rf /etc/nginx/conf.d /etc/nginx/sites-enabled

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# backend code + data
COPY --from=backend /app            /app
COPY --from=backend /drugbank_data  /drugbank_data

# ─── front-end bundle ───────────────────────────────────
COPY frontend/            /usr/share/nginx/html/
COPY frontend/index.html  /usr/share/nginx/html/index.html

# ─── final Nginx config + entrypoint ────────────────────
COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh    /start.sh
RUN chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
