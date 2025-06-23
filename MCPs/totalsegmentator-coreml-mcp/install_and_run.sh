#!/bin/bash

# One-command setup and run script for GitHub Codespaces
# This installs everything and runs the conversion

echo "🚀 TotalSegmentator CoreML Converter - Quick Start"
echo "=================================================="

# Install dependencies directly (no virtual environment for simplicity)
echo ""
echo "📦 Installing dependencies..."
pip install --upgrade pip

# Install in specific order to avoid conflicts
pip install numpy==1.24.3
pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu
pip install coremltools==7.2
pip install scipy==1.10.1 scikit-image==0.21.0 nibabel matplotlib tqdm pandas

# Create output directory
mkdir -p models

# Run the conversion
echo ""
echo "🔄 Running conversion..."
python scripts/convert_full_model.py --input-size 128

echo ""
echo "✅ Done! Check the 'models' directory for output files."