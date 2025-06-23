# GitHub Codespaces Guide for TotalSegmentator CoreML Conversion

## Overview

This repository is configured to work seamlessly with GitHub Codespaces, providing a cloud-based development environment with all dependencies pre-installed for converting TotalSegmentator models to CoreML format.

## Quick Start

### 1. Launch Codespace

1. Go to the repository on GitHub
2. Click the green "Code" button
3. Select "Codespaces" tab
4. Click "Create codespace on main"

### 2. Wait for Environment Setup

The Codespace will automatically:
- Install Python 3.11
- Install all required dependencies
- Set up Jupyter Lab
- Configure the development environment

This takes about 2-3 minutes on first launch.

### 3. Verify Environment

Once the Codespace is ready, open the terminal and run:

```bash
python test_environment.py
```

You should see:
```
Python: 3.11.x
✅ PyTorch: 2.1.2
✅ CoreMLTools: 7.2
✅ NumPy: 1.24.3
✅ NiBabel: 5.2.0

🎉 Environment test complete!
```

## Converting Models

### Option 1: Command Line (Recommended)

Run the full conversion script:

```bash
python scripts/convert_full_model.py --input-size 128
```

Options:
- `--input-size`: Cubic volume size (64, 128, 256)
- `--output-dir`: Output directory (default: /workspace/models)
- `--features`: Initial U-Net features (default: 32)

### Option 2: Jupyter Notebook

1. Start Jupyter Lab:
   ```bash
   jupyter lab --ip=0.0.0.0 --no-browser
   ```

2. In VS Code, go to the Ports panel (bottom)
3. Find port 8888 and click the globe icon to open in browser
4. Open `notebooks/TotalSegmentator_Colab_Final.ipynb`
5. Run all cells

### Option 3: Docker (Isolated Environment)

If you need complete isolation:

```bash
cd docker
./run_conversion.sh
```

## Workflow Options

### Basic Conversion (5 minutes)

```bash
# Convert with default settings
python scripts/convert_full_model.py

# Check output
ls -la models/
```

### Custom Size Conversion

```bash
# Smaller model (faster, less accurate)
python scripts/convert_full_model.py --input-size 64

# Larger model (slower, more accurate)
python scripts/convert_full_model.py --input-size 256
```

### Batch Conversion

```bash
# Convert multiple sizes
for size in 64 128 256; do
    python scripts/convert_full_model.py \
        --input-size $size \
        --output-dir "models/size_${size}"
done
```

## Using GitHub Actions

The repository includes a GitHub Action that automatically converts models:

1. Go to Actions tab
2. Select "Convert TotalSegmentator to CoreML"
3. Click "Run workflow"
4. Choose options:
   - Input size (64, 128, 256)
   - Model variant (standard, fast, small)
5. Download artifacts when complete

## Output Files

After conversion, you'll find:

```
models/
├── TotalSegmentator.mlmodel      # iOS 15+ compatible
├── TotalSegmentator.mlpackage/   # iOS 16+ optimized
├── TotalSegmentator.swift        # Integration code
├── README.md                     # Documentation
└── TotalSegmentator_iOS_Package.zip  # Everything bundled
```

## Performance in Codespaces

- **Conversion Time**: 2-5 minutes (CPU only)
- **Memory Usage**: ~2GB during conversion
- **Output Size**: 
  - 64³: ~50MB
  - 128³: ~150MB
  - 256³: ~400MB

## Tips & Tricks

### 1. Faster Conversion
```bash
# Use smaller feature size for testing
python scripts/convert_full_model.py --features 16 --input-size 64
```

### 2. Monitor Progress
```bash
# Watch conversion in real-time
python scripts/convert_full_model.py 2>&1 | tee conversion.log
```

### 3. Download Results
```bash
# Create downloadable archive
cd models
zip -r ../TotalSegmentator_Models.zip *
```

Then download from VS Code file explorer.

### 4. Persistent Storage
Files in `/workspace` persist between Codespace sessions.

### 5. GPU Support
Codespaces don't have GPU, but the converted models will use Neural Engine on iOS devices.

## Troubleshooting

### Memory Issues
If conversion fails with memory errors:
```bash
# Use smaller batch size
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
python scripts/convert_full_model.py --input-size 64
```

### Dependency Conflicts
```bash
# Reset environment
pip uninstall -y torch torchvision coremltools
pip install -r requirements-codespaces.txt
```

### Jupyter Connection Issues
1. Check Ports panel in VS Code
2. Ensure port 8888 is forwarded
3. Try stopping and restarting Jupyter

## Advanced Usage

### Custom Model Architecture
Edit `scripts/convert_full_model.py` to modify:
- Number of U-Net levels
- Feature dimensions
- Activation functions
- Normalization layers

### Production Weights
To use actual TotalSegmentator weights:
1. Download from official repository
2. Upload to Codespace
3. Modify script to load weights

### Multi-Format Export
The script automatically creates both:
- `.mlmodel` - Better compatibility
- `.mlpackage` - Better performance

## Integration with iOS

1. Download the generated package
2. Add to Xcode project
3. Use provided Swift code:

```swift
let segmentator = try TotalSegmentator()
let result = try await segmentator.segment(ctVolume: ctData)
```

## Contributing

1. Fork the repository
2. Create a Codespace on your fork
3. Make changes
4. Test conversion
5. Submit pull request

## Resources

- [TotalSegmentator Paper](https://github.com/wasserth/TotalSegmentator)
- [CoreMLTools Documentation](https://coremltools.readme.io/)
- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)

## Support

If you encounter issues:
1. Check the logs in `/workspace/conversion.log`
2. Verify environment with `test_environment.py`
3. Open an issue with error details

---

Happy converting! 🚀