# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip
RUN pip install --upgrade pip

# Install dependencies in correct order
# First, install numpy with specific version
RUN pip install numpy==1.24.3

# Install PyTorch CPU version
RUN pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu

# Install CoreMLTools
RUN pip install coremltools==7.2

# Install other dependencies
RUN pip install \
    scipy==1.10.1 \
    scikit-image==0.21.0 \
    nibabel==5.2.0 \
    SimpleITK==2.3.1 \
    matplotlib==3.7.2 \
    tqdm==4.66.1 \
    pandas==2.0.3 \
    pydicom==2.4.3 \
    dicom2nifti==2.4.8

# Install nnUNet and TotalSegmentator without dependencies
RUN pip install batchgenerators==0.25
RUN pip install nnunetv2==2.2.1 --no-deps
RUN pip install totalsegmentator==2.2.1 --no-deps

# Copy conversion scripts
COPY convert_model.py /app/
COPY requirements.txt /app/

# Create output directory
RUN mkdir -p /app/models

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=""

# Default command
CMD ["python", "convert_model.py"]