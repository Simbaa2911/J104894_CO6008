# -------- 1. build / prepare -------- #
FROM python:3.10-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# rdkit to render SVGs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential libxrender1 libxext6 libsm6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# project code + data
COPY . .
# lift the pre-computed drugbank data out so the runtime stage can copy it quickly
RUN mkdir -p /drugbank_data && cp -r drugbank_data/* /drugbank_data/



# -------- 2. runtime image ---------- #
FROM python:3.10-slim AS final

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# nginx + envsubst + rdkit SVG libs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx libxrender1 libxext6 libsm6 gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install rdkit-pypi uvicorn

# code, data, and frontend
COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data
COPY frontend /usr/share/nginx/html

# Copy nginx template
COPY nginx.conf /etc/nginx/nginx.conf.template

# For running locally: `docker run -p 8080:8080 -e PORT=8080 …`
ENV PORT=8080

# ---------- start everything ----------
# 1. render the template with the actual $PORT
# 2. launch Uvicorn on the private port 8000
# 3. start nginx in the foreground (keeps container alive)
CMD sh -c 'envsubst "$$PORT" < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && \
           uvicorn backend.app:app --host 0.0.0.0 --port 8000 & \
           nginx -g "daemon off;"'
