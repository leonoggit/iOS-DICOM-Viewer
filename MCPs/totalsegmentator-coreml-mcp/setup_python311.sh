#!/bin/bash

# Setup Python 3.11 environment for compatibility
echo "🐍 Setting up Python 3.11 environment for TotalSegmentator CoreML"
echo "================================================================"

# Check if pyenv is available
if command -v pyenv &> /dev/null; then
    echo "✅ pyenv found, installing Python 3.11..."
    pyenv install 3.11.8 -s
    pyenv local 3.11.8
    python_cmd="python"
else
    # Try to use python3.11 if available
    if command -v python3.11 &> /dev/null; then
        echo "✅ Python 3.11 found"
        python_cmd="python3.11"
    else
        echo "⚠️  Python 3.11 not found. Trying with system Python..."
        python_cmd="python3"
    fi
fi

# Create virtual environment with Python 3.11
echo ""
echo "📦 Creating virtual environment..."
$python_cmd -m venv venv311

# Activate it
source venv311/bin/activate

# Show Python version
echo ""
echo "🐍 Python version:"
python --version

# Upgrade pip
echo ""
echo "📦 Upgrading pip..."
python -m pip install --upgrade pip setuptools wheel

# Install packages that work with available versions
echo ""
echo "📦 Installing compatible packages..."

# Core packages
pip install numpy==1.26.4  # Latest numpy that works
pip install torch==2.2.0 torchvision==0.17.0 --index-url https://download.pytorch.org/whl/cpu  # Available version
pip install coremltools==7.2

# Scientific packages - use latest compatible versions
pip install scipy scikit-image nibabel matplotlib tqdm pandas
pip install pydicom dicom2nifti

echo ""
echo "✅ Environment setup complete!"
echo ""
echo "To use this environment:"
echo "  source venv311/bin/activate"
echo "  python scripts/convert_full_model.py"