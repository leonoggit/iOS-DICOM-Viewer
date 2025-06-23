#!/bin/bash

# Post-create script for iOS DICOM Viewer Codespace
echo "🚀 Setting up iOS DICOM Viewer Development Environment"
echo "====================================================="

# Navigate to TotalSegmentator directory
cd /workspaces/iOS-DICOM-Viewer/MCPs/totalsegmentator-coreml-mcp

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p models notebooks/outputs logs

# Create a test script to verify environment
cat > test_setup.py << 'EOF'
#!/usr/bin/env python3
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

print("\n🎉 Setup verification complete!")
EOF

chmod +x test_setup.py

# Run the test
echo ""
echo "🧪 Testing environment..."
python test_setup.py

echo ""
echo "====================================================="
echo "✅ Codespace setup complete!"
echo ""
echo "To convert TotalSegmentator to CoreML:"
echo "  cd MCPs/totalsegmentator-coreml-mcp"
echo "  python scripts/convert_full_model.py"
echo ""
echo "To run a notebook:"
echo "  cd MCPs/totalsegmentator-coreml-mcp/notebooks"
echo "  jupyter lab"
echo "====================================================="