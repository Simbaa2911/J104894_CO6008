########################################
# 1 – build stage
########################################
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

# RDKit needs a few X libraries for SVG
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
# 2 – runtime stage
########################################
FROM python:3.10-slim AS final

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

# tiny Nginx + envsubst + same X libs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# ----- code, data, front-end -----
COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data

# copy the entire front-end bundle
COPY frontend/. /usr/share/nginx/html/

# guarantee the launch page sits at the web-root
# (over-writes anything the previous COPY might have placed there)
COPY frontend/index.html /usr/share/nginx/html/index.html

# Nginx config + entrypoint
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
