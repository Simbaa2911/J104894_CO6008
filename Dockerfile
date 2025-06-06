# Use an official Python 3.10 image
FROM python:3.10-slim

# Install system dependencies for RDKit
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install RDKit via wheels from conda-forge (no conda needed)
RUN pip install numpy
RUN pip install rdkit-pypi

# Set the working directory
WORKDIR /app

# Copy requirements and install everything else
COPY requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt

# Copy the app
COPY . /app

# Expose port (Railway expects $PORT to be respected)
EXPOSE 8000

# Run the app
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
