# Use official Python 3.11 image
FROM python:3.11-slim-bullseye

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    vim \
    sudo \
    libgomp1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set working directory
WORKDIR /workspace

# Copy requirements first for better caching
COPY requirements-codespaces.txt /tmp/requirements.txt

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Pre-download PyTorch with CPU support to avoid issues
RUN pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu

# Install Jupyter and development tools
RUN pip install \
    jupyter \
    jupyterlab \
    ipykernel \
    ipywidgets \
    black \
    pylint \
    pytest

# Create directories
RUN mkdir -p /workspace/models /workspace/notebooks /workspace/scripts && \
    chown -R $USERNAME:$USERNAME /workspace

# Switch to non-root user
USER $USERNAME

# Set Python path
ENV PYTHONPATH=/workspace
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Default command
CMD ["bash"]