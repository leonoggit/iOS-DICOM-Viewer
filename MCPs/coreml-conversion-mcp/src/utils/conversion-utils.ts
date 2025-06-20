/**
 * CoreML Conversion Utilities
 * Advanced utilities for medical imaging model conversion
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { 
  ModelConversionConfig, 
  OptimizationConfig, 
  DeviceCapabilities, 
  TotalSegmentatorConfig,
  MedicalImagingContext,
  ConversionStage,
  ConversionPipeline
} from '../types/coreml.js';

export class ConversionUtils {
  
  /**
   * Generate Python conversion script for CoreML Tools 8.0+
   */
  static generateConversionScript(config: ModelConversionConfig, optimization: OptimizationConfig): string {
    const scriptId = uuidv4().slice(0, 8);
    const scriptName = `convert_${config.modelName}_${scriptId}.py`;
    
    return `#!/usr/bin/env python3
"""
Advanced CoreML Conversion Script
Generated for: ${config.modelName}
CoreML Tools 8.0+ with iOS 18 optimizations
Medical Imaging Context: ${config.medicalContext.modality}
"""

import torch
import coremltools as ct
import numpy as np
import os
import sys
from pathlib import Path
import json
import time
from typing import Dict, Any, Tuple, List

# Enhanced imports for iOS 18+ features
import coremltools.optimize.coreml as cto
from coremltools.models.utils import save_multifunction
from coremltools.models import ComputeUnit

class MedicalModelConverter:
    def __init__(self):
        self.config = ${JSON.stringify(config, null, 8)}
        self.optimization = ${JSON.stringify(optimization, null, 8)}
        self.conversion_log = []
        
    def log_step(self, step: str, details: str = ""):
        """Log conversion steps for detailed tracking"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {step}: {details}"
        print(log_entry)
        self.conversion_log.append(log_entry)
    
    def validate_environment(self) -> bool:
        """Validate CoreML Tools version and dependencies"""
        try:
            import coremltools
            version = coremltools.__version__
            self.log_step("Environment Check", f"CoreML Tools version: {version}")
            
            # Check for iOS 18+ features
            if hasattr(ct, 'StateType'):
                self.log_step("Feature Check", "iOS 18 stateful model support: Available")
            
            if hasattr(cto, 'OpLinearQuantizerConfig'):
                self.log_step("Feature Check", "Advanced quantization: Available")
                
            return True
        except Exception as e:
            self.log_step("Environment Error", str(e))
            return False
    
    def load_pytorch_model(self) -> torch.nn.Module:
        """Load and prepare PyTorch model for conversion"""
        self.log_step("Model Loading", f"Loading from: {self.config['sourcePath']}")
        
        try:
            # Handle different PyTorch model formats
            if self.config['sourcePath'].endswith('.pth') or self.config['sourcePath'].endswith('.pt'):
                model = torch.load(self.config['sourcePath'], map_location='cpu')
            elif self.config['sourcePath'].endswith('.ckpt'):
                # Handle checkpoint files (common in medical imaging)
                checkpoint = torch.load(self.config['sourcePath'], map_location='cpu')
                model = checkpoint.get('model', checkpoint.get('state_dict', checkpoint))
            else:
                raise ValueError(f"Unsupported model format: {self.config['sourcePath']}")
            
            # Ensure model is in evaluation mode
            if hasattr(model, 'eval'):
                model.eval()
            
            self.log_step("Model Loaded", f"Model type: {type(model)}")
            return model
            
        except Exception as e:
            self.log_step("Model Loading Error", str(e))
            raise
    
    def create_example_input(self) -> torch.Tensor:
        """Create example input based on medical imaging context"""
        shape = self.config['medicalContext']['inputShape']
        
        # Create realistic medical imaging input
        if self.config['medicalContext']['modality'] == 'CT':
            # CT typically has HU values from -1000 to +3000
            example_input = torch.randint(-1000, 3000, shape, dtype=torch.float32)
        elif self.config['medicalContext']['modality'] == 'MR':
            # MR has arbitrary intensity values, typically 0-4095
            example_input = torch.randint(0, 4095, shape, dtype=torch.float32)
        else:
            # Default normalized input
            example_input = torch.randn(*shape, dtype=torch.float32)
        
        self.log_step("Example Input", f"Shape: {shape}, Modality: {self.config['medicalContext']['modality']}")
        return example_input
    
    def apply_model_wrapping(self, model: torch.nn.Module) -> torch.nn.Module:
        """Wrap model for medical imaging specific preprocessing"""
        
        class MedicalImagePreprocessingWrapper(torch.nn.Module):
            def __init__(self, base_model, normalization):
                super().__init__()
                self.base_model = base_model
                self.mean = torch.tensor(normalization['mean'], dtype=torch.float32)
                self.std = torch.tensor(normalization['std'], dtype=torch.float32)
                
            def forward(self, x):
                # Apply medical imaging normalization
                x = (x - self.mean.view(1, -1, 1, 1)) / self.std.view(1, -1, 1, 1)
                
                # Apply base model
                output = self.base_model(x)
                
                # Post-process for medical imaging
                if self.base_model.training == False:  # Inference mode
                    if len(output.shape) == 4:  # Segmentation output
                        # Apply softmax for probability maps
                        output = torch.softmax(output, dim=1)
                
                return output
        
        normalization = self.config['medicalContext']['normalization']
        wrapped_model = MedicalImagePreprocessingWrapper(model, normalization)
        
        self.log_step("Model Wrapping", "Applied medical imaging preprocessing wrapper")
        return wrapped_model
    
    def trace_model(self, model: torch.nn.Module, example_input: torch.Tensor) -> torch.jit.ScriptModule:
        """Trace PyTorch model with enhanced error handling"""
        self.log_step("Model Tracing", "Starting TorchScript tracing")
        
        try:
            # Use torch.jit.trace for most reliable conversion
            traced_model = torch.jit.trace(model, example_input, strict=False)
            
            # Validate tracing
            with torch.no_grad():
                original_output = model(example_input)
                traced_output = traced_model(example_input)
                
                # Check output similarity
                if torch.allclose(original_output, traced_output, rtol=1e-3, atol=1e-3):
                    self.log_step("Tracing Validation", "✅ Outputs match within tolerance")
                else:
                    self.log_step("Tracing Warning", "⚠️ Traced model outputs differ from original")
            
            return traced_model
            
        except Exception as e:
            self.log_step("Tracing Error", str(e))
            
            # Fallback to torch.export for newer models
            try:
                self.log_step("Fallback", "Attempting torch.export (experimental)")
                exported_program = torch.export.export(model, (example_input,))
                return exported_program
            except Exception as e2:
                self.log_step("Export Error", str(e2))
                raise RuntimeError(f"Both tracing and export failed: {e}, {e2}")
    
    def configure_coreml_inputs(self, example_input: torch.Tensor) -> List[ct.TensorType]:
        """Configure CoreML input specifications for medical imaging"""
        
        # Medical imaging specific input configuration
        medical_context = self.config['medicalContext']
        
        if medical_context['modality'] in ['CT', 'MR']:
            # Medical images often have flexible input sizes
            input_spec = ct.TensorType(
                name="medical_image",
                shape=ct.Shape(shape=example_input.shape),
                dtype=np.float32
            )
        else:
            # Standard tensor input
            input_spec = ct.TensorType(
                name="input",
                shape=example_input.shape,
                dtype=np.float32
            )
        
        self.log_step("Input Configuration", f"Configured input: {input_spec.name}, shape: {example_input.shape}")
        return [input_spec]
    
    def configure_compute_units(self) -> ComputeUnit:
        """Configure compute units based on target deployment"""
        compute_unit_map = {
            'cpuOnly': ComputeUnit.CPU_ONLY,
            'cpuAndGPU': ComputeUnit.CPU_AND_GPU,
            'all': ComputeUnit.ALL,
            'cpuAndNeuralEngine': ComputeUnit.CPU_AND_NEURAL_ENGINE
        }
        
        compute_unit = compute_unit_map.get(self.config['computeUnits'], ComputeUnit.ALL)
        self.log_step("Compute Units", f"Configured: {self.config['computeUnits']}")
        return compute_unit
    
    def convert_to_coreml(self, traced_model, inputs: List[ct.TensorType]) -> ct.models.MLModel:
        """Convert traced model to CoreML with iOS 18+ features"""
        self.log_step("CoreML Conversion", "Starting conversion")
        
        # Configure conversion parameters
        convert_params = {
            'inputs': inputs,
            'compute_units': self.configure_compute_units(),
            'minimum_deployment_target': getattr(ct.target, self.config['deploymentTarget'], ct.target.iOS16),
            'convert_to': 'mlprogram' if self.config['targetFormat'] == 'mlpackage' else 'neuralnetwork'
        }
        
        # Add iOS 18+ stateful model support if enabled
        if (self.optimization.get('statefulOptimization', {}).get('enabled') and 
            hasattr(ct, 'StateType')):
            
            cache_shape = [1, 256, 32, 32]  # Example cache shape
            convert_params['states'] = [
                ct.StateType(name="kv_cache", shape=cache_shape)
            ]
            self.log_step("Stateful Model", "Enabled iOS 18 stateful model support")
        
        try:
            mlmodel = ct.convert(traced_model, **convert_params)
            self.log_step("Conversion Success", f"Model converted to {self.config['targetFormat']}")
            return mlmodel
            
        except Exception as e:
            self.log_step("Conversion Error", str(e))
            raise
    
    def apply_optimizations(self, mlmodel: ct.models.MLModel) -> ct.models.MLModel:
        """Apply iOS 18+ optimizations"""
        optimized_model = mlmodel
        
        # Apply quantization
        if self.optimization['quantization']['enabled']:
            self.log_step("Quantization", f"Applying {self.optimization['quantization']['dtype']} quantization")
            
            try:
                config = cto.OptimizationConfig(
                    global_config=cto.OpLinearQuantizerConfig(
                        mode=self.optimization['quantization']['method'],
                        dtype=self.optimization['quantization']['dtype']
                    )
                )
                
                optimized_model = cto.linear_quantize_weights(optimized_model, config)
                self.log_step("Quantization Success", "Model weights quantized")
                
            except Exception as e:
                self.log_step("Quantization Error", str(e))
        
        # Apply palettization  
        if self.optimization['palettization']['enabled']:
            self.log_step("Palettization", f"Applying {self.optimization['palettization']['nBits']}-bit palettization")
            
            try:
                config = cto.OptimizationConfig(
                    global_config=cto.OpPalettizerConfig(
                        nbits=self.optimization['palettization']['nBits'],
                        enable_per_channel_scale=self.optimization['palettization'].get('enablePerChannelScale', False)
                    )
                )
                
                optimized_model = cto.palettize_weights(optimized_model, config)
                self.log_step("Palettization Success", "Model weights palettized")
                
            except Exception as e:
                self.log_step("Palettization Error", str(e))
        
        return optimized_model
    
    def add_medical_metadata(self, mlmodel: ct.models.MLModel) -> ct.models.MLModel:
        """Add medical imaging specific metadata"""
        medical_context = self.config['medicalContext']
        
        # Add comprehensive medical metadata
        metadata = {
            "com.apple.coreml.model.preview.type": "imageSegmenter" if self.config['modelType'] == 'segmentation' else "imageClassifier",
            "medical.modality": medical_context['modality'],
            "medical.anatomy": ",".join(medical_context['anatomy']),
            "medical.clinical_use": medical_context['clinicalUse'],
            "medical.classes": str(medical_context['outputClasses']),
            "medical.input_shape": ",".join(map(str, medical_context['inputShape'])),
            "medical.normalization.mean": ",".join(map(str, medical_context['normalization']['mean'])),
            "medical.normalization.std": ",".join(map(str, medical_context['normalization']['std'])),
            "conversion.framework": "CoreML Tools 8.0+",
            "conversion.date": time.strftime("%Y-%m-%d %H:%M:%S"),
            "conversion.config": json.dumps(self.config),
            "model.author": self.config['author'],
            "model.version": self.config['version'],
            "model.license": self.config.get('license', 'Unknown')
        }
        
        # Apply metadata
        for key, value in metadata.items():
            mlmodel.user_defined_metadata[key] = str(value)
        
        self.log_step("Metadata", f"Added {len(metadata)} medical metadata fields")
        return mlmodel
    
    def save_model(self, mlmodel: ct.models.MLModel) -> str:
        """Save optimized CoreML model"""
        output_path = self.config['targetPath']
        
        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Save model
        mlmodel.save(output_path)
        
        # Get model size
        if output_path.endswith('.mlpackage'):
            model_size = sum(os.path.getsize(os.path.join(dirpath, filename))
                           for dirpath, dirnames, filenames in os.walk(output_path)
                           for filename in filenames)
        else:
            model_size = os.path.getsize(output_path)
        
        self.log_step("Model Saved", f"Path: {output_path}, Size: {model_size / (1024*1024):.2f} MB")
        return output_path
    
    def generate_conversion_report(self, model_path: str, start_time: float) -> Dict[str, Any]:
        """Generate comprehensive conversion report"""
        end_time = time.time()
        conversion_duration = end_time - start_time
        
        report = {
            "conversion_summary": {
                "model_name": self.config['modelName'],
                "source_path": self.config['sourcePath'],
                "target_path": model_path,
                "duration_seconds": conversion_duration,
                "success": True
            },
            "model_metadata": {
                "format": self.config['targetFormat'],
                "deployment_target": self.config['deploymentTarget'],
                "compute_units": self.config['computeUnits'],
                "precision": self.config['precision']
            },
            "medical_context": self.config['medicalContext'],
            "optimizations_applied": self.optimization,
            "conversion_log": self.conversion_log,
            "recommendations": self.generate_recommendations()
        }
        
        return report
    
    def generate_recommendations(self) -> List[str]:
        """Generate deployment recommendations"""
        recommendations = []
        
        # Device-specific recommendations
        if self.config['deploymentTarget'] == 'iOS18':
            recommendations.append("✅ Model targets iOS 18+ with latest optimizations")
            
        if self.optimization['quantization']['enabled']:
            recommendations.append(f"🔧 Model quantized to {self.optimization['quantization']['dtype']} - expect {70-90}% size reduction")
            
        if self.optimization['palettization']['enabled']:
            recommendations.append(f"🎨 Model palettized with {self.optimization['palettization']['nBits']}-bit - optimized for Neural Engine")
            
        # Medical imaging specific
        if self.config['medicalContext']['modality'] == 'CT':
            recommendations.append("🏥 CT-optimized model - ensure HU value preprocessing")
            
        if self.config['medicalContext']['requires3D']:
            recommendations.append("📊 3D model - consider memory optimization for mobile deployment")
            
        return recommendations
    
    def convert(self) -> Dict[str, Any]:
        """Main conversion pipeline"""
        start_time = time.time()
        
        try:
            # Validate environment
            if not self.validate_environment():
                raise RuntimeError("Environment validation failed")
            
            # Load model
            model = self.load_pytorch_model()
            
            # Create example input
            example_input = self.create_example_input()
            
            # Apply medical imaging wrapper
            wrapped_model = self.apply_model_wrapping(model)
            
            # Trace model
            traced_model = self.trace_model(wrapped_model, example_input)
            
            # Configure inputs
            inputs = self.configure_coreml_inputs(example_input)
            
            # Convert to CoreML
            mlmodel = self.convert_to_coreml(traced_model, inputs)
            
            # Apply optimizations
            optimized_model = self.apply_optimizations(mlmodel)
            
            # Add medical metadata
            final_model = self.add_medical_metadata(optimized_model)
            
            # Save model
            model_path = self.save_model(final_model)
            
            # Generate report
            report = self.generate_conversion_report(model_path, start_time)
            
            return report
            
        except Exception as e:
            self.log_step("Conversion Failed", str(e))
            return {
                "conversion_summary": {
                    "success": False,
                    "error": str(e),
                    "duration_seconds": time.time() - start_time
                },
                "conversion_log": self.conversion_log
            }

def main():
    """Main conversion entry point"""
    converter = MedicalModelConverter()
    result = converter.convert()
    
    # Save conversion report
    report_path = "${config.targetPath.replace(/\.[^/.]+$/, '')}_conversion_report.json"
    with open(report_path, 'w') as f:
        json.dump(result, f, indent=2, default=str)
    
    print(f"\\n{'='*50}")
    print("CONVERSION COMPLETE")
    print(f"{'='*50}")
    print(f"Success: {result['conversion_summary']['success']}")
    print(f"Duration: {result['conversion_summary'].get('duration_seconds', 0):.2f}s")
    print(f"Report: {report_path}")
    
    if result['conversion_summary']['success']:
        print(f"Model: {result['conversion_summary']['target_path']}")
        print("\\nRecommendations:")
        for rec in result.get('recommendations', []):
            print(f"  {rec}")
    else:
        print(f"Error: {result['conversion_summary'].get('error', 'Unknown error')}")
        sys.exit(1)

if __name__ == "__main__":
    main()
`;
  }

  /**
   * Generate TotalSegmentator specific conversion configuration
   */
  static generateTotalSegmentatorConfig(
    modelPath: string,
    variant: '1.5mm' | '3mm' = '3mm',
    anatomy: string[] = ['total']
  ): TotalSegmentatorConfig {
    return {
      modelVariant: variant,
      taskType: anatomy.includes('lung') ? 'lung_vessels' : 'total',
      localModelPath: modelPath,
      
      ctNormalization: {
        windowCenter: 40,
        windowWidth: 400,
        huRange: {
          min: -1000,
          max: 3000
        }
      },
      
      outputMasks: anatomy,
      combineOrgans: anatomy.length > 10,
      generateMeshes: false // Disable for mobile deployment
    };
  }

  /**
   * Assess device capabilities for model deployment
   */
  static assessDeviceCapabilities(
    deviceModel: string = 'iPhone16,2', // iPhone 16 Pro Max
    osVersion: string = '18.0'
  ): DeviceCapabilities {
    
    // Device capability database (simplified)
    const deviceSpecs: { [key: string]: any } = {
      'iPhone16,2': { // iPhone 16 Pro Max
        neuralEngine: { available: true, version: 'A18', computeUnits: 35 },
        gpu: { available: true, family: 'Apple8', memoryBandwidth: 273 },
        cpu: { cores: 6, performanceCores: 2, efficiencyCores: 4 },
        memory: { total: 8, available: 6 }
      },
      'iPhone15,3': { // iPhone 15 Pro Max
        neuralEngine: { available: true, version: 'A17', computeUnits: 35 },
        gpu: { available: true, family: 'Apple7', memoryBandwidth: 250 },
        cpu: { cores: 6, performanceCores: 2, efficiencyCores: 4 },
        memory: { total: 8, available: 6 }
      },
      'MacBookPro18,1': { // MacBook Pro M4 
        neuralEngine: { available: true, version: 'M4', computeUnits: 38 },
        gpu: { available: true, family: 'AppleM4', memoryBandwidth: 546 },
        cpu: { cores: 14, performanceCores: 10, efficiencyCores: 4 },
        memory: { total: 36, available: 32 }
      }
    };

    const specs = deviceSpecs[deviceModel] || deviceSpecs['iPhone16,2'];
    
    const capabilities: DeviceCapabilities = {
      deviceModel,
      osVersion,
      ...specs,
      
      recommendedOptimizations: [
        specs.neuralEngine.available ? 'Use Neural Engine for inference' : 'Optimize for CPU/GPU',
        specs.memory.total < 8 ? 'Apply aggressive quantization' : 'Standard optimizations sufficient',
        'Enable palettization for Neural Engine efficiency'
      ],
      
      maxModelSize: specs.memory.total * 256, // Conservative estimate in MB
      preferredComputeUnit: specs.neuralEngine.available ? 'cpuAndNeuralEngine' : 'cpuAndGPU'
    };

    return capabilities;
  }

  /**
   * Create conversion pipeline stages
   */
  static createConversionPipeline(config: ModelConversionConfig): ConversionPipeline {
    const stages: ConversionStage[] = [
      {
        name: 'environment_validation',
        description: 'Validate CoreML Tools and dependencies',
        status: 'pending',
        progress: 0
      },
      {
        name: 'model_loading',
        description: 'Load PyTorch model and validate structure',
        status: 'pending',
        progress: 0
      },
      {
        name: 'preprocessing_setup',
        description: 'Configure medical imaging preprocessing',
        status: 'pending',
        progress: 0
      },
      {
        name: 'model_tracing',
        description: 'Trace PyTorch model for CoreML conversion',
        status: 'pending',
        progress: 0
      },
      {
        name: 'coreml_conversion',
        description: 'Convert traced model to CoreML format',
        status: 'pending',
        progress: 0
      },
      {
        name: 'optimization',
        description: 'Apply quantization and palettization',
        status: 'pending',
        progress: 0
      },
      {
        name: 'validation',
        description: 'Validate converted model functionality',
        status: 'pending',
        progress: 0
      },
      {
        name: 'metadata_addition',
        description: 'Add medical imaging metadata',
        status: 'pending',
        progress: 0
      },
      {
        name: 'model_saving',
        description: 'Save optimized CoreML model',
        status: 'pending',
        progress: 0
      }
    ];

    return {
      stages,
      currentStage: 0,
      totalStages: stages.length,
      startTime: new Date().toISOString()
    };
  }

  /**
   * Validate model conversion configuration
   */
  static validateConversionConfig(config: ModelConversionConfig): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];

    // Validate required fields
    if (!config.sourcePath || !fs.existsSync(config.sourcePath)) {
      errors.push(`Source model path does not exist: ${config.sourcePath}`);
    }

    if (!config.targetPath) {
      errors.push('Target path is required');
    }

    if (!config.modelName || config.modelName.trim().length === 0) {
      errors.push('Model name is required');
    }

    // Validate medical context
    if (!config.medicalContext.inputShape || config.medicalContext.inputShape.length === 0) {
      errors.push('Input shape is required in medical context');
    }

    if (!config.medicalContext.normalization.mean || config.medicalContext.normalization.mean.length === 0) {
      errors.push('Normalization parameters are required');
    }

    // Validate deployment target
    const validTargets = ['iOS16', 'iOS17', 'iOS18', 'macOS13', 'macOS14', 'macOS15'];
    if (!validTargets.includes(config.deploymentTarget)) {
      errors.push(`Invalid deployment target: ${config.deploymentTarget}`);
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  /**
   * Estimate conversion time based on model complexity
   */
  static estimateConversionTime(config: ModelConversionConfig): number {
    let baseTime = 120; // 2 minutes base time

    // Adjust based on model complexity
    const inputPixels = config.medicalContext.inputShape.reduce((a, b) => a * b, 1);
    const complexityFactor = Math.log10(inputPixels / 1000000); // Log scale
    baseTime += complexityFactor * 60;

    // Adjust based on optimizations
    if (config.medicalContext.requires3D) {
      baseTime *= 1.5; // 3D models take longer
    }

    // Quantization adds time
    baseTime += 30; // Additional 30 seconds for optimizations

    return Math.max(60, Math.round(baseTime)); // Minimum 1 minute
  }

  /**
   * Generate optimization recommendations based on device and model
   */
  static generateOptimizationRecommendations(
    config: ModelConversionConfig,
    deviceCapabilities: DeviceCapabilities
  ): OptimizationConfig {
    const recommendations: OptimizationConfig = {
      quantization: {
        enabled: true,
        method: 'linear_symmetric',
        dtype: deviceCapabilities.memory.total < 8 ? 'int4' : 'int8',
        perChannel: true
      },
      
      palettization: {
        enabled: deviceCapabilities.neuralEngine.available,
        nBits: deviceCapabilities.neuralEngine.available ? 6 : 8,
        enablePerChannelScale: true,
        groupedChannels: true
      },
      
      pruning: {
        enabled: deviceCapabilities.memory.total < 8,
        sparsity: 0.1, // Conservative pruning
        structured: false
      },
      
      modelSplitting: {
        enabled: Boolean(config.medicalContext.requires3D) && deviceCapabilities.memory.total < 16,
        maxModelSize: deviceCapabilities.maxModelSize
      },
      
      statefulOptimization: {
        enabled: config.deploymentTarget === 'iOS18',
        cacheSize: 256
      }
    };

    return recommendations;
  }
}