########################################
# 1) build stage – install deps & copy code
########################################
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ─── OS libs RDKit needs for SVG drawing ──────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# project code + pre-computed data
COPY . .
RUN mkdir -p /drugbank_data && cp -r drugbank_data/* /drugbank_data/


########################################
# 2) runtime stage – really small image
########################################
FROM python:3.10-slim AS final

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ─── Nginx + RDKit’s minimal X libs + envsubst ───────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python wheels (wheel cache reused => fast)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# code, data, frontend bundle
COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data
COPY frontend /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# entrypoint script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose the port Railway will map (good practice)
EXPOSE 8080

CMD ["/start.sh"]
