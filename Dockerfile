# Use Miniconda as the base image
FROM continuumio/miniconda3

# Create a new conda environment named "dti-env" with Python 3.10
RUN conda create -n dti-env python=3.10 -y

# Activate the environment
SHELL ["conda", "run", "-n", "dti-env", "/bin/bash", "-c"]

# Install RDKit inside conda
RUN conda install -c conda-forge rdkit -y

# Install additional dependencies inside conda
COPY requirements.txt /app/requirements.txt
WORKDIR /app
RUN conda run -n dti-env pip install -r requirements.txt
RUN conda run -n dti-env pip install uvicorn  # install uvicorn inside conda

# Copy the app code
COPY . /app

# Expose the port
ENV PORT=8000
EXPOSE $PORT

# Start the app using a shell so that the PORT variable is interpolated properly
CMD conda run -n dti-env bash -c "uvicorn backend.app:app --host 0.0.0.0 --port ${PORT:-8000}"
