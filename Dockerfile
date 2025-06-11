########################################
# ---------- 1. build stage ---------- #
########################################
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# OS libs rdkit needs to render SVGs
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
# ---------- 2. runtime stage -------- #
########################################
FROM python:3.10-slim AS final

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Nginx + minimal X libs rdkit needs + envsubst
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python deps (wheel cache reused → quick)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# code, data, frontend bundle
COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data
COPY frontend /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ------- entry point (one line, no quoting pain) -------
CMD ["/start.sh"]
