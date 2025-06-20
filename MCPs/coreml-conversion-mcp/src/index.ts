#!/usr/bin/env node

/**
 * Advanced CoreML Conversion MCP Server
 * Specialized medical imaging model conversion with iOS 18+ optimizations
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';

// Import conversion tools
import { TotalSegmentatorConverter } from './tools/totalsegmentator-converter.js';
import { ModelValidator } from './tools/model-validator.js';

// Import types and utilities
import {
  ModelConversionConfig,
  OptimizationConfig,
  DeviceCapabilities,
  TotalSegmentatorConfig,
  BatchConversionConfig,
  ConversionResult
} from './types/coreml.js';
import { ConversionUtils } from './utils/conversion-utils.js';

class CoreMLConversionServer {
  private server: Server;
  private totalSegmentatorConverter: TotalSegmentatorConverter;
  private modelValidator: ModelValidator;

  constructor() {
    this.server = new Server(
      {
        name: 'coreml-conversion-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // Initialize conversion tools
    this.totalSegmentatorConverter = new TotalSegmentatorConverter();
    this.modelValidator = new ModelValidator();

    this.setupToolHandlers();
    this.setupErrorHandling();
  }

  private setupToolHandlers(): void {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'convert_totalsegmentator_model',
            description: 'Convert TotalSegmentator PyTorch model to CoreML with medical imaging optimizations for iOS 18+',
            inputSchema: {
              type: 'object',
              properties: {
                modelPath: {
                  type: 'string',
                  description: 'Absolute path to the TotalSegmentator PyTorch model file (.pth or .pt)'
                },
                outputPath: {
                  type: 'string',
                  description: 'Output path for the converted CoreML model (.mlpackage)'
                },
                variant: {
                  type: 'string',
                  description: 'TotalSegmentator model variant',
                  enum: ['1.5mm', '3mm'],
                  default: '3mm'
                },
                deviceTarget: {
                  type: 'string',
                  description: 'Target device for optimization',
                  enum: ['iPhone16,2', 'iPhone15,3', 'iPad14,1', 'MacBookPro18,1'],
                  default: 'iPhone16,2'
                },
                enableOptimizations: {
                  type: 'boolean',
                  description: 'Enable advanced iOS 18+ optimizations (quantization, palettization)',
                  default: true
                }
              },
              required: ['modelPath', 'outputPath']
            }
          },
          {
            name: 'download_totalsegmentator_model',
            description: 'Download TotalSegmentator model from Hugging Face repository',
            inputSchema: {
              type: 'object',
              properties: {
                variant: {
                  type: 'string',
                  description: 'Model variant to download',
                  enum: ['1.5mm', '3mm'],
                  default: '3mm'
                },
                outputDir: {
                  type: 'string',
                  description: 'Directory to save the downloaded model',
                  default: './models'
                }
              }
            }
          },
          {
            name: 'validate_coreml_model',
            description: 'Comprehensive validation of CoreML model for medical imaging deployment',
            inputSchema: {
              type: 'object',
              properties: {
                modelPath: {
                  type: 'string',
                  description: 'Absolute path to the CoreML model (.mlpackage or .mlmodel)'
                },
                deviceCapabilities: {
                  type: 'object',
                  description: 'Target device capabilities for validation',
                  properties: {
                    deviceModel: { type: 'string' },
                    osVersion: { type: 'string' },
                    memoryGB: { type: 'number' },
                    hasNeuralEngine: { type: 'boolean' }
                  }
                },
                medicalContext: {
                  type: 'object',
                  description: 'Medical imaging context for specialized validation',
                  properties: {
                    modality: { 
                      type: 'string',
                      enum: ['CT', 'MR', 'US', 'XR', 'PET', 'SPECT']
                    },
                    anatomyRegions: {
                      type: 'array',
                      items: { type: 'string' }
                    },
                    clinicalUse: {
                      type: 'string',
                      enum: ['diagnostic', 'screening', 'treatment_planning', 'research']
                    }
                  }
                }
              },
              required: ['modelPath']
            }
          },
          {
            name: 'create_conversion_config',
            description: 'Generate optimized conversion configuration for medical imaging models',
            inputSchema: {
              type: 'object',
              properties: {
                modelType: {
                  type: 'string',
                  description: 'Type of medical imaging model',
                  enum: ['totalsegmentator', 'nnunet', 'custom_segmentation', 'classification']
                },
                inputShape: {
                  type: 'array',
                  items: { type: 'number' },
                  description: 'Model input shape [batch, channels, height, width, depth?]'
                },
                modality: {
                  type: 'string',
                  description: 'Medical imaging modality',
                  enum: ['CT', 'MR', 'US', 'XR', 'PET', 'SPECT']
                },
                anatomyRegions: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Anatomical regions covered by the model'
                },
                deploymentTarget: {
                  type: 'string',
                  description: 'iOS deployment target',
                  enum: ['iOS16', 'iOS17', 'iOS18'],
                  default: 'iOS18'
                },
                deviceConstraints: {
                  type: 'object',
                  description: 'Device memory and performance constraints',
                  properties: {
                    maxMemoryMB: { type: 'number', default: 2048 },
                    maxModelSizeMB: { type: 'number', default: 1024 },
                    requireNeuralEngine: { type: 'boolean', default: false }
                  }
                }
              },
              required: ['modelType', 'inputShape', 'modality']
            }
          },
          {
            name: 'optimize_existing_model',
            description: 'Apply iOS 18+ optimizations to existing CoreML model',
            inputSchema: {
              type: 'object',
              properties: {
                modelPath: {
                  type: 'string',
                  description: 'Path to existing CoreML model'
                },
                outputPath: {
                  type: 'string',
                  description: 'Path for optimized model output'
                },
                optimizations: {
                  type: 'object',
                  description: 'Optimization settings',
                  properties: {
                    quantization: {
                      type: 'object',
                      properties: {
                        enabled: { type: 'boolean', default: true },
                        dtype: { 
                          type: 'string', 
                          enum: ['int8', 'int4', 'int3'],
                          default: 'int8'
                        }
                      }
                    },
                    palettization: {
                      type: 'object',
                      properties: {
                        enabled: { type: 'boolean', default: true },
                        nBits: {
                          type: 'number',
                          enum: [2, 3, 4, 6, 8],
                          default: 6
                        }
                      }
                    },
                    pruning: {
                      type: 'object',
                      properties: {
                        enabled: { type: 'boolean', default: false },
                        sparsity: { type: 'number', minimum: 0, maximum: 1, default: 0.1 }
                      }
                    }
                  }
                }
              },
              required: ['modelPath', 'outputPath']
            }
          },
          {
            name: 'assess_device_capabilities',
            description: 'Assess device capabilities for CoreML model deployment',
            inputSchema: {
              type: 'object',
              properties: {
                deviceModel: {
                  type: 'string',
                  description: 'Device model identifier',
                  default: 'iPhone16,2'
                },
                osVersion: {
                  type: 'string',
                  description: 'iOS/macOS version',
                  default: '18.0'
                },
                modelRequirements: {
                  type: 'object',
                  description: 'Model resource requirements',
                  properties: {
                    estimatedSizeMB: { type: 'number' },
                    requires3D: { type: 'boolean' },
                    preferredComputeUnit: {
                      type: 'string',
                      enum: ['cpuOnly', 'cpuAndGPU', 'all', 'cpuAndNeuralEngine']
                    }
                  }
                }
              }
            }
          },
          {
            name: 'batch_convert_models',
            description: 'Convert multiple medical imaging models in batch with shared optimizations',
            inputSchema: {
              type: 'object',
              properties: {
                modelPaths: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Array of model paths to convert'
                },
                outputDirectory: {
                  type: 'string',
                  description: 'Directory for converted models'
                },
                sharedConfig: {
                  type: 'object',
                  description: 'Shared conversion configuration',
                  properties: {
                    deploymentTarget: {
                      type: 'string',
                      enum: ['iOS16', 'iOS17', 'iOS18'],
                      default: 'iOS18'
                    },
                    enableOptimizations: { type: 'boolean', default: true },
                    maxConcurrentConversions: { type: 'number', default: 2 }
                  }
                }
              },
              required: ['modelPaths', 'outputDirectory']
            }
          },
          {
            name: 'generate_ios_integration_code',
            description: 'Generate Swift code for integrating CoreML model into iOS DICOM app',
            inputSchema: {
              type: 'object',
              properties: {
                modelPath: {
                  type: 'string',
                  description: 'Path to the CoreML model'
                },
                modelType: {
                  type: 'string',
                  description: 'Type of medical imaging model',
                  enum: ['totalsegmentator', 'segmentation', 'classification']
                },
                integrationTarget: {
                  type: 'string',
                  description: 'Integration target in iOS app',
                  enum: ['segmentation_service', 'view_controller', 'metal_renderer'],
                  default: 'segmentation_service'
                },
                includePreprocessing: {
                  type: 'boolean',
                  description: 'Include DICOM preprocessing code',
                  default: true
                }
              },
              required: ['modelPath', 'modelType']
            }
          }
        ] as Tool[]
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;
      const typedArgs = args as any;

      try {
        switch (name) {
          case 'convert_totalsegmentator_model':
            return await this.convertTotalSegmentatorModel(typedArgs);

          case 'download_totalsegmentator_model':
            return await this.downloadTotalSegmentatorModel(typedArgs);

          case 'validate_coreml_model':
            return await this.validateCoreMLModel(typedArgs);

          case 'create_conversion_config':
            return await this.createConversionConfig(typedArgs);

          case 'optimize_existing_model':
            return await this.optimizeExistingModel(typedArgs);

          case 'assess_device_capabilities':
            return await this.assessDeviceCapabilities(typedArgs);

          case 'batch_convert_models':
            return await this.batchConvertModels(typedArgs);

          case 'generate_ios_integration_code':
            return await this.generateiOSIntegrationCode(typedArgs);

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify({
                success: false,
                error: (error as Error).message,
                tool: name
              }, null, 2)
            }
          ]
        };
      }
    });
  }

  private setupErrorHandling(): void {
    this.server.onerror = (error) => {
      console.error('[CoreML Conversion MCP Server Error]:', error);
    };

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  // Tool implementation methods

  private async convertTotalSegmentatorModel(args: any) {
    const { modelPath, outputPath, variant = '3mm', deviceTarget = 'iPhone16,2', enableOptimizations = true } = args;

    // Assess device capabilities
    const deviceCapabilities = ConversionUtils.assessDeviceCapabilities(deviceTarget);

    // Perform conversion
    const result = await this.totalSegmentatorConverter.convertTotalSegmentatorModel(
      modelPath,
      outputPath,
      variant,
      enableOptimizations ? deviceCapabilities : undefined
    );

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: result.success,
            conversion_result: result,
            device_target: deviceTarget,
            optimizations_enabled: enableOptimizations,
            summary: {
              model_path: result.modelPath,
              success: result.success,
              recommendations: result.recommendations,
              errors: result.errors,
              warnings: result.warnings
            }
          }, null, 2)
        }
      ]
    };
  }

  private async downloadTotalSegmentatorModel(args: any) {
    const { variant = '3mm', outputDir = './models' } = args;

    try {
      const modelPath = await this.totalSegmentatorConverter.downloadTotalSegmentatorModel(variant, outputDir);

      return {
        content: [
          {
            type: 'text' as const,
            text: JSON.stringify({
              success: true,
              downloaded_model_path: modelPath,
              variant: variant,
              output_directory: outputDir,
              next_steps: [
                'Model downloaded successfully',
                'Use convert_totalsegmentator_model to convert to CoreML',
                'Validate the converted model before deployment'
              ]
            }, null, 2)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text' as const,
            text: JSON.stringify({
              success: false,
              error: (error as Error).message,
              suggestion: 'Check internet connection and Hugging Face repository access'
            }, null, 2)
          }
        ]
      };
    }
  }

  private async validateCoreMLModel(args: any) {
    const { modelPath, deviceCapabilities, medicalContext } = args;

    const validation = await this.modelValidator.validateModel(
      modelPath,
      deviceCapabilities,
      medicalContext
    );

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: validation.isValid,
            validation_result: validation,
            summary: {
              is_valid: validation.isValid,
              error_count: validation.errors.length,
              warning_count: validation.warnings.length,
              medical_compliant: validation.medicalCompliance.dicomCompatible,
              performance_ready: Object.values(validation.performanceTests).every(Boolean)
            }
          }, null, 2)
        }
      ]
    };
  }

  private async createConversionConfig(args: any) {
    const {
      modelType,
      inputShape,
      modality,
      anatomyRegions = [],
      deploymentTarget = 'iOS18',
      deviceConstraints = {}
    } = args;

    const deviceCapabilities = ConversionUtils.assessDeviceCapabilities();
    
    // Create medical imaging context
    const medicalContext = {
      modality,
      anatomy: anatomyRegions,
      clinicalUse: 'diagnostic' as const,
      dataType: 'DICOM' as const,
      inputShape,
      outputClasses: anatomyRegions.length || 104, // Default to TotalSegmentator classes
      outputType: 'mask' as const,
      normalization: {
        mean: modality === 'CT' ? [0.0] : [0.485, 0.456, 0.406],
        std: modality === 'CT' ? [1.0] : [0.229, 0.224, 0.225]
      },
      inputRange: {
        min: modality === 'CT' ? -1000 : 0,
        max: modality === 'CT' ? 3000 : 255
      },
      requires3D: inputShape.length > 4,
      isMultiOrgan: anatomyRegions.length > 5
    };

    const optimizations = ConversionUtils.generateOptimizationRecommendations(
      { medicalContext } as ModelConversionConfig,
      deviceCapabilities
    );

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            conversion_config: {
              modelType,
              deploymentTarget,
              medicalContext,
              optimizations,
              deviceCapabilities
            },
            recommendations: [
              `Configure for ${modality} medical imaging`,
              `Optimized for ${deploymentTarget} deployment`,
              `${anatomyRegions.length} anatomical regions configured`,
              'Review normalization parameters for your data',
              'Test on target devices before deployment'
            ]
          }, null, 2)
        }
      ]
    };
  }

  private async optimizeExistingModel(args: any) {
    const { modelPath, outputPath, optimizations = {} } = args;

    // Generate optimization script
    const optimizationScript = this.generateOptimizationScript(modelPath, outputPath, optimizations);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            optimization_script: optimizationScript,
            applied_optimizations: optimizations,
            next_steps: [
              'Run the generated Python script to apply optimizations',
              'Validate the optimized model',
              'Test performance on target devices'
            ]
          }, null, 2)
        }
      ]
    };
  }

  private async assessDeviceCapabilities(args: any) {
    const { deviceModel = 'iPhone16,2', osVersion = '18.0', modelRequirements = {} } = args;

    const capabilities = ConversionUtils.assessDeviceCapabilities(deviceModel, osVersion);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            device_capabilities: capabilities,
            compatibility_assessment: {
              neural_engine_compatible: capabilities.neuralEngine.available,
              memory_sufficient: capabilities.memory.total >= (modelRequirements.estimatedSizeMB || 0) / 1024,
              recommended_optimizations: capabilities.recommendedOptimizations,
              preferred_compute_unit: capabilities.preferredComputeUnit
            }
          }, null, 2)
        }
      ]
    };
  }

  private async batchConvertModels(args: any) {
    const { modelPaths, outputDirectory, sharedConfig = {} } = args;

    const batchConfig = {
      models: modelPaths.map((path: string, index: number) => ({
        sourcePath: path,
        targetPath: `${outputDirectory}/model_${index}.mlpackage`,
        modelName: `BatchModel_${index}`,
        ...sharedConfig
      })),
      parallelConversions: sharedConfig.maxConcurrentConversions || 2,
      continueOnError: true,
      outputDirectory,
      sharedOptimizations: {},
      generateReport: true
    };

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            batch_configuration: batchConfig,
            estimated_time: ConversionUtils.estimateConversionTime({
              medicalContext: { inputShape: [1, 1, 256, 256] }
            } as ModelConversionConfig) * modelPaths.length,
            next_steps: [
              `${modelPaths.length} models configured for batch conversion`,
              'Execute batch conversion with generated configuration',
              'Monitor progress and validate results'
            ]
          }, null, 2)
        }
      ]
    };
  }

  private async generateiOSIntegrationCode(args: any) {
    const { modelPath, modelType, integrationTarget = 'segmentation_service', includePreprocessing = true } = args;

    const integrationCode = this.generateSwiftIntegrationCode(modelPath, modelType, integrationTarget, includePreprocessing);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            swift_integration_code: integrationCode,
            integration_target: integrationTarget,
            includes_preprocessing: includePreprocessing,
            implementation_notes: [
              'Add the generated code to your iOS DICOM project',
              'Ensure CoreML framework is imported',
              'Test with actual DICOM data',
              'Handle memory management for large models',
              'Implement proper error handling'
            ]
          }, null, 2)
        }
      ]
    };
  }

  // Helper methods

  private generateOptimizationScript(modelPath: string, outputPath: string, optimizations: any): string {
    return `#!/usr/bin/env python3
import coremltools as ct
import coremltools.optimize.coreml as cto

# Load existing CoreML model
model = ct.models.MLModel("${modelPath}")

# Apply optimizations
${optimizations.quantization?.enabled ? `
# Quantization
config = cto.OptimizationConfig(
    global_config=cto.OpLinearQuantizerConfig(
        mode="linear_symmetric",
        dtype="${optimizations.quantization.dtype || 'int8'}"
    )
)
model = cto.linear_quantize_weights(model, config)
` : ''}

${optimizations.palettization?.enabled ? `
# Palettization  
config = cto.OptimizationConfig(
    global_config=cto.OpPalettizerConfig(
        nbits=${optimizations.palettization.nBits || 6}
    )
)
model = cto.palettize_weights(model, config)
` : ''}

# Save optimized model
model.save("${outputPath}")
print("Model optimization complete!")
`;
  }

  private generateSwiftIntegrationCode(
    modelPath: string,
    modelType: string,
    integrationTarget: string,
    includePreprocessing: boolean
  ): string {
    
    const modelName = modelPath.split('/').pop()?.replace(/\.[^/.]+$/, '') || 'Model';
    
    return `
import CoreML
import Vision
import Accelerate
${includePreprocessing ? 'import DICOMKit' : ''}

class ${modelName}Service {
    private var model: MLModel?
    private let modelURL: URL
    
    init() {
        // Initialize with CoreML model
        guard let modelURL = Bundle.main.url(forResource: "${modelName}", withExtension: "mlpackage") else {
            fatalError("Could not find ${modelName}.mlpackage in bundle")
        }
        self.modelURL = modelURL
        loadModel()
    }
    
    private func loadModel() {
        do {
            // Configure for optimal performance
            let config = MLModelConfiguration()
            config.computeUnits = .all // Use CPU, GPU, and Neural Engine
            
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
            print("✅ ${modelName} loaded successfully")
        } catch {
            print("❌ Failed to load ${modelName}: \\(error)")
        }
    }
    
    ${includePreprocessing ? `
    // DICOM preprocessing for medical imaging
    func preprocessDICOMImage(_ dicomData: Data) -> MLMultiArray? {
        // Parse DICOM data
        // Apply medical imaging normalization
        // Convert to MLMultiArray format
        // This is a placeholder - implement actual DICOM processing
        return nil
    }
    ` : ''}
    
    ${modelType === 'totalsegmentator' || modelType === 'segmentation' ? `
    // Segmentation inference
    func performSegmentation(on inputData: MLMultiArray) async throws -> MLMultiArray {
        guard let model = self.model else {
            throw CoreMLServiceError.modelNotLoaded
        }
        
        // Create input for the model
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input": MLFeatureValue(multiArray: inputData)
        ])
        
        // Perform inference
        let output = try await model.prediction(from: input)
        
        // Extract segmentation mask
        guard let segmentationMask = output.featureValue(for: "output")?.multiArrayValue else {
            throw CoreMLServiceError.invalidOutput
        }
        
        return segmentationMask
    }
    
    // Post-process segmentation results
    func postProcessSegmentation(_ segmentationMask: MLMultiArray) -> [String: Any] {
        // Convert to anatomical labels
        // Calculate volumes
        // Generate clinical metrics
        return [
            "anatomicalRegions": [],
            "volumes": [:],
            "confidence": 0.0
        ]
    }
    ` : ''}
    
    ${modelType === 'classification' ? `
    // Classification inference
    func performClassification(on inputData: MLMultiArray) async throws -> [String: Double] {
        guard let model = self.model else {
            throw CoreMLServiceError.modelNotLoaded
        }
        
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input": MLFeatureValue(multiArray: inputData)
        ])
        
        let output = try await model.prediction(from: input)
        
        // Extract classification probabilities
        var results: [String: Double] = [:]
        // Process output based on model specifics
        
        return results
    }
    ` : ''}
}

enum CoreMLServiceError: Error {
    case modelNotLoaded
    case invalidInput
    case invalidOutput
    case preprocessingFailed
}

// Extension for DICOM integration
${includePreprocessing ? `
extension ${modelName}Service {
    // Integration with DICOMServiceManager
    func processDICOMStudy(_ study: DICOMStudy) async -> SegmentationResult? {
        // Process DICOM series for segmentation
        // Apply medical imaging preprocessing
        // Return structured results
        return nil
    }
}
` : ''}
`;
  }

  async run(): Promise<void> {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Advanced CoreML Conversion MCP Server running on stdio');
  }
}

// Start the server
const server = new CoreMLConversionServer();
server.run().catch((error) => {
  console.error('Failed to start CoreML Conversion MCP server:', error);
  process.exit(1);
});