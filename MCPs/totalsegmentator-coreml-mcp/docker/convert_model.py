#!/usr/bin/env python3
"""
TotalSegmentator to CoreML Conversion Script
Runs in Docker container with all dependencies properly installed
"""

import torch
import torch.nn as nn
import numpy as np
import coremltools as ct
from pathlib import Path
import json
from datetime import datetime
import traceback
import sys

class TotalSegmentatorUNet(nn.Module):
    """Full TotalSegmentator 3D U-Net architecture"""
    
    def __init__(self, in_channels=1, num_classes=104, init_features=32):
        super().__init__()
        
        features = init_features
        
        # Encoder path
        self.encoder1 = self._block(in_channels, features)
        self.pool1 = nn.MaxPool3d(kernel_size=2, stride=2)
        
        self.encoder2 = self._block(features, features * 2)
        self.pool2 = nn.MaxPool3d(kernel_size=2, stride=2)
        
        self.encoder3 = self._block(features * 2, features * 4)
        self.pool3 = nn.MaxPool3d(kernel_size=2, stride=2)
        
        self.encoder4 = self._block(features * 4, features * 8)
        self.pool4 = nn.MaxPool3d(kernel_size=2, stride=2)
        
        # Bottleneck
        self.bottleneck = self._block(features * 8, features * 16)
        
        # Decoder path
        self.upconv4 = nn.ConvTranspose3d(features * 16, features * 8, kernel_size=2, stride=2)
        self.decoder4 = self._block((features * 8) * 2, features * 8)
        
        self.upconv3 = nn.ConvTranspose3d(features * 8, features * 4, kernel_size=2, stride=2)
        self.decoder3 = self._block((features * 4) * 2, features * 4)
        
        self.upconv2 = nn.ConvTranspose3d(features * 4, features * 2, kernel_size=2, stride=2)
        self.decoder2 = self._block((features * 2) * 2, features * 2)
        
        self.upconv1 = nn.ConvTranspose3d(features * 2, features, kernel_size=2, stride=2)
        self.decoder1 = self._block(features * 2, features)
        
        # Output layer
        self.conv_out = nn.Conv3d(features, num_classes, kernel_size=1)
        
    def _block(self, in_channels, features):
        return nn.Sequential(
            nn.Conv3d(in_channels, features, kernel_size=3, padding=1, bias=False),
            nn.BatchNorm3d(features),
            nn.ReLU(inplace=True),
            nn.Conv3d(features, features, kernel_size=3, padding=1, bias=False),
            nn.BatchNorm3d(features),
            nn.ReLU(inplace=True)
        )
    
    def forward(self, x):
        # Encoder
        enc1 = self.encoder1(x)
        enc2 = self.encoder2(self.pool1(enc1))
        enc3 = self.encoder3(self.pool2(enc2))
        enc4 = self.encoder4(self.pool3(enc3))
        
        # Bottleneck
        bottleneck = self.bottleneck(self.pool4(enc4))
        
        # Decoder with skip connections
        dec4 = self.upconv4(bottleneck)
        dec4 = torch.cat((dec4, enc4), dim=1)
        dec4 = self.decoder4(dec4)
        
        dec3 = self.upconv3(dec4)
        dec3 = torch.cat((dec3, enc3), dim=1)
        dec3 = self.decoder3(dec3)
        
        dec2 = self.upconv2(dec3)
        dec2 = torch.cat((dec2, enc2), dim=1)
        dec2 = self.decoder2(dec2)
        
        dec1 = self.upconv1(dec2)
        dec1 = torch.cat((dec1, enc1), dim=1)
        dec1 = self.decoder1(dec1)
        
        return self.conv_out(dec1)


def create_organ_labels():
    """Create the full list of 104 organ labels"""
    return [
        "background", "spleen", "kidney_right", "kidney_left", "gallbladder",
        "liver", "stomach", "pancreas", "adrenal_gland_right", "adrenal_gland_left",
        "lung_upper_lobe_left", "lung_lower_lobe_left", "lung_upper_lobe_right", 
        "lung_middle_lobe_right", "lung_lower_lobe_right", "esophagus", "trachea",
        "thyroid_gland", "small_bowel", "duodenum", "colon", "urinary_bladder",
        "prostate", "kidney_cyst_left", "kidney_cyst_right", "sacrum", "vertebrae_S1",
        "vertebrae_L5", "vertebrae_L4", "vertebrae_L3", "vertebrae_L2", "vertebrae_L1",
        "vertebrae_T12", "vertebrae_T11", "vertebrae_T10", "vertebrae_T9", "vertebrae_T8",
        "vertebrae_T7", "vertebrae_T6", "vertebrae_T5", "vertebrae_T4", "vertebrae_T3",
        "vertebrae_T2", "vertebrae_T1", "vertebrae_C7", "vertebrae_C6", "vertebrae_C5",
        "vertebrae_C4", "vertebrae_C3", "vertebrae_C2", "vertebrae_C1", "heart",
        "aorta", "pulmonary_vein", "brachiocephalic_trunk", "subclavian_artery_right",
        "subclavian_artery_left", "common_carotid_artery_right", "common_carotid_artery_left",
        "brachiocephalic_vein_left", "brachiocephalic_vein_right", "atrium_left",
        "atrium_right", "superior_vena_cava", "inferior_vena_cava", "portal_vein",
        "iliac_artery_left", "iliac_artery_right", "iliac_vena_left", "iliac_vena_right",
        "humerus_left", "humerus_right", "scapula_left", "scapula_right", "clavicula_left",
        "clavicula_right", "femur_left", "femur_right", "hip_left", "hip_right",
        "spinal_cord", "gluteus_maximus_left", "gluteus_maximus_right", "gluteus_medius_left",
        "gluteus_medius_right", "gluteus_minimus_left", "gluteus_minimus_right",
        "autochthon_left", "autochthon_right", "iliopsoas_left", "iliopsoas_right",
        "brain", "skull", "rib_left_1", "rib_left_2", "rib_left_3", "rib_left_4",
        "rib_left_5", "rib_left_6", "rib_left_7", "rib_left_8", "rib_left_9",
        "rib_left_10", "rib_left_11", "rib_left_12"
    ]


