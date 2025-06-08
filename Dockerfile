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

# Copy entire source code including backend, drugbank_data, etc.
COPY . /app

# (Optional) Confirm directory structure (debugging only, can be removed)
RUN ls -R /app

# Frontend + Nginx + Uvicorn
FROM python:3.10-slim AS final

# Install Nginx and system dependencies
RUN apt-get update && \
    apt-get install -y nginx libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
RUN pip install rdkit-pypi uvicorn

# Set working directory
WORKDIR /app

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy frontend
COPY frontend /usr/share/nginx/html

# Copy backend and data from build stage
COPY --from=backend /app /app

# **Place drugbank_data in /app/drugbank_data to match local relative imports**
RUN mkdir -p /app/drugbank_data && \
    cp -r /app/drugbank_data/* /app/drugbank_data/

# Expose port 80
EXPOSE 80

# Start Uvicorn and Nginx
CMD sh -c "uvicorn backend.app:app --host 0.0.0.0 --port 8000 & nginx -g 'daemon off;'"
