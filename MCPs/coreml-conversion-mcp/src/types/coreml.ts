/**
 * CoreML Conversion Types
 * Advanced types for medical imaging model conversion with iOS 18+ support
 */

export interface ModelConversionConfig {
  // Source model configuration
  sourcePath: string;
  sourceFormat: 'pytorch' | 'onnx' | 'tensorflow';
  modelType: 'segmentation' | 'classification' | 'detection' | 'custom';
  
  // Target configuration
  targetPath: string;
  targetFormat: 'mlpackage' | 'mlmodel';
  deploymentTarget: 'iOS16' | 'iOS17' | 'iOS18' | 'macOS13' | 'macOS14' | 'macOS15';
  
  // Model metadata
  modelName: string;
  version: string;
  description: string;
  author: string;
  license?: string;
  
  // Conversion options
  computeUnits: 'cpuOnly' | 'cpuAndGPU' | 'all' | 'cpuAndNeuralEngine';
  precision: 'float32' | 'float16' | 'int8' | 'int4';
  
  // Medical imaging specific
  medicalContext: MedicalImagingContext;
}

export interface MedicalImagingContext {
  modality: 'CT' | 'MR' | 'US' | 'XR' | 'PET' | 'SPECT' | 'multi';
  anatomy: string[];
  clinicalUse: 'diagnostic' | 'screening' | 'treatment_planning' | 'research';
  dataType: 'DICOM' | 'NIfTI' | 'PNG' | 'JPEG' | 'mixed';
  
  // TotalSegmentator specific
  segmentationClasses?: number;
  isMultiOrgan?: boolean;
  requires3D?: boolean;
  
  // Preprocessing requirements
  normalization: {
    mean: number[];
    std: number[];
    scale?: number;
    bias?: number;
  };
  
  // Input specifications
  inputShape: number[];
  inputRange: {
    min: number;
    max: number;
  };
  
  // Output specifications
  outputClasses: number;
  outputType: 'mask' | 'probability' | 'logits' | 'coordinates';
}

export interface OptimizationConfig {
  // Quantization options (iOS 18+ features)
  quantization: {
    enabled: boolean;
    method: 'linear_symmetric' | 'linear_asymmetric' | 'dynamic';
    dtype: 'int8' | 'int4' | 'int3' | 'uint8' | 'uint4';
    perChannel?: boolean;
    calibrationDataPath?: string;
  };
  
  // Palettization options (iOS 18+ enhanced)
  palettization: {
    enabled: boolean;
    nBits: 1 | 2 | 3 | 4 | 6 | 8;
    enablePerChannelScale?: boolean;
    clusterDim?: number;
    groupedChannels?: boolean;
  };
  
  // Pruning options
  pruning: {
    enabled: boolean;
    sparsity: number; // 0.0 to 1.0
    structured?: boolean;
  };
  
  // Model splitting for large models
  modelSplitting: {
    enabled: boolean;
    splitPoints?: string[];
    maxModelSize?: number; // in MB
  };
  
  // iOS 18+ stateful models
  statefulOptimization: {
    enabled: boolean;
    cacheSize?: number;
    stateNames?: string[];
  };
}

export interface ConversionResult {
  success: boolean;
  modelPath?: string;
  metadata: ModelMetadata;
  performance: PerformanceMetrics;
  validation: ValidationResult;
  recommendations: string[];
  warnings: string[];
  errors: string[];
}

export interface ModelMetadata {
  name: string;
  version: string;
  format: string;
  size: number; // in bytes
  createdAt: string;
  
  // CoreML specific
  coreMLVersion: string;
  minimumDeploymentTarget: string;
  computeUnits: string[];
  
  // Medical context
  medicalMetadata: {
    modality: string;
    anatomy: string[];
    classes: number;
    inputShape: number[];
    outputShape: number[];
    clinicalValidation?: boolean;
  };
  
  // Model architecture
  architecture: {
    framework: string;
    baseModel: string;
    layers: number;
    parameters: number;
    operations: number;
  };
}

export interface PerformanceMetrics {
  // Model size metrics
  originalSize: number;
  compressedSize: number;
  compressionRatio: number;
  
  // Inference metrics (estimated)
  cpuInferenceTime?: number; // ms
  gpuInferenceTime?: number; // ms
  neuralEngineInferenceTime?: number; // ms
  
  // Memory usage
  peakMemoryUsage: number; // MB
  
  // Accuracy metrics (if validation data provided)
  accuracy?: number;
  diceScore?: number; // for segmentation
  ioU?: number; // for segmentation
  
  // Device compatibility
  supportedDevices: string[];
  recommendedDevice: string;
}

export interface ValidationResult {
  isValid: boolean;
  modelStructure: {
    inputsValid: boolean;
    outputsValid: boolean;
    operationsSupported: boolean;
  };
  
  // Medical imaging validation
  medicalCompliance: {
    dicomCompatible: boolean;
    clinicalAccuracy?: number;
    segmentationQuality?: {
      boundaryAccuracy: number;
      volumeAccuracy: number;
      anatomicalConsistency: number;
    };
  };
  
  // Performance validation
  performanceTests: {
    cpuTest: boolean;
    gpuTest: boolean;
    neuralEngineTest: boolean;
    memoryTest: boolean;
  };
  
  errors: ValidationError[];
  warnings: ValidationWarning[];
}

export interface ValidationError {
  code: string;
  message: string;
  severity: 'error' | 'critical';
  suggestion?: string;
}

export interface ValidationWarning {
  code: string;
  message: string;
  impact: 'performance' | 'accuracy' | 'compatibility' | 'unknown' | 'compliance';
  suggestion?: string;
}

// TotalSegmentator specific types
export interface TotalSegmentatorConfig {
  modelVariant: '1.5mm' | '3mm' | 'fast' | 'total_mr';
  taskType: 'total' | 'lung_vessels' | 'covid' | 'body' | 'custom';
  
  // Model source
  huggingFaceRepo?: string;
  localModelPath?: string;
  
  // Preprocessing
  ctNormalization: {
    windowCenter: number;
    windowWidth: number;
    huRange: {
      min: number;
      max: number;
    };
  };
  
  // Output configuration
  outputMasks: string[];
  combineOrgans?: boolean;
  generateMeshes?: boolean;
}

// Device capability assessment
export interface DeviceCapabilities {
  deviceModel: string;
  osVersion: string;
  
  // Hardware specs
  neuralEngine: {
    available: boolean;
    version?: string;
    computeUnits?: number;
  };
  
  gpu: {
    available: boolean;
    family?: string;
    memoryBandwidth?: number;
  };
  
  cpu: {
    cores: number;
    performanceCores: number;
    efficiencyCores: number;
  };
  
  memory: {
    total: number; // GB
    available: number; // GB
  };
  
  // Recommendations
  recommendedOptimizations: string[];
  maxModelSize: number; // MB
  preferredComputeUnit: string;
}

// Conversion pipeline stages
export interface ConversionPipeline {
  stages: ConversionStage[];
  currentStage: number;
  totalStages: number;
  startTime: string;
  estimatedDuration?: number; // seconds
}

export interface ConversionStage {
  name: string;
  description: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  progress: number; // 0-100
  startTime?: string;
  duration?: number; // seconds
  output?: string;
  error?: string;
}

// Batch conversion for multiple models
export interface BatchConversionConfig {
  models: ModelConversionConfig[];
  parallelConversions: number;
  continueOnError: boolean;
  outputDirectory: string;
  
  // Shared optimizations
  sharedOptimizations: OptimizationConfig;
  generateReport: boolean;
}

export interface BatchConversionResult {
  totalModels: number;
  successful: number;
  failed: number;
  results: ConversionResult[];
  summary: BatchConversionSummary;
}

export interface BatchConversionSummary {
  totalTime: number; // seconds
  averageTime: number; // seconds per model
  totalSizeReduction: number; // bytes
  averageCompressionRatio: number;
  
  deviceCompatibility: {
    [device: string]: number; // count of compatible models
  };
  
  recommendations: string[];
}