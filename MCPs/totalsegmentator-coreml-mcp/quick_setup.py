#!/usr/bin/env python3
"""
Quick setup script for Python dependencies
Run this if setup_environment.sh doesn't work
"""

import subprocess
import sys
import os

def run_command(cmd, description):
    """Run a command and handle errors"""
    print(f"\n📦 {description}...")
    try:
        if isinstance(cmd, str):
            result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        else:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(f"✅ {description} - Success")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} - Failed")
        print(f"   Error: {e.stderr}")
        return False

def main():
    print("🚀 Quick Setup for TotalSegmentator CoreML Conversion")
    print("=" * 50)
    
    # Check Python version
    print(f"Python: {sys.version}")
    
    # Essential packages in order
    packages = [
        ("pip install --upgrade pip", "Upgrading pip"),
        ("pip install numpy==1.24.3", "Installing NumPy"),
        ("pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu", "Installing PyTorch"),
        ("pip install coremltools==7.2", "Installing CoreMLTools"),
        ("pip install scipy==1.10.1", "Installing SciPy"),
        ("pip install scikit-image==0.21.0", "Installing scikit-image"),
        ("pip install nibabel==5.2.0", "Installing NiBabel"),
        ("pip install matplotlib==3.7.2", "Installing Matplotlib"),
        ("pip install tqdm==4.66.1", "Installing tqdm"),
        ("pip install pandas==2.0.3", "Installing Pandas"),
    ]
    
    failed = []
    for cmd, desc in packages:
        if not run_command(cmd, desc):
            failed.append(desc)
    
    # Create directories
    print("\n📁 Creating directories...")
    os.makedirs("models", exist_ok=True)
    os.makedirs("notebooks/outputs", exist_ok=True)
    os.makedirs("logs", exist_ok=True)
    print("✅ Directories created")
    
    # Test installation
    print("\n🧪 Testing installation...")
    test_code = """
import torch
import coremltools as ct
import numpy as np
print(f'PyTorch: {torch.__version__}')
print(f'CoreMLTools: {ct.__version__}')
print(f'NumPy: {np.__version__}')
"""
    
    try:
        exec(test_code)
        print("\n✅ All packages installed successfully!")
    except ImportError as e:
        print(f"\n❌ Import error: {e}")
        print("Some packages failed to install properly")
    
    if failed:
        print(f"\n⚠️  The following installations failed:")
        for f in failed:
            print(f"   - {f}")
        print("\nTry running these commands manually or use Docker")
    else:
        print("\n🎉 Setup complete! You can now run:")
        print("   python scripts/convert_full_model.py")

if __name__ == "__main__":
    main()