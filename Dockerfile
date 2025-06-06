# Use an official slim Python image
FROM python:3.10-slim

# Install build dependencies
RUN apt-get update && apt-get install -y build-essential

# Install RDKit via pip (no conda)
RUN pip install rdkit-pypi

# Install other dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Install uvicorn globally
RUN pip install uvicorn

# Set working directory
WORKDIR /app

# Copy the app
COPY . /app

# Expose the port (8000)
EXPOSE 8000

# Run the app (using uvicorn)
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
