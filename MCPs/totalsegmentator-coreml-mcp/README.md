# TotalSegmentator CoreML Conversion

This repository provides tools to convert TotalSegmentator models to CoreML format for iOS deployment.

## Quick Start

### Option 1: Google Colab (Easiest)
1. Open `notebooks/TotalSegmentator_Colab_Final.ipynb` in Google Colab
2. Run all cells
3. Download the generated models

### Option 2: GitHub Codespaces
1. Fork this repository
2. Click "Code" → "Codespaces" → "Create codespace on main"
3. Run: `python scripts/convert_full_model.py`

### Option 3: Local Docker
```bash
cd docker
./run_conversion.sh
```

## Repository Structure

```
totalsegmentator-coreml-mcp/
├── README.md                          # This file
├── CODESPACES_GUIDE.md               # GitHub Codespaces instructions
├── DEPENDENCY_SOLUTIONS.md           # Dependency troubleshooting
├── iOS_INTEGRATION_GUIDE.md          # iOS integration instructions
│
├── notebooks/                        # Jupyter notebooks
│   ├── TotalSegmentator_Colab_Final.ipynb
│   ├── TotalSegmentator_PyTorch_to_CoreML_Fixed.ipynb
│   └── TotalSegmentator_PyTorch_to_CoreML_Fixed_v2.ipynb
│
├── scripts/                          # Conversion scripts
│   └── convert_full_model.py        # Main conversion script
│
├── docker/                          # Docker setup
│   ├── Dockerfile
│   ├── convert_model.py
│   ├── docker-compose.yml
│   └── run_conversion.sh
│
├── MODEL_FILES/                     # Your converted models
│   ├── model.mlmodel
│   ├── weight.bin
│   └── TotalSegmentatorWrapper.swift
│
├── .devcontainer/                   # GitHub Codespaces config
│   ├── devcontainer.json
│   ├── Dockerfile
│   └── post-create.sh
│
├── .github/                         # GitHub Actions
│   └── workflows/
│       └── convert-model.yml
│
└── requirements-codespaces.txt      # Python dependencies
```

## Converted Models

Your successfully converted models are in the `MODEL_FILES/` directory:
- `model.mlmodel` - CoreML model (6.1 KB)
- `weight.bin` - Model weights (60.5 KB)
- `TotalSegmentatorWrapper.swift` - iOS integration code

## Next Steps

1. Follow the `iOS_INTEGRATION_GUIDE.md` to integrate the models into your iOS app
2. For larger/more accurate models, use the conversion scripts
3. For production models with original weights, contact the TotalSegmentator team

## Dependencies

- Python 3.11
- PyTorch 2.1.2
- CoreMLTools 7.2
- NumPy 1.24.3

## Support

If you encounter issues:
1. Check `DEPENDENCY_SOLUTIONS.md` for common problems
2. Use Docker for a clean environment
3. Try Google Colab for a managed environment