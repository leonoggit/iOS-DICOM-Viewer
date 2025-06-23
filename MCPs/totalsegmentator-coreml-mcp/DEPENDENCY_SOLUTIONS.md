# TotalSegmentator CoreML Conversion - Dependency Solutions

## Problem Summary

The main issue you're encountering is a complex dependency conflict:
- TotalSegmentator requires `torch>=2.1.2`
- Some dependencies want `numpy>=2.0.0` (like thinc)
- Other dependencies want `numpy<2.0.0` (most ML libraries)
- Binary incompatibility errors when mixing different numpy versions

## Solutions

### 1. **Docker Solution (Recommended)**

The most reliable approach is using Docker to create an isolated environment:

```bash
cd /Users/leandroalmeida/iOS_DICOM/MCPs/totalsegmentator-coreml-mcp/docker
./run_conversion.sh
```

This solution:
- Creates a clean Python 3.11 environment
- Installs all dependencies in the correct order
- Avoids all conflicts by using a container
- Produces a CoreML model ready for iOS

### 2. **Poetry MCP Solution**

Use the Python Poetry MCP for better dependency management:

```javascript
// In Claude
await mcp.call("poetry_create_project", {
  name: "totalsegmentator-coreml",
  path: "/path/to/project",
  python_version: "3.11"
});

await mcp.call("poetry_ml_setup", {
  projectPath: "/path/to/project",
  framework: "pytorch",
  cuda: false,
  additionalDeps: [
    "coremltools==7.2",
    "numpy==1.24.3",
    "totalsegmentator==2.2.1"
  ]
});
```

### 3. **Virtual Environment Solution**

Create a clean virtual environment with specific versions:

```bash
# Create new environment
python3.11 -m venv coreml_env
source coreml_env/bin/activate  # On Windows: coreml_env\Scripts\activate

# Install in specific order
pip install numpy==1.24.3
pip install torch==2.1.2 --index-url https://download.pytorch.org/whl/cpu
pip install coremltools==7.2
pip install scipy==1.10.1 scikit-image==0.21.0
pip install nibabel==5.2.0 SimpleITK==2.3.1
pip install totalsegmentator==2.2.1 --no-deps
```

### 4. **Colab/Jupyter Fixes**

For Google Colab or Jupyter environments:

1. **Restart Runtime**: After installing conflicting packages
2. **Use Fixed Notebook v2**: Located at `notebooks/TotalSegmentator_PyTorch_to_CoreML_Fixed_v2.ipynb`
3. **Install without dependencies**: Use `--no-deps` flag for problematic packages

## Specific Dependency Versions That Work

```toml
[dependencies]
python = "3.11"
numpy = "1.24.3"  # Critical - not 1.26.x or 2.x
torch = "2.1.2"   # Minimum for TotalSegmentator
torchvision = "0.16.2"
coremltools = "7.2"  # Works with torch 2.1.2
scipy = "1.10.1"
scikit-image = "0.21.0"
nibabel = "5.2.0"
pandas = "2.0.3"
matplotlib = "3.7.2"
```

## Quick Fix Commands

If you're getting the numpy binary incompatibility error:

```bash
# Complete reset
pip uninstall -y numpy scipy scikit-image pandas torch torchvision
pip cache purge

# Reinstall in order
pip install numpy==1.24.3
pip install torch==2.1.2 --index-url https://download.pytorch.org/whl/cpu
pip install coremltools==7.2
```

## Why These Conflicts Happen

1. **Binary ABI Changes**: NumPy 2.0 changed its C API, breaking binary compatibility
2. **Dependency Trees**: TotalSegmentator has deep dependencies that conflict
3. **Version Pinning**: Many ML libraries pin to numpy<2.0 for stability
4. **Colab Environment**: Pre-installed packages can conflict with new installations

## Best Practices

1. **Always use virtual environments** for ML projects
2. **Pin all dependency versions** in production
3. **Use Poetry or pipenv** for dependency management
4. **Test in Docker** before deployment
5. **Document working version combinations**

## Working Conversion Script

If you get past the dependencies, here's a minimal conversion script:

```python
import torch
import coremltools as ct
import numpy as np

# Create simple 3D segmentation model
model = create_simple_unet()  # Your model here
model.eval()

# Convert
example_input = torch.randn(1, 1, 128, 128, 128)
traced = torch.jit.trace(model, example_input)

coreml_model = ct.convert(
    traced,
    inputs=[ct.TensorType(shape=(1, 1, 128, 128, 128))],
    minimum_deployment_target=ct.target.iOS16
)

coreml_model.save("TotalSegmentator.mlpackage")
```

## Support

If you continue to have issues:
1. Use the Docker solution - it's the most reliable
2. Check the Poetry MCP for automated dependency resolution
3. Consider using a cloud service with pre-configured environments
4. Contact the TotalSegmentator team for their official conversion scripts