########################################
# -------- 1. build / prepare -------- #
########################################
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential libxrender1 libxext6 libsm6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

COPY . .
RUN mkdir -p /drugbank_data && cp -r drugbank_data/* /drugbank_data/


########################################
# -------- 2. runtime image ---------- #
########################################
FROM python:3.10-slim AS final

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data
COPY frontend /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# For local runs:  docker run -p 8080:8080 -e PORT=8080 …
ENV PORT=8080

# ---------- start everything ----------
#CMD ["sh","-c","envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && uvicorn backend.app:app --host 127.0.0.1 --port 8000 & nginx -g 'daemon off;'"]
CMD ["sh","-c",
     "set -e ; \
      envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf ; \
      echo '----- generated nginx.conf -----' ; \
      cat /etc/nginx/nginx.conf ; \
      echo '--------------------------------' ; \
      echo 'Running:  nginx -t' ; \
      nginx -t ; \
      echo 'Config OK, starting services…' ; \
      uvicorn backend.app:app --host 127.0.0.1 --port 8000 & \
      nginx -g 'daemon off;'"
]