# ML Framework Examples

This document provides examples of using the Python Poetry MCP for different ML/AI frameworks.

## TensorFlow Projects

### Basic TensorFlow Setup

```typescript
// Create a TensorFlow project
await mcp.call("poetry_create_project", {
  name: "tensorflow-experiment",
  path: "/path/to/projects",
  python: "3.10"  // TensorFlow has specific Python version requirements
});

// Set up TensorFlow with CUDA support
await mcp.call("poetry_ml_setup", {
  projectPath: "/path/to/projects/tensorflow-experiment",
  framework: "tensorflow",
  cuda: true,
  extras: ["tensorflow-hub", "tensorflow-addons", "tensorflow-probability"]
});
```

### TensorFlow Project Structure

```
tensorflow-experiment/
├── pyproject.toml
├── README.md
├── src/
│   └── tensorflow_experiment/
│       ├── __init__.py
│       ├── models/
│       ├── data/
│       └── utils/
├── notebooks/
├── tests/
└── .gitignore
```

## PyTorch Projects

### PyTorch with Lightning

```typescript
// Create PyTorch project
await mcp.call("poetry_create_project", {
  name: "pytorch-vision",
  path: "/path/to/projects",
  python: "3.11",
  src: true
});

// Set up PyTorch with CUDA
await mcp.call("poetry_ml_setup", {
  projectPath: "/path/to/projects/pytorch-vision",
  framework: "pytorch",
  cuda: true
});

// Add PyTorch Lightning and vision libraries
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/pytorch-vision",
  packages: [
    "pytorch-lightning",
    "torchmetrics",
    "timm",  // PyTorch Image Models
    "albumentations",
    "segmentation-models-pytorch"
  ]
});
```

### PyTorch Development Dependencies

```typescript
// Add development tools
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/pytorch-vision",
  packages: [
    "wandb",  // Weights & Biases
    "tensorboard",
    "hydra-core",  // Configuration management
    "omegaconf",
    "rich"  // Beautiful terminal output
  ],
  group: "dev"
});
```

## JAX Projects

### JAX with Flax

```typescript
// Create JAX project
await mcp.call("poetry_create_project", {
  name: "jax-research",
  path: "/path/to/projects",
  python: "3.10"
});

// Set up JAX
await mcp.call("poetry_ml_setup", {
  projectPath: "/path/to/projects/jax-research",
  framework: "jax",
  cuda: true
});

// Add additional JAX ecosystem packages
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/jax-research",
  packages: [
    "dm-haiku",  // DeepMind's neural network library
    "rlax",  // Reinforcement learning
    "chex",  // Testing utilities
    "einops",  // Tensor operations
    "jaxtyping"  // Type annotations
  ]
});
```

## Transformers Projects

### Hugging Face Transformers

```typescript
// Create transformers project
await mcp.call("poetry_create_project", {
  name: "nlp-transformers",
  path: "/path/to/projects",
  python: "3.11"
});

// Set up transformers
await mcp.call("poetry_ml_setup", {
  projectPath: "/path/to/projects/nlp-transformers",
  framework: "transformers",
  cuda: true
});

// Add NLP-specific packages
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/nlp-transformers",
  packages: [
    "sentencepiece",
    "sacremoses",
    "rouge-score",
    "nltk",
    "spacy",
    "evaluate",  // Hugging Face evaluation library
    "peft"  // Parameter-efficient fine-tuning
  ]
});
```

## Multi-Framework Projects

### Research Project with Multiple Frameworks

```typescript
// Create research project
await mcp.call("poetry_create_project", {
  name: "ml-research",
  path: "/path/to/projects",
  python: "3.11",
  src: true
});

// Add multiple frameworks with dependency groups
// PyTorch group
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/ml-research",
  packages: ["torch", "torchvision", "pytorch-lightning"],
  group: "pytorch"
});

// TensorFlow group
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/ml-research",
  packages: ["tensorflow", "keras"],
  group: "tensorflow"
});

// JAX group
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/ml-research",
  packages: ["jax[cuda]", "flax", "optax"],
  group: "jax"
});

// Install specific groups
await mcp.call("poetry_install", {
  projectPath: "/path/to/projects/ml-research",
  groups: ["pytorch", "dev"]  // Only install PyTorch and dev deps
});
```

## Scikit-learn Projects

### Classical ML Pipeline

```typescript
// Create scikit-learn project
await mcp.call("poetry_create_project", {
  name: "ml-pipeline",
  path: "/path/to/projects",
  python: "3.11"
});

// Set up scikit-learn
await mcp.call("poetry_ml_setup", {
  projectPath: "/path/to/projects/ml-pipeline",
  framework: "scikit-learn"
});

// Add additional ML packages
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/projects/ml-pipeline",
  packages: [
    "xgboost",
    "lightgbm",
    "catboost",
    "imbalanced-learn",
    "feature-engine",
    "yellowbrick",  // ML visualizations
    "shap",  // Model interpretability
    "optuna"  // Hyperparameter optimization
  ]
});
```

## Computer Vision Projects

### Complete CV Setup

```typescript
// Set up computer vision project
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/cv-project",
  packages: [
    "opencv-python",
    "opencv-contrib-python",
    "scikit-image",
    "imageio",
    "imageio-ffmpeg",
    "kornia",  // PyTorch-based CV
    "detectron2",  // Facebook's detection library
    "mmcv-full",  // OpenMMLab computer vision
    "pytesseract"  // OCR
  ]
});
```

## Managing CUDA Dependencies

### Handling Different CUDA Versions

```typescript
// Add custom PyTorch index for specific CUDA version
await mcp.call("poetry_source", {
  projectPath: "/path/to/project",
  action: "add",
  name: "pytorch-cu118",
  url: "https://download.pytorch.org/whl/cu118",
  priority: "supplemental"
});

// Install PyTorch with specific CUDA
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  packages: ["torch", "torchvision", "torchaudio"],
  source: "pytorch-cu118"
});
```

## Dependency Conflict Resolution

### Example: Resolving TensorFlow/PyTorch Conflicts

```typescript
// Check current conflicts
const conflicts = await mcp.call("poetry_check_conflicts", {
  projectPath: "/path/to/project"
});

// View dependency tree to understand the issue
const tree = await mcp.call("poetry_dependency_tree", {
  projectPath: "/path/to/project",
  package: "numpy",  // Common conflict source
  depth: 2
});

// Update with constraints
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  packages: ["numpy>=1.21,<1.24"]  // Specify version range
});
```

## Production Deployment

### Preparing for Production

```typescript
// Export minimal requirements (no dev deps)
await mcp.call("poetry_export_requirements", {
  projectPath: "/path/to/project",
  output: "requirements-prod.txt",
  withDev: false,
  withoutHashes: true
});

// Export with specific extras for deployment
await mcp.call("poetry_export_requirements", {
  projectPath: "/path/to/project",
  output: "requirements-inference.txt",
  extras: ["inference"],  // Only inference dependencies
  withoutHashes: true
});
```

### Docker Integration

Create a `Dockerfile` for your ML project:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Copy only requirements first for better caching
COPY requirements-prod.txt .
RUN pip install --no-cache-dir -r requirements-prod.txt

# Copy project files
COPY src/ ./src/
COPY pyproject.toml .

# Install the project
RUN pip install --no-deps .

CMD ["python", "-m", "myproject.main"]
```