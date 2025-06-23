#!/bin/bash

# Post-create script for GitHub Codespaces
# This runs after the container is created

echo "🚀 Setting up TotalSegmentator CoreML Converter Codespace..."

# Create necessary directories
mkdir -p /workspace/models
mkdir -p /workspace/notebooks
mkdir -p /workspace/scripts
mkdir -p /workspace/temp

# Copy conversion scripts if they exist
if [ -d "/workspace/docker" ]; then
    cp /workspace/docker/*.py /workspace/scripts/ 2>/dev/null || true
fi

# Install any additional tools
echo "📦 Installing additional tools..."
pip install --user poetry pre-commit

# Set up Jupyter kernel
python -m ipykernel install --user --name totalsegmentator --display-name "TotalSegmentator"

# Create a simple test script
cat > /workspace/test_environment.py << 'EOF'
#!/usr/bin/env python3
"""Test script to verify environment setup"""

import sys
print(f"Python: {sys.version}")

try:
    import torch
    print(f"✅ PyTorch: {torch.__version__}")
except ImportError:
    print("❌ PyTorch not found")

try:
    import coremltools as ct
    print(f"✅ CoreMLTools: {ct.__version__}")
except ImportError:
    print("❌ CoreMLTools not found")

try:
    import numpy as np
    print(f"✅ NumPy: {np.__version__}")
except ImportError:
    print("❌ NumPy not found")

try:
    import nibabel
    print(f"✅ NiBabel: {nibabel.__version__}")
except ImportError:
    print("❌ NiBabel not found")

print("\n🎉 Environment test complete!")
EOF

chmod +x /workspace/test_environment.py

# Create README for Codespace
cat > /workspace/CODESPACE_README.md << 'EOF'
# TotalSegmentator CoreML Converter - GitHub Codespace

Welcome to your TotalSegmentator conversion environment!

## Quick Start

### 1. Test Environment
```bash
python test_environment.py
```

### 2. Run Conversion Script
```bash
python scripts/convert_full_model.py
```

### 3. Run Jupyter Notebook
```bash
jupyter lab --ip=0.0.0.0 --no-browser
```
Then open the forwarded port in your browser.

### 4. Use Docker for Isolated Conversion
```bash
cd docker
./run_conversion.sh
```

## Available Scripts

- `scripts/convert_full_model.py` - Full model conversion
- `scripts/convert_simplified.py` - Simplified model for testing
- `notebooks/TotalSegmentator_Colab_Final.ipynb` - Jupyter notebook

## Model Output

All converted models will be saved to `/workspace/models/`

## Tips

- Use `Ctrl+Shift+P` → "Forward a Port" to access Jupyter
- The environment has all dependencies pre-installed
- GPU is not available in Codespaces, using CPU-only PyTorch

EOF

echo "✅ Codespace setup complete!"
echo ""
echo "Run 'python test_environment.py' to verify your setup"