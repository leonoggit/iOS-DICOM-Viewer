#!/usr/bin/env python3
"""
TotalSegmentator to CoreML Conversion Script
Run this in a clean virtual environment to avoid dependency conflicts.
"""

import subprocess
import sys
import os

def create_venv():
    """Create a clean virtual environment"""
    venv_name = "coreml_conversion_env"
    
    print(f"Creating virtual environment: {venv_name}")
    subprocess.run([sys.executable, "-m", "venv", venv_name])
    
    # Get pip path
    if os.name == "nt":  # Windows
        pip_path = os.path.join(venv_name, "Scripts", "pip")
        python_path = os.path.join(venv_name, "Scripts", "python")
    else:  # Unix/Linux/Mac
        pip_path = os.path.join(venv_name, "bin", "pip")
        python_path = os.path.join(venv_name, "bin", "python")
    
    return pip_path, python_path

def install_dependencies(pip_path):
    """Install dependencies in correct order"""
    deps = [
        "numpy==1.24.3",
        "torch==2.1.2 --index-url https://download.pytorch.org/whl/cpu",
        "coremltools==7.2",
        "nibabel==5.2.0",
        "scipy==1.10.1",
        "scikit-image==0.21.0",
    ]
    
    for dep in deps:
        print(f"Installing {dep}...")
        subprocess.run(f"{pip_path} install {dep}".split())

def main():
    pip_path, python_path = create_venv()
    install_dependencies(pip_path)
    
    print("
✅ Environment ready!")
    print(f"
To activate the environment:")
    if os.name == "nt":
        print(f"  .\\coreml_conversion_env\\Scripts\\activate")
    else:
        print(f"  source coreml_conversion_env/bin/activate")
    print(f"
Then run your conversion script with:")
    print(f"  python convert_totalsegmentator.py")

if __name__ == "__main__":
    main()
