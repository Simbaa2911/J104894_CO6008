########################################
# 1 – build stage
########################################
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

# System libs RDKit needs for 2-D SVGs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn          # rdkit wheel brings Pillow

# Code + data
COPY . .
RUN mkdir -p /drugbank_data && cp -r drugbank_data/* /drugbank_data


########################################
# 2 – runtime stage
########################################
FROM python:3.10-slim AS final

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

# Tiny Nginx layer + envsubst + the same X libs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data
#COPY frontend/. /usr/share/nginx/html/
#COPY frontend/index.html /usr/share/nginx/html/index.html
#COPY frontend/JSME_2024-04-29/index.html /usr/share/nginx/html/index.html
#COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY frontend/. /usr/share/nginx/html/
COPY frontend/index.html /usr/share/nginx/html/index.html
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80
# Railway’s default health-check target
CMD ["/start.sh"]