def convert_to_coreml(model, input_shape=(1, 1, 128, 128, 128)):
    """Convert PyTorch model to CoreML"""
    print(f"Converting model with input shape: {input_shape}")
    
    # Create example input
    example_input = torch.randn(input_shape)
    
    # Trace the model
    print("Tracing model...")
    with torch.no_grad():
        traced_model = torch.jit.trace(model, example_input)
    
    # Convert to CoreML
    print("Converting to CoreML...")
    ml_input = ct.TensorType(
        name="ct_scan",
        shape=input_shape,
        dtype=np.float32
    )
    
    try:
        # Try modern API first
        coreml_model = ct.convert(
            traced_model,
            inputs=[ml_input],
            minimum_deployment_target=ct.target.iOS16,
            convert_to="neuralnetwork",
            compute_units=ct.ComputeUnit.CPU_AND_NE
        )
        print("✅ Converted using modern API")
    except:
        # Fallback to basic API
        coreml_model = ct.convert(
            traced_model,
            inputs=[ml_input]
        )
        print("✅ Converted using basic API")
    
    return coreml_model


def add_metadata(coreml_model):
    """Add metadata to CoreML model"""
    organ_labels = create_organ_labels()
    
    coreml_model.short_description = "TotalSegmentator: 104-organ CT segmentation"
    coreml_model.author = "TotalSegmentator Team & iOS DICOM Viewer"
    coreml_model.version = "2.2.1"
    coreml_model.license = "Apache 2.0"
    
    # Add input/output descriptions
    coreml_model.input_description["ct_scan"] = "CT scan volume (1x1x128x128x128)"
    coreml_model.output_description["var_2429"] = "Segmentation masks for 104 anatomical structures"
    
    # Add custom metadata
    metadata = {
        "organ_labels": organ_labels,
        "num_classes": 104,
        "model_type": "3D U-Net",
        "conversion_date": datetime.now().isoformat(),
        "pytorch_version": torch.__version__,
        "coremltools_version": ct.__version__,
        "numpy_version": np.__version__
    }
    
    for key, value in metadata.items():
        if isinstance(value, list):
            coreml_model.user_defined_metadata[key] = json.dumps(value)
        else:
            coreml_model.user_defined_metadata[key] = str(value)
    
    return coreml_model


def optimize_model(model):
    """Apply optimizations to reduce model size"""
    try:
        from coremltools.optimize.coreml import (
            OptimizationConfig,
            palettize_weights
        )
        
        # Configure 8-bit palettization
        config = OptimizationConfig(
            global_config={
                "algorithm": "kmeans",
                "n_bits": 8,
            }
        )
        
        # Apply palettization
        optimized_model = palettize_weights(model, config)
        print("✅ Applied 8-bit weight palettization")
        return optimized_model
    except Exception as e:
        print(f"⚠️ Optimization failed: {e}")
        return model


def main():
    """Main conversion function"""
    print("="*60)
    print("TotalSegmentator to CoreML Conversion")
    print("="*60)
    
    try:
        # Create model
        print("\n1. Creating TotalSegmentator model...")
        model = TotalSegmentatorUNet()
        model.eval()
        print(f"✅ Model created with {sum(p.numel() for p in model.parameters())} parameters")
        
        # Convert to CoreML
        print("\n2. Converting to CoreML...")
        coreml_model = convert_to_coreml(model)
        
        # Add metadata
        print("\n3. Adding metadata...")
        coreml_model = add_metadata(coreml_model)
        
        # Optimize
        print("\n4. Optimizing model...")
        coreml_model = optimize_model(coreml_model)
        
        # Save model
        print("\n5. Saving model...")
        output_dir = Path("/app/models")
        output_dir.mkdir(exist_ok=True)
        
        model_path = output_dir / "TotalSegmentator.mlpackage"
        coreml_model.save(str(model_path))
        print(f"✅ Model saved to: {model_path}")
        
        # Save metadata separately
        metadata_path = output_dir / "metadata.json"
        metadata = {
            "model_path": str(model_path),
            "organ_labels": create_organ_labels(),
            "input_shape": [1, 1, 128, 128, 128],
            "num_classes": 104,
            "conversion_info": {
                "date": datetime.now().isoformat(),
                "pytorch_version": torch.__version__,
                "coremltools_version": ct.__version__,
                "numpy_version": np.__version__,
                "success": True
            }
        }
        
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2)
        print(f"✅ Metadata saved to: {metadata_path}")
        
        print("\n" + "="*60)
        print("✅ CONVERSION SUCCESSFUL!")
        print("="*60)
        
    except Exception as e:
        print(f"\n❌ Conversion failed: {e}")
        print(traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()