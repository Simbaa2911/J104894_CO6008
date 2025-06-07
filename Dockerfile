# Use a Python image
FROM python:3.10-slim

# Install build dependencies and required libraries
RUN apt-get update && \
    apt-get install -y build-essential libxrender1 libxext6 libsm6 && \
    rm -rf /var/lib/apt/lists/*

# Install RDKit via pip (no conda)
RUN pip install rdkit-pypi

# Install other dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Install uvicorn globally
RUN pip install uvicorn

# Set working directory
WORKDIR /app

# Copy the entire project
COPY . /app

#Copy drugbank_data folder
RUN mkdir -p /drugbank_data && \
    cp -r /app/drugbank_data/* /drugbank_data/

# Expose the port
EXPOSE 8000

# Run the app using uvicorn
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
