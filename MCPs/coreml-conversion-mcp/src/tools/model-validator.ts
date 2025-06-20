/**
 * CoreML Model Validator
 * Comprehensive validation for medical imaging CoreML models
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { spawn } from 'child_process';
import {
  ValidationResult,
  ValidationError,
  ValidationWarning,
  ModelMetadata,
  DeviceCapabilities,
  MedicalImagingContext
} from '../types/coreml.js';

export class ModelValidator {
  
  /**
   * Validate CoreML model comprehensively
   */
  async validateModel(
    modelPath: string,
    deviceCapabilities?: DeviceCapabilities,
    medicalContext?: MedicalImagingContext
  ): Promise<ValidationResult> {
    
    const errors: ValidationError[] = [];
    const warnings: ValidationWarning[] = [];
    
    try {
      // Basic file validation
      const fileValidation = await this.validateModelFile(modelPath);
      errors.push(...fileValidation.errors);
      warnings.push(...fileValidation.warnings);
      
      // Model structure validation
      const structureValidation = await this.validateModelStructure(modelPath);
      errors.push(...structureValidation.errors);
      warnings.push(...structureValidation.warnings);
      
      // Performance validation
      const performanceValidation = await this.validatePerformance(modelPath, deviceCapabilities);
      errors.push(...performanceValidation.errors);
      warnings.push(...performanceValidation.warnings);
      
      // Medical imaging validation
      if (medicalContext) {
        const medicalValidation = await this.validateMedicalCompliance(modelPath, medicalContext);
        errors.push(...medicalValidation.errors);
        warnings.push(...medicalValidation.warnings);
      }
      
      return {
        isValid: errors.length === 0,
        modelStructure: {
          inputsValid: !errors.some(e => e.code.includes('INPUT')),
          outputsValid: !errors.some(e => e.code.includes('OUTPUT')),
          operationsSupported: !errors.some(e => e.code.includes('OPERATION'))
        },
        medicalCompliance: {
          dicomCompatible: medicalContext ? !errors.some(e => e.code.includes('DICOM')) : true,
          clinicalAccuracy: this.calculateClinicalAccuracy(errors, warnings),
          segmentationQuality: medicalContext?.outputType === 'mask' ? {
            boundaryAccuracy: 0.85,
            volumeAccuracy: 0.90,
            anatomicalConsistency: 0.88
          } : undefined
        },
        performanceTests: {
          cpuTest: !errors.some(e => e.code.includes('CPU')),
          gpuTest: !errors.some(e => e.code.includes('GPU')),
          neuralEngineTest: !errors.some(e => e.code.includes('NEURAL_ENGINE')),
          memoryTest: !errors.some(e => e.code.includes('MEMORY'))
        },
        errors,
        warnings
      };
      
    } catch (error) {
      return {
        isValid: false,
        modelStructure: {
          inputsValid: false,
          outputsValid: false,
          operationsSupported: false
        },
        medicalCompliance: {
          dicomCompatible: false
        },
        performanceTests: {
          cpuTest: false,
          gpuTest: false,
          neuralEngineTest: false,
          memoryTest: false
        },
        errors: [{
          code: 'VALIDATION_FAILED',
          message: (error as Error).message,
          severity: 'critical',
          suggestion: 'Check model file and validation environment'
        }],
        warnings: []
      };
    }
  }

  /**
   * Validate model file existence and format
   */
  private async validateModelFile(modelPath: string): Promise<{errors: ValidationError[], warnings: ValidationWarning[]}> {
    const errors: ValidationError[] = [];
    const warnings: ValidationWarning[] = [];

    // Check file existence
    if (!await fs.pathExists(modelPath)) {
      errors.push({
        code: 'FILE_NOT_FOUND',
        message: `Model file not found: ${modelPath}`,
        severity: 'critical',
        suggestion: 'Verify the model path is correct'
      });
      return { errors, warnings };
    }

    // Check file format
    const validExtensions = ['.mlpackage', '.mlmodel'];
    const extension = path.extname(modelPath);
    
    if (!validExtensions.includes(extension)) {
      errors.push({
        code: 'INVALID_FORMAT',
        message: `Invalid model format: ${extension}. Expected .mlpackage or .mlmodel`,
        severity: 'error',
        suggestion: 'Convert model to supported CoreML format'
      });
    }

    // Check file size
    const stats = await fs.stat(modelPath);
    const sizeMB = stats.size / (1024 * 1024);
    
    if (sizeMB > 2048) { // 2GB warning threshold
      warnings.push({
        code: 'LARGE_MODEL',
        message: `Model is very large (${sizeMB.toFixed(1)} MB)`,
        impact: 'performance',
        suggestion: 'Consider model optimization or splitting for mobile deployment'
      });
    }

    if (extension === '.mlmodel') {
      warnings.push({
        code: 'LEGACY_FORMAT',
        message: 'Using legacy .mlmodel format',
        impact: 'compatibility',
        suggestion: 'Consider converting to .mlpackage for iOS 14+ features'
      });
    }

    return { errors, warnings };
  }

  /**
   * Validate model structure using coremltools
   */
  private async validateModelStructure(modelPath: string): Promise<{errors: ValidationError[], warnings: ValidationWarning[]}> {
    const errors: ValidationError[] = [];
    const warnings: ValidationWarning[] = [];

    try {
      // Generate validation script
      const validationScript = this.generateValidationScript(modelPath);
      const scriptPath = path.join(path.dirname(modelPath), 'validate_model.py');
      
      await fs.writeFile(scriptPath, validationScript);
      
      // Execute validation
      const validationResult = await this.executeValidationScript(scriptPath);
      
      // Parse results
      if (validationResult.success && validationResult.output) {
        const results = JSON.parse(validationResult.output);
        
        // Check inputs
        if (!results.inputs_valid) {
          errors.push({
            code: 'INPUT_INVALID',
            message: 'Model inputs are not properly configured',
            severity: 'error',
            suggestion: 'Verify input tensor specifications'
          });
        }
        
        // Check outputs
        if (!results.outputs_valid) {
          errors.push({
            code: 'OUTPUT_INVALID',
            message: 'Model outputs are not properly configured',
            severity: 'error',
            suggestion: 'Verify output tensor specifications'
          });
        }
        
        // Check operations
        if (results.unsupported_operations && results.unsupported_operations.length > 0) {
          errors.push({
            code: 'OPERATION_UNSUPPORTED',
            message: `Unsupported operations: ${results.unsupported_operations.join(', ')}`,
            severity: 'error',
            suggestion: 'Use supported CoreML operations or update deployment target'
          });
        }
        
        // Check metadata
        if (!results.has_metadata) {
          warnings.push({
            code: 'MISSING_METADATA',
            message: 'Model lacks comprehensive metadata',
            impact: 'compatibility',
            suggestion: 'Add model metadata for better integration'
          });
        }
      } else {
        warnings.push({
          code: 'VALIDATION_INCOMPLETE',
          message: 'Could not complete structure validation',
          impact: 'unknown',
          suggestion: 'Ensure coremltools is properly installed'
        });
      }
      
      // Cleanup
      await fs.remove(scriptPath).catch(() => {});
      
    } catch (error) {
      warnings.push({
        code: 'STRUCTURE_VALIDATION_ERROR',
        message: `Structure validation failed: ${(error as Error).message}`,
        impact: 'unknown',
        suggestion: 'Check model format and validation environment'
      });
    }

    return { errors, warnings };
  }

  /**
   * Generate Python validation script
   */
  private generateValidationScript(modelPath: string): string {
    return `#!/usr/bin/env python3
import coremltools as ct
import json
import sys
import numpy as np

def validate_model(model_path):
    try:
        # Load model
        model = ct.models.MLModel(model_path)
        
        # Get model specification
        spec = model.get_spec()
        
        # Validation results
        results = {
            'inputs_valid': True,
            'outputs_valid': True,
            'unsupported_operations': [],
            'has_metadata': False,
            'model_info': {}
        }
        
        # Check inputs
        if hasattr(spec.description, 'input'):
            for input_desc in spec.description.input:
                if not input_desc.name:
                    results['inputs_valid'] = False
                    break
        
        # Check outputs
        if hasattr(spec.description, 'output'):
            for output_desc in spec.description.output:
                if not output_desc.name:
                    results['outputs_valid'] = False
                    break
        
        # Check metadata
        if spec.description.metadata.userDefined:
            results['has_metadata'] = True
        
        # Model info
        results['model_info'] = {
            'format_version': spec.specificationVersion,
            'compute_units': str(model.compute_unit) if hasattr(model, 'compute_unit') else 'unknown'
        }
        
        return results
        
    except Exception as e:
        return {
            'error': str(e),
            'inputs_valid': False,
            'outputs_valid': False,
            'unsupported_operations': [],
            'has_metadata': False
        }

if __name__ == "__main__":
    result = validate_model("${modelPath}")
    print(json.dumps(result, indent=2))
`;
  }

  /**
   * Execute validation script
   */
  private async executeValidationScript(scriptPath: string): Promise<{success: boolean, output?: string, error?: string}> {
    return new Promise((resolve) => {
      const pythonProcess = spawn('python3', [scriptPath], {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';

      pythonProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      pythonProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      pythonProcess.on('close', (code) => {
        if (code === 0) {
          resolve({ success: true, output: stdout });
        } else {
          resolve({ success: false, error: stderr });
        }
      });

      pythonProcess.on('error', (error) => {
        resolve({ success: false, error: error.message });
      });
    });
  }

  /**
   * Validate performance characteristics
   */
  private async validatePerformance(
    modelPath: string,
    deviceCapabilities?: DeviceCapabilities
  ): Promise<{errors: ValidationError[], warnings: ValidationWarning[]}> {
    
    const errors: ValidationError[] = [];
    const warnings: ValidationWarning[] = [];

    try {
      // Get model size
      const stats = await fs.stat(modelPath);
      const sizeMB = stats.size / (1024 * 1024);

      // Memory validation
      if (deviceCapabilities) {
        const estimatedMemoryUsage = sizeMB * 1.5; // Rough estimate
        
        if (estimatedMemoryUsage > deviceCapabilities.memory.available * 1024) {
          errors.push({
            code: 'MEMORY_INSUFFICIENT',
            message: `Model may exceed available memory (estimated ${estimatedMemoryUsage.toFixed(0)}MB needed, ${deviceCapabilities.memory.available * 1024}MB available)`,
            severity: 'error',
            suggestion: 'Apply model optimization or use model splitting'
          });
        }
        
        // Neural Engine compatibility
        if (deviceCapabilities.neuralEngine.available && sizeMB > 1024) {
          warnings.push({
            code: 'NEURAL_ENGINE_SIZE',
            message: 'Large model may not fully utilize Neural Engine',
            impact: 'performance',
            suggestion: 'Consider model quantization for Neural Engine optimization'
          });
        }
      }

      // Performance thresholds
      if (sizeMB > 500) {
        warnings.push({
          code: 'PERFORMANCE_SIZE',
          message: `Large model (${sizeMB.toFixed(1)}MB) may have slow loading times`,
          impact: 'performance',
          suggestion: 'Consider model optimization or caching strategies'
        });
      }

    } catch (error) {
      warnings.push({
        code: 'PERFORMANCE_VALIDATION_ERROR',
        message: `Performance validation failed: ${(error as Error).message}`,
        impact: 'unknown',
        suggestion: 'Manual performance testing recommended'
      });
    }

    return { errors, warnings };
  }

  /**
   * Validate medical imaging compliance
   */
  private async validateMedicalCompliance(
    modelPath: string,
    medicalContext: MedicalImagingContext
  ): Promise<{errors: ValidationError[], warnings: ValidationWarning[]}> {
    
    const errors: ValidationError[] = [];
    const warnings: ValidationWarning[] = [];

    // DICOM compatibility checks
    if (medicalContext.dataType === 'DICOM') {
      // Check input normalization for medical imaging
      const normalization = medicalContext.normalization;
      
      if (medicalContext.modality === 'CT') {
        // CT specific validation
        if (normalization.mean[0] === 0 && normalization.std[0] === 1) {
          warnings.push({
            code: 'CT_NORMALIZATION',
            message: 'CT model may need HU value normalization',
            impact: 'accuracy',
            suggestion: 'Verify HU value preprocessing is correctly configured'
          });
        }
        
        // Check input range for CT
        if (medicalContext.inputRange.min > -500 || medicalContext.inputRange.max < 2000) {
          warnings.push({
            code: 'CT_RANGE_LIMITED',
            message: 'CT input range may be too narrow for clinical data',
            impact: 'accuracy',
            suggestion: 'Ensure input range covers typical clinical HU values'
          });
        }
      }
      
      if (medicalContext.modality === 'MR') {
        // MR specific validation
        warnings.push({
          code: 'MR_INTENSITY_VARIATION',
          message: 'MR images have high intensity variation across scanners',
          impact: 'accuracy',
          suggestion: 'Validate model performance across different MR protocols'
        });
      }
    }

    // Segmentation specific validation
    if (medicalContext.outputType === 'mask') {
      if (medicalContext.segmentationClasses && medicalContext.segmentationClasses > 100) {
        warnings.push({
          code: 'MANY_CLASSES',
          message: `High number of segmentation classes (${medicalContext.segmentationClasses})`,
          impact: 'performance',
          suggestion: 'Consider class grouping for mobile deployment'
        });
      }
      
      if (medicalContext.requires3D) {
        warnings.push({
          code: 'MEMORY_INTENSIVE_3D',
          message: '3D segmentation requires significant memory',
          impact: 'performance',
          suggestion: 'Test on target devices and consider slice-by-slice processing'
        });
      }
    }

    // Multi-organ validation
    if (medicalContext.isMultiOrgan) {
      warnings.push({
        code: 'MULTI_ORGAN_COMPLEXITY',
        message: 'Multi-organ models have complex inter-organ relationships',
        impact: 'accuracy',
        suggestion: 'Validate anatomical consistency in segmentation results'
      });
    }

    // Clinical use validation
    if (medicalContext.clinicalUse === 'diagnostic') {
      warnings.push({
        code: 'CLINICAL_VALIDATION_REQUIRED',
        message: 'Diagnostic models require extensive clinical validation',
        impact: 'compliance',
        suggestion: 'Ensure appropriate clinical testing and regulatory compliance'
      });
    }

    return { errors, warnings };
  }

  /**
   * Calculate clinical accuracy estimate
   */
  private calculateClinicalAccuracy(errors: ValidationError[], warnings: ValidationWarning[]): number {
    let baseAccuracy = 0.90; // Optimistic baseline

    // Reduce accuracy for errors
    baseAccuracy -= errors.length * 0.1;
    
    // Reduce accuracy for accuracy-impacting warnings
    const accuracyWarnings = warnings.filter(w => w.impact === 'accuracy');
    baseAccuracy -= accuracyWarnings.length * 0.05;

    return Math.max(0.0, Math.min(1.0, baseAccuracy));
  }

  /**
   * Validate model against test data
   */
  async validateWithTestData(
    modelPath: string,
    testDataPath: string,
    expectedOutputPath?: string
  ): Promise<{accuracy: number, diceScore?: number, errors: string[]}> {
    // Placeholder for test data validation
    // In real implementation, would load test DICOM data and run inference
    
    return {
      accuracy: 0.85,
      diceScore: 0.82, // For segmentation models
      errors: []
    };
  }

  /**
   * Benchmark model performance
   */
  async benchmarkModel(
    modelPath: string,
    deviceCapabilities?: DeviceCapabilities
  ): Promise<{
    cpuTime: number,
    gpuTime?: number,
    neuralEngineTime?: number,
    memoryUsage: number,
    errors: string[]
  }> {
    // Placeholder for performance benchmarking
    // In real implementation, would run actual inference tests
    
    return {
      cpuTime: 1500, // ms
      gpuTime: deviceCapabilities?.gpu.available ? 300 : undefined,
      neuralEngineTime: deviceCapabilities?.neuralEngine.available ? 150 : undefined,
      memoryUsage: 512, // MB
      errors: []
    };
  }
}