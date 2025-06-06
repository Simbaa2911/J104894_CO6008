# Use Miniconda as the base image
FROM continuumio/miniconda3

# Create a new conda environment named "dti-env" with Python 3.10
RUN conda create -n dti-env python=3.10 -y

# Activate the environment
SHELL ["conda", "run", "-n", "dti-env", "/bin/bash", "-c"]

# Install RDKit via conda
RUN conda install -c conda-forge rdkit -y

# Set the working directory
WORKDIR /app

# Copy the project files into the container
COPY . /app

# Install Python dependencies from requirements.txt
RUN pip install -r requirements.txt

# Set the environment variable for the port
ENV PORT=8000

# Expose the port
EXPOSE $PORT

# Run the app
CMD ["conda", "run", "-n", "dti-env", "uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "$PORT"]
