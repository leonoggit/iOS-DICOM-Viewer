#!/usr/bin/env node

/**
 * Custom DICOM MCP Server
 * Provides specialized medical imaging functionality for Claude Code
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';

// Import our DICOM tools
import { DICOMMetadataParser } from './tools/dicom-metadata-parser.js';
import { MedicalFileDetector, MedicalFileDetectionResult } from './tools/medical-file-detector.js';
import { DICOMComplianceChecker, DetailedComplianceResult } from './tools/dicom-compliance-checker.js';
import { PixelDataAnalyzer, PixelDataAnalysis } from './tools/pixel-data-analyzer.js';
import { MedicalTerminologyLookup, TerminologyLookupResult } from './tools/medical-terminology-lookup.js';

// Import types
import { DICOMMetadata, DICOMValidationResult, DICOMFileInfo } from './types/dicom.js';

// Import error handling
import { errorHandler, ErrorCode } from './utils/error-handler.js';

class DICOMServer {
  private server: Server;
  private metadataParser: DICOMMetadataParser;
  private fileDetector: MedicalFileDetector;
  private complianceChecker: DICOMComplianceChecker;
  private pixelAnalyzer: PixelDataAnalyzer;
  private terminologyLookup: MedicalTerminologyLookup;

  constructor() {
    this.server = new Server(
      {
        name: 'custom-dicom-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    // Initialize DICOM tools
    this.metadataParser = new DICOMMetadataParser();
    this.fileDetector = new MedicalFileDetector();
    this.complianceChecker = new DICOMComplianceChecker();
    this.pixelAnalyzer = new PixelDataAnalyzer();
    this.terminologyLookup = new MedicalTerminologyLookup();

    this.setupToolHandlers();
    this.setupErrorHandling();
  }

  private setupToolHandlers(): void {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'parse_dicom_metadata',
            description: 'Parse DICOM file and extract comprehensive metadata including patient, study, series, and image information',
            inputSchema: {
              type: 'object',
              properties: {
                filePath: {
                  type: 'string',
                  description: 'Absolute path to the DICOM file'
                }
              },
              required: ['filePath']
            }
          },
          {
            name: 'detect_medical_file_type',
            description: 'Detect and analyze medical imaging file types (DICOM, NIfTI, ANALYZE, etc.) with comprehensive characteristics',
            inputSchema: {
              type: 'object',
              properties: {
                filePath: {
                  type: 'string',
                  description: 'Absolute path to the medical imaging file'
                }
              },
              required: ['filePath']
            }
          },
          {
            name: 'batch_detect_medical_files',
            description: 'Analyze multiple medical imaging files in batch for efficient processing',
            inputSchema: {
              type: 'object',
              properties: {
                filePaths: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Array of absolute file paths to analyze'
                }
              },
              required: ['filePaths']
            }
          },
          {
            name: 'check_dicom_compliance',
            description: 'Validate DICOM file compliance against standard profiles and generate detailed compliance report',
            inputSchema: {
              type: 'object',
              properties: {
                filePath: {
                  type: 'string',
                  description: 'Absolute path to the DICOM file'
                },
                profile: {
                  type: 'string',
                  description: 'Optional specific compliance profile to check against',
                  enum: ['CT_IMAGE', 'MR_IMAGE', 'SC_IMAGE']
                }
              },
              required: ['filePath']
            }
          },
          {
            name: 'analyze_pixel_data',
            description: 'Comprehensive pixel data analysis including statistics, quality metrics, and recommendations',
            inputSchema: {
              type: 'object',
              properties: {
                filePath: {
                  type: 'string',
                  description: 'Absolute path to the DICOM file'
                },
                modality: {
                  type: 'string',
                  description: 'Optional imaging modality for specialized analysis',
                  enum: ['CT', 'MR', 'US', 'CR', 'DR', 'XA']
                }
              },
              required: ['filePath']
            }
          },
          {
            name: 'lookup_medical_terminology',
            description: 'Look up medical terminology, anatomical regions, and imaging procedures',
            inputSchema: {
              type: 'object',
              properties: {
                term: {
                  type: 'string',
                  description: 'Medical term to look up'
                }
              },
              required: ['term']
            }
          },
          {
            name: 'validate_terminology_code',
            description: 'Validate medical terminology codes (SNOMED, DCM, ICD-10, etc.)',
            inputSchema: {
              type: 'object',
              properties: {
                code: {
                  type: 'string',
                  description: 'Medical terminology code to validate'
                },
                scheme: {
                  type: 'string',
                  description: 'Coding scheme (SNM3, DCM, UCUM, ICD10)',
                  enum: ['SNM3', 'SNOMED', 'DCM', 'UCUM', 'ICD10']
                }
              },
              required: ['code', 'scheme']
            }
          },
          {
            name: 'get_anatomical_regions',
            description: 'Get list of anatomical regions, optionally filtered by body part',
            inputSchema: {
              type: 'object',
              properties: {
                bodyPart: {
                  type: 'string',
                  description: 'Optional body part filter (e.g., "head", "chest", "abdomen")'
                }
              }
            }
          },
          {
            name: 'get_imaging_procedures',
            description: 'Get imaging procedures, optionally filtered by modality',
            inputSchema: {
              type: 'object',
              properties: {
                modality: {
                  type: 'string',
                  description: 'Optional modality filter (CT, MR, US, etc.)'
                }
              }
            }
          },
          {
            name: 'suggest_imaging_protocol',
            description: 'Suggest appropriate imaging protocols based on clinical indication and modality',
            inputSchema: {
              type: 'object',
              properties: {
                indication: {
                  type: 'string',
                  description: 'Clinical indication (e.g., "headache", "chest pain")'
                },
                modality: {
                  type: 'string',
                  description: 'Imaging modality (CT, MR, US, etc.)'
                }
              },
              required: ['indication', 'modality']
            }
          },
          {
            name: 'get_compliance_profiles',
            description: 'Get available DICOM compliance profiles',
            inputSchema: {
              type: 'object',
              properties: {}
            }
          },
          {
            name: 'extract_dicom_pixel_data',
            description: 'Extract and analyze pixel data from DICOM file with detailed statistics',
            inputSchema: {
              type: 'object',
              properties: {
                filePath: {
                  type: 'string',
                  description: 'Absolute path to the DICOM file'
                },
                analyzeQuality: {
                  type: 'boolean',
                  description: 'Whether to perform quality analysis (default: true)'
                }
              },
              required: ['filePath']
            }
          }
        ] as Tool[]
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;
      const typedArgs = args as any; // Type assertion for arguments

      try {
        switch (name) {
          case 'parse_dicom_metadata':
            await errorHandler.validateFilePath(typedArgs.filePath);
            return await errorHandler.wrapAsync(
              () => this.parseDICOMMetadata(typedArgs.filePath),
              `parse_dicom_metadata: ${typedArgs.filePath}`
            );

          case 'detect_medical_file_type':
            await errorHandler.validateFilePath(typedArgs.filePath);
            return await errorHandler.wrapAsync(
              () => this.detectMedicalFileType(typedArgs.filePath),
              `detect_medical_file_type: ${typedArgs.filePath}`
            );

          case 'batch_detect_medical_files':
            await errorHandler.validateFilePaths(typedArgs.filePaths);
            return await errorHandler.wrapAsync(
              () => this.batchDetectMedicalFiles(typedArgs.filePaths),
              `batch_detect_medical_files: ${typedArgs.filePaths.length} files`,
              60000 // Longer timeout for batch operations
            );

          case 'check_dicom_compliance':
            await errorHandler.validateFilePath(typedArgs.filePath);
            return await errorHandler.wrapAsync(
              () => this.checkDICOMCompliance(typedArgs.filePath, typedArgs.profile),
              `check_dicom_compliance: ${typedArgs.filePath}`
            );

          case 'analyze_pixel_data':
            await errorHandler.validateFilePath(typedArgs.filePath);
            return await errorHandler.wrapAsync(
              () => this.analyzePixelData(typedArgs.filePath, typedArgs.modality),
              `analyze_pixel_data: ${typedArgs.filePath}`,
              45000 // Longer timeout for pixel analysis
            );

          case 'lookup_medical_terminology':
            if (!typedArgs.term || typeof typedArgs.term !== 'string') {
              throw errorHandler.createError(
                ErrorCode.INVALID_PARAMETERS,
                'Term parameter is required and must be a string',
                'lookup_medical_terminology'
              );
            }
            return await this.lookupMedicalTerminology(typedArgs.term);

          case 'validate_terminology_code':
            if (!typedArgs.code || !typedArgs.scheme) {
              throw errorHandler.createError(
                ErrorCode.INVALID_PARAMETERS,
                'Code and scheme parameters are required',
                'validate_terminology_code'
              );
            }
            return await this.validateTerminologyCode(typedArgs.code, typedArgs.scheme);

          case 'get_anatomical_regions':
            return await this.getAnatomicalRegions(typedArgs.bodyPart);

          case 'get_imaging_procedures':
            return await this.getImagingProcedures(typedArgs.modality);

          case 'suggest_imaging_protocol':
            if (!typedArgs.indication || !typedArgs.modality) {
              throw errorHandler.createError(
                ErrorCode.INVALID_PARAMETERS,
                'Indication and modality parameters are required',
                'suggest_imaging_protocol'
              );
            }
            return await this.suggestImagingProtocol(typedArgs.indication, typedArgs.modality);

          case 'get_compliance_profiles':
            return await this.getComplianceProfiles();

          case 'extract_dicom_pixel_data':
            await errorHandler.validateFilePath(typedArgs.filePath);
            return await errorHandler.wrapAsync(
              () => this.extractDICOMPixelData(typedArgs.filePath, typedArgs.analyzeQuality),
              `extract_dicom_pixel_data: ${typedArgs.filePath}`,
              45000 // Longer timeout for pixel extraction
            );

          default:
            throw errorHandler.createError(
              ErrorCode.INVALID_PARAMETERS,
              `Unknown tool: ${name}`,
              'tool_handler',
              { toolName: name }
            );
        }
      } catch (error) {
        return errorHandler.handleError(error, `tool_execution: ${name}`).response;
      }
    });
  }

  private setupErrorHandling(): void {
    this.server.onerror = (error) => {
      console.error('[DICOM MCP Server Error]:', error);
    };

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  // Tool implementation methods
  private async parseDICOMMetadata(filePath: string) {
    const result = await this.metadataParser.parseDICOMFile(filePath);
    
    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            metadata: result.metadata,
            validation: result.validation,
            fileInfo: result.fileInfo,
            summary: {
              patient: result.metadata.patientName || 'Unknown',
              study: result.metadata.studyDescription || 'Unknown',
              modality: result.metadata.modality || 'Unknown',
              dimensions: result.metadata.rows && result.metadata.columns 
                ? `${result.metadata.columns}x${result.metadata.rows}` 
                : 'Unknown',
              isValid: result.validation.isValid,
              errorCount: result.validation.errors.length,
              warningCount: result.validation.warnings.length
            }
          }, null, 2)
        }
      ]
    };
  }

  private async detectMedicalFileType(filePath: string) {
    const result = await this.fileDetector.detectFileType(filePath);
    
    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            detection: result,
            summary: {
              filename: result.filename,
              fileType: result.fileType,
              confidence: `${Math.round(result.confidence * 100)}%`,
              size: result.formattedSize,
              hasRecommendations: result.recommendations.length > 0,
              hasWarnings: result.warnings.length > 0
            }
          }, null, 2)
        }
      ]
    };
  }

  private async batchDetectMedicalFiles(filePaths: string[]) {
    const results = await this.fileDetector.batchDetectFiles(filePaths);
    
    const summary = {
      totalFiles: results.length,
      byType: {} as { [key: string]: number },
      totalSize: 0,
      averageConfidence: 0
    };

    for (const result of results) {
      summary.byType[result.fileType] = (summary.byType[result.fileType] || 0) + 1;
      summary.totalSize += result.size;
      summary.averageConfidence += result.confidence;
    }

    summary.averageConfidence = summary.averageConfidence / results.length;

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            results,
            summary
          }, null, 2)
        }
      ]
    };
  }

  private async checkDICOMCompliance(filePath: string, profile?: string) {
    const parseResult = await this.metadataParser.parseDICOMFile(filePath);
    
    let complianceResult: DetailedComplianceResult;
    if (profile) {
      const profileData = this.complianceChecker.getProfileDetails(profile);
      if (!profileData) {
        throw new Error(`Unknown compliance profile: ${profile}`);
      }
      complianceResult = this.complianceChecker.validateAgainstProfile(parseResult.metadata, profileData);
    } else {
      complianceResult = this.complianceChecker.checkCompliance(parseResult.metadata);
    }

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            compliance: complianceResult,
            summary: {
              profile: complianceResult.profile,
              sopClass: complianceResult.sopClassName,
              score: `${complianceResult.complianceScore}%`,
              isCompliant: complianceResult.isValid,
              errorCount: complianceResult.errors.length,
              warningCount: complianceResult.warnings.length,
              requiredTagsPresent: `${complianceResult.tagCompliance.required.present}/${complianceResult.tagCompliance.required.total}`,
              conditionalTagsPresent: `${complianceResult.tagCompliance.conditional.present}/${complianceResult.tagCompliance.conditional.applicable}`
            }
          }, null, 2)
        }
      ]
    };
  }

  private async analyzePixelData(filePath: string, modality?: string) {
    const parseResult = await this.metadataParser.parseDICOMFile(filePath);
    const pixelData = this.metadataParser.extractPixelData(parseResult.metadata as any);
    
    if (!pixelData) {
      throw new Error('No pixel data found in DICOM file');
    }

    const analysis = this.pixelAnalyzer.analyzePixelData(pixelData, modality, parseResult.metadata);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            analysis,
            summary: {
              dimensions: `${pixelData.columns}x${pixelData.rows}`,
              bitsAllocated: pixelData.bitsAllocated,
              pixelRange: `${analysis.statistics.min} - ${analysis.statistics.max}`,
              meanValue: Math.round(analysis.statistics.mean),
              contrast: `${Math.round(analysis.qualityMetrics.contrast * 100)}%`,
              noiseLevel: `${Math.round(analysis.qualityMetrics.noise * 100)}%`,
              artifactCount: analysis.artifacts.length,
              recommendationCount: analysis.recommendations.processingRecommendations.length
            }
          }, null, 2)
        }
      ]
    };
  }

  private async lookupMedicalTerminology(term: string) {
    const result = this.terminologyLookup.lookupTerm(term);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            lookup: result,
            summary: {
              term: result.term,
              category: result.category,
              confidence: `${Math.round(result.confidence * 100)}%`,
              definitionCount: result.definitions.length,
              relatedTermCount: result.relatedTerms.length
            }
          }, null, 2)
        }
      ]
    };
  }

  private async validateTerminologyCode(code: string, scheme: string) {
    const result = this.terminologyLookup.validateTerminologyCode(code, scheme);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            validation: result,
            summary: {
              code,
              scheme: result.scheme,
              isValid: result.isValid,
              hasMeaning: !!result.meaning
            }
          }, null, 2)
        }
      ]
    };
  }

  private async getAnatomicalRegions(bodyPart?: string) {
    const regions = this.terminologyLookup.getAnatomicalRegions(bodyPart);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            regions,
            summary: {
              count: regions.length,
              bodyPartFilter: bodyPart || 'none',
              categories: [...new Set(regions.map(r => r.category))]
            }
          }, null, 2)
        }
      ]
    };
  }

  private async getImagingProcedures(modality?: string) {
    const procedures = this.terminologyLookup.getImagingProcedures(modality);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            procedures,
            summary: {
              count: procedures.length,
              modalityFilter: modality || 'none',
              modalities: [...new Set(procedures.map(p => p.modality))]
            }
          }, null, 2)
        }
      ]
    };
  }

  private async suggestImagingProtocol(indication: string, modality: string) {
    const suggestions = this.terminologyLookup.suggestImagingProtocol(indication, modality);

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            suggestions,
            summary: {
              indication,
              modality,
              protocolCount: suggestions.length,
              hasContraindications: suggestions.some(s => s.contraindications.length > 0)
            }
          }, null, 2)
        }
      ]
    };
  }

  private async getComplianceProfiles() {
    const profiles = this.complianceChecker.getAvailableProfiles();

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            profiles,
            profileDetails: profiles.map(name => ({
              name,
              details: this.complianceChecker.getProfileDetails(name)
            }))
          }, null, 2)
        }
      ]
    };
  }

  private async extractDICOMPixelData(filePath: string, analyzeQuality: boolean = true) {
    const parseResult = await this.metadataParser.parseDICOMFile(filePath);
    const pixelData = this.metadataParser.extractPixelData(parseResult.metadata as any);
    
    if (!pixelData) {
      throw new Error('No pixel data found in DICOM file');
    }

    const statistics = this.pixelAnalyzer.analyzePixelData(pixelData).statistics;
    const histogram = this.pixelAnalyzer.analyzeHistogram(pixelData);

    let qualityMetrics = null;
    if (analyzeQuality) {
      qualityMetrics = this.pixelAnalyzer.analyzePixelData(pixelData).qualityMetrics;
    }

    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({
            success: true,
            pixelData: {
              dimensions: {
                rows: pixelData.rows,
                columns: pixelData.columns,
                samplesPerPixel: pixelData.samplesPerPixel
              },
              encoding: {
                bitsAllocated: pixelData.bitsAllocated,
                bitsStored: pixelData.bitsStored,
                pixelRepresentation: pixelData.pixelRepresentation,
                photometricInterpretation: pixelData.photometricInterpretation
              },
              statistics,
              histogram,
              qualityMetrics
            },
            summary: {
              totalPixels: pixelData.rows * pixelData.columns,
              dataType: pixelData.bitsAllocated <= 8 ? 'uint8' : 
                       pixelData.pixelRepresentation === 1 ? 'int16' : 'uint16',
              dynamicRange: statistics.max - statistics.min,
              hasQualityAnalysis: analyzeQuality
            }
          }, null, 2)
        }
      ]
    };
  }

  async run(): Promise<void> {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Custom DICOM MCP Server running on stdio');
  }
}

// Start the server
const server = new DICOMServer();
server.run().catch((error) => {
  console.error('Failed to start DICOM MCP server:', error);
  process.exit(1);
});