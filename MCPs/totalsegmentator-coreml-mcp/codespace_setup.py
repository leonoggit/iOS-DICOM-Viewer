#!/usr/bin/env python3
"""
Setup script that works with Python 3.12 in GitHub Codespaces
Uses available package versions
"""

import subprocess
import sys
import os

print("🚀 TotalSegmentator CoreML Setup for Python 3.12")
print("=" * 50)
print(f"Python version: {sys.version}")
print("=" * 50)

def install_package(package_spec):
    """Install a package and return success status"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package_spec])
        return True
    except subprocess.CalledProcessError:
        return False

# Upgrade pip first
print("\n📦 Upgrading pip...")
subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])

# Install packages with Python 3.12 compatible versions
packages = [
    # NumPy - use latest version that works with Python 3.12
    ("numpy", "Installing NumPy (latest)"),
    
    # PyTorch - use CPU version that's available for Python 3.12
    ("torch --index-url https://download.pytorch.org/whl/cpu", "Installing PyTorch (CPU)"),
    ("torchvision --index-url https://download.pytorch.org/whl/cpu", "Installing TorchVision"),
    
    # CoreMLTools - already installed successfully
    ("coremltools==7.2", "Installing CoreMLTools"),
    
    # Scientific packages - use latest compatible versions
    ("scipy", "Installing SciPy (latest)"),
    ("scikit-image", "Installing scikit-image (latest)"),
    ("nibabel", "Installing NiBabel"),
    ("matplotlib", "Installing Matplotlib"),
    ("tqdm", "Installing tqdm"),
    ("pandas", "Installing Pandas"),
    
    # Medical imaging
    ("pydicom", "Installing PyDICOM"),
    ("SimpleITK", "Installing SimpleITK"),
]

failed = []
for package, description in packages:
    print(f"\n📦 {description}...")
    if not install_package(package):
        failed.append(package)
        print(f"   ⚠️  Failed to install {package}")

# Create necessary directories
print("\n📁 Creating directories...")
os.makedirs("models", exist_ok=True)
os.makedirs("logs", exist_ok=True)

# Test installation
print("\n🧪 Testing installation...")
test_passed = True

try:
    import torch
    print(f"✅ PyTorch: {torch.__version__}")
except ImportError as e:
    print(f"❌ PyTorch import failed: {e}")
    test_passed = False

try:
    import coremltools as ct
    print(f"✅ CoreMLTools: {ct.__version__}")
except ImportError as e:
    print(f"❌ CoreMLTools import failed: {e}")
    test_passed = False

try:
    import numpy as np
    print(f"✅ NumPy: {np.__version__}")
except ImportError as e:
    print(f"❌ NumPy import failed: {e}")
    test_passed = False

if test_passed and not failed:
    print("\n✅ Setup complete! You can now run:")
    print("   python scripts/convert_full_model.py")
else:
    print("\n⚠️  Some packages failed to install.")
    print("You may need to adjust package versions or use Docker.")

# Create a simplified conversion script that works with available packages
simplified_script = '''#!/usr/bin/env python3
"""Simplified conversion script for Python 3.12 compatibility"""

import torch
import torch.nn as nn
import numpy as np
import coremltools as ct
from pathlib import Path
import json

# Simple 3D UNet model
class SimpleUNet3D(nn.Module):
    def __init__(self, in_channels=1, out_channels=104):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Conv3d(in_channels, 32, 3, padding=1),
            nn.ReLU(),
            nn.Conv3d(32, 64, 3, padding=1),
            nn.ReLU(),
            nn.MaxPool3d(2)
        )
        self.decoder = nn.Sequential(
            nn.ConvTranspose3d(64, 32, 2, stride=2),
            nn.ReLU(),
            nn.Conv3d(32, out_channels, 1)
        )
    
    def forward(self, x):
        x = self.encoder(x)
        x = self.decoder(x)
        return x

print("Creating simplified TotalSegmentator model...")
model = SimpleUNet3D()
model.eval()

# Create example input
input_shape = (1, 1, 64, 64, 64)
example_input = torch.randn(input_shape)

# Trace model
traced_model = torch.jit.trace(model, example_input)

# Convert to CoreML
print("Converting to CoreML...")
ml_model = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="ct_scan", shape=input_shape)],
    minimum_deployment_target=ct.target.iOS15
)

# Save model
output_dir = Path("models")
output_dir.mkdir(exist_ok=True)
model_path = output_dir / "TotalSegmentator_Simple.mlmodel"
ml_model.save(str(model_path))

print(f"✅ Model saved to: {model_path}")
'''

with open("convert_simple.py", "w") as f:
    f.write(simplified_script)

print("\n📝 Created simplified conversion script: convert_simple.py")
print("   Run it with: python convert_simple.py")