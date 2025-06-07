# Backend build
FROM python:3.10-slim AS backend

# Install dependencies
RUN apt-get update && \
    apt-get install -y build-essential libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and install dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
RUN pip install rdkit-pypi uvicorn

COPY . /app

RUN mkdir -p /drugbank_data && \
    cp -r /app/drugbank_data/* /drugbank_data/

# Frontend + Nginx + Uvicorn
FROM python:3.10-slim AS final

# Install Nginx
RUN apt-get update && \
    apt-get install -y nginx libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

# Install uvicorn and rdkit
RUN pip install uvicorn rdkit-pypi

# Set working directory
WORKDIR /app

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy frontend
COPY frontend /usr/share/nginx/html

# Copy backend and data from build stage
COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data

# Expose ports
EXPOSE 80

# Start Uvicorn and Nginx
CMD sh -c "uvicorn backend.app:app --host 0.0.0.0 --port 8000 & nginx -g 'daemon off;'"
