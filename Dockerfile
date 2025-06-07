# Stage 1: Backend build
FROM python:3.10-slim AS backend

# Install dependencies
RUN apt-get update && \
    apt-get install -y build-essential libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

# Working directory
WORKDIR /app

# Copy and install dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
RUN pip install rdkit-pypi uvicorn

# Copy backend code
COPY . /app

# Copy drugbank_data folder
RUN mkdir -p /drugbank_data && \
    cp -r /app/drugbank_data/* /drugbank_data/

# Stage 2: Frontend + Nginx
FROM nginx:alpine

# Copy frontend files
COPY frontend /usr/share/nginx/html

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy backend files from build stage
COPY --from=backend /app /app
COPY --from=backend /drugbank_data /drugbank_data

# Expose ports
EXPOSE 80

# Start Uvicorn and Nginx together
CMD sh -c "uvicorn backend.app:app --host 0.0.0.0 --port 8000 & nginx -g 'daemon off;'"
