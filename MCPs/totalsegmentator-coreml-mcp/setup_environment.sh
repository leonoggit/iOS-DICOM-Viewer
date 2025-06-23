#!/bin/bash

# Setup script for TotalSegmentator CoreML conversion environment
# Run this first when using GitHub Codespaces or a fresh environment

echo "🚀 Setting up TotalSegmentator CoreML Conversion Environment"
echo "=========================================================="

# Check Python version
echo ""
echo "📍 Checking Python version..."
python --version

# Create virtual environment
echo ""
echo "📦 Creating virtual environment..."
if [ ! -d "venv" ]; then
    python -m venv venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo ""
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo ""
echo "📦 Upgrading pip..."
pip install --upgrade pip setuptools wheel

# Install core dependencies in correct order
echo ""
echo "📦 Installing core dependencies..."
echo "   Installing numpy first (to avoid conflicts)..."
pip install numpy==1.24.3

echo "   Installing PyTorch..."
pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu

echo "   Installing CoreMLTools..."
pip install coremltools==7.2

# Install other dependencies
echo ""
echo "📦 Installing additional dependencies..."
if [ -f "requirements-codespaces.txt" ]; then
    # Install without the already installed packages
    pip install scipy==1.10.1 scikit-image==0.21.0 scikit-learn==1.3.0
    pip install nibabel==5.2.0 SimpleITK==2.3.1 pydicom==2.4.3 dicom2nifti==2.4.8
    pip install pandas==2.0.3 matplotlib==3.7.2 tqdm==4.66.1
    pip install ipython jupyter jupyterlab
else
    echo "⚠️  requirements-codespaces.txt not found, installing minimal set"
fi

# Create necessary directories
echo ""
echo "📁 Creating output directories..."
mkdir -p models notebooks/outputs logs

# Test the environment
echo ""
echo "🧪 Testing environment..."
python -c "
import sys
print(f'Python: {sys.version.split()[0]}')
try:
    import torch
    print(f'✅ PyTorch: {torch.__version__}')
except ImportError:
    print('❌ PyTorch not installed')
try:
    import coremltools as ct
    print(f'✅ CoreMLTools: {ct.__version__}')
except ImportError:
    print('❌ CoreMLTools not installed')
try:
    import numpy as np
    print(f'✅ NumPy: {np.__version__}')
except ImportError:
    print('❌ NumPy not installed')
"

echo ""
echo "=========================================================="
echo "✅ Environment setup complete!"
echo ""
echo "To activate the environment in future sessions, run:"
echo "    source venv/bin/activate"
echo ""
echo "To run the conversion script:"
echo "    python scripts/convert_full_model.py"
echo ""
echo "To start Jupyter Lab:"
echo "    jupyter lab --ip=0.0.0.0 --no-browser"
echo "=========================================================="