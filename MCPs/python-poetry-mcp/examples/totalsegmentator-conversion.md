# TotalSegmentator to CoreML Conversion Example

This example shows how to use the Python Poetry MCP to properly manage dependencies for the TotalSegmentator to CoreML conversion project.

## Step 1: Create the Project

```bash
# Using the MCP in Claude
await mcp.call("poetry_create_project", {
  name: "totalsegmentator-coreml",
  path: "/path/to/project",
  python_version: "3.11",
  description: "Convert TotalSegmentator models to CoreML format",
  author: "Your Name <your.email@example.com>",
  dependencies: {
    numpy: "^1.24.0,<2.0.0",
    pillow: "^10.0.0",
    tqdm: "^4.65.0"
  }
});
```

## Step 2: Set Up ML Dependencies with Proper Versions

```bash
# Add PyTorch 2.1.2 (minimum for TotalSegmentator)
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  dependency: "torch==2.1.2",
  group: "main",
  source: "pytorch",
  extras: ["cpu"]  # or ["cuda11.8"] for GPU
});

# Add CoreMLTools 8.0+ (compatible with PyTorch 2.1+)
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  dependency: "coremltools>=8.0",
  group: "main"
});

# Add TotalSegmentator
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  dependency: "totalsegmentator>=2.0.0",
  group: "main"
});
```

## Step 3: Add PyTorch Source

```bash
# Add PyTorch repository for proper package resolution
await mcp.call("poetry_source", {
  projectPath: "/path/to/project",
  action: "add",
  name: "pytorch",
  url: "https://download.pytorch.org/whl/cpu",
  priority: "supplemental"
});
```

## Step 4: Check for Conflicts

```bash
# Verify no dependency conflicts
await mcp.call("poetry_check_conflicts", {
  projectPath: "/path/to/project",
  fix: true
});
```

## Step 5: Create Virtual Environment and Install

```bash
# Install all dependencies
await mcp.call("poetry_install", {
  projectPath: "/path/to/project",
  noDev: false,
  sync: true,
  verbose: true
});
```

## Step 6: Export Requirements (if needed)

```bash
# Export to requirements.txt for other tools
await mcp.call("poetry_export_requirements", {
  projectPath: "/path/to/project",
  outputFile: "requirements.txt",
  includeDev: false,
  withHashes: false
});
```

## Step 7: Run Conversion Script

```bash
# Run your conversion script in the Poetry environment
await mcp.call("poetry_run", {
  projectPath: "/path/to/project",
  command: "python convert_to_coreml.py"
});
```

## Complete pyproject.toml Example

After running the above commands, your `pyproject.toml` should look like:

```toml
[tool.poetry]
name = "totalsegmentator-coreml"
version = "0.1.0"
description = "Convert TotalSegmentator models to CoreML format"
authors = ["Your Name <your.email@example.com>"]
python = "^3.11"

[tool.poetry.dependencies]
python = "^3.11"
numpy = "^1.24.0,<2.0.0"
pillow = "^10.0.0"
tqdm = "^4.65.0"
torch = {version = "2.1.2", source = "pytorch"}
coremltools = "^8.0"
totalsegmentator = "^2.0.0"
nibabel = "^5.0.0"
scikit-image = "^0.21.0"
matplotlib = "^3.7.0"
pandas = "^2.0.0"

[tool.poetry.group.dev.dependencies]
jupyter = "^1.0.0"
pytest = "^7.3.0"
black = "^23.3.0"
ruff = "^0.0.270"

[[tool.poetry.source]]
name = "pytorch"
url = "https://download.pytorch.org/whl/cpu"
priority = "supplemental"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
```

## Benefits of Using Poetry for This Project

1. **Dependency Resolution**: Poetry automatically resolves the complex dependency tree between TotalSegmentator, PyTorch, and CoreMLTools
2. **Lock File**: Creates a `poetry.lock` file ensuring reproducible builds
3. **Virtual Environment**: Isolates project dependencies from system Python
4. **Version Constraints**: Properly handles version constraints like numpy<2.0.0 (required by many ML libraries)
5. **PyPI Sources**: Can add custom sources like PyTorch's wheel repository

## Troubleshooting Common Issues

### Issue: CUDA/CPU PyTorch Variants
```bash
# For CPU-only (smaller download):
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  dependency: "torch==2.1.2+cpu",
  source: "pytorch"
});

# For CUDA 11.8:
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  dependency: "torch==2.1.2+cu118",
  source: "pytorch"
});
```

### Issue: Dependency Conflicts
```bash
# Show dependency tree to understand conflicts
await mcp.call("poetry_dependency_tree", {
  projectPath: "/path/to/project",
  package: "torch"
});
```

### Issue: CoreMLTools Compatibility
```bash
# If CoreMLTools 8.0 has issues, try the latest:
await mcp.call("poetry_update_dependency", {
  projectPath: "/path/to/project",
  dependency: "coremltools",
  strategy: "latest"
});
```

## Running the Conversion

Create a `convert_to_coreml.py` script in your project:

```python
import torch
import coremltools as ct
from totalsegmentator.python_api import totalsegmentator

def convert_model():
    # Load TotalSegmentator model
    model = load_totalsegmentator_model()
    
    # Convert to CoreML
    example_input = torch.randn(1, 1, 128, 128, 128)
    
    model = ct.convert(
        model,
        inputs=[ct.TensorType(shape=example_input.shape)],
        minimum_deployment_target=ct.target.iOS18,
        compute_units=ct.ComputeUnit.ALL
    )
    
    # Save model
    model.save("TotalSegmentator.mlpackage")

if __name__ == "__main__":
    convert_model()
```

Then run:
```bash
await mcp.call("poetry_run", {
  projectPath: "/path/to/project",
  command: "python convert_to_coreml.py"
});
```

This approach ensures all dependencies are properly managed and conflicts are resolved automatically by Poetry.