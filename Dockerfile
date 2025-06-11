########################################
# 1 – BUILD STAGE
########################################
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

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

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base && \
    rm -rf /var/lib/apt/lists/*

RUN rm -f /etc/nginx/conf.d/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# code + data
COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data

# ─── FRONT-END ─────────────────────────────────────────────
COPY frontend/.          /usr/share/nginx/html/
COPY frontend/index.html /usr/share/nginx/html/index.html

# ─── Nginx & entrypoint ───────────────────────────────────
RUN rm -f /etc/nginx/nginx.conf.template        # ensure old file is gone
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
