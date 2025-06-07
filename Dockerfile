# Use an official slim Python image
FROM python:3.10-slim

# Install build dependencies and X11 libraries required by RDKit
RUN apt-get update && apt-get install -y \
    build-essential \
    libxrender1 \
    libxext6 \
    libsm6

# Install RDKit via pip (no conda)
RUN pip install rdkit-pypi

# Install other dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Install uvicorn globally
RUN pip install uvicorn

# Set working directory
WORKDIR /app

# Copy the app code
COPY . /app

# Copy the drugbank_data folder
COPY drugbank_data /app/drugbank_data

# Expose the port (8000)
EXPOSE 8000

# Run the app (using uvicorn)
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
