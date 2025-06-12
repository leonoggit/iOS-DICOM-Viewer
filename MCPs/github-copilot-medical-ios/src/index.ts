#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

import { CopilotCodeGenerator } from './tools/copilot-code-generator.js';
import { MedicalPromptTemplates } from './tools/medical-prompt-templates.js';
import { IOSOptimizationAdvisor } from './tools/ios-optimization-advisor.js';

// Initialize tool instances
const codeGenerator = new CopilotCodeGenerator();
const promptTemplates = new MedicalPromptTemplates();
const optimizationAdvisor = new IOSOptimizationAdvisor();

// Create server instance
const server = new Server(
  {
    name: 'github-copilot-medical-ios-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      resources: {},
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'generate_medical_ios_code',
        description: 'Generate Swift code optimized for medical imaging and iOS development with GitHub Copilot-style enhanced prompts',
        inputSchema: codeGenerator.getSchema(),
      },
      {
        name: 'get_medical_prompt_template',
        description: 'Get specialized prompt templates for medical imaging development with iOS optimizations',
        inputSchema: promptTemplates.getSchema(),
      },
      {
        name: 'analyze_ios_optimization',
        description: 'Analyze Swift code for iOS-specific optimizations, particularly for medical imaging applications',
        inputSchema: optimizationAdvisor.getSchema(),
      },
    ],
  };
});

// List available resources
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return {
    resources: [
      {
        uri: 'medical-imaging://best-practices',
        name: 'Medical Imaging Best Practices',
        description: 'Comprehensive guide for medical imaging development on iOS',
        mimeType: 'text/markdown',
      },
      {
        uri: 'ios-development://optimization-guide',
        name: 'iOS Medical App Optimization Guide',
        description: 'Performance optimization strategies for medical imaging iOS apps',
        mimeType: 'text/markdown',
      },
      {
        uri: 'dicom-standards://compliance-checklist',
        name: 'DICOM Compliance Checklist',
        description: 'Essential DICOM standards compliance requirements for iOS development',
        mimeType: 'text/markdown',
      },
    ],
  };
});

// Handle resource reading
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const uri = request.params.uri;
  
  switch (uri) {
    case 'medical-imaging://best-practices':
      return {
        contents: [
          {
            uri,
            mimeType: 'text/markdown',
            text: `# Medical Imaging Best Practices for iOS

## DICOM Standards Compliance
- Always validate DICOM conformance with Part 5 data structures
- Implement proper window/level calculations (DICOM Part 14)
- Support standard transfer syntaxes (uncompressed, JPEG, RLE)
- Handle multi-frame datasets correctly

## iOS Memory Management
- Use autoreleasepool for large image processing
- Implement NSCache for medical image caching
- Handle memory warnings gracefully
- Use weak references in closures to prevent retain cycles

## GPU Acceleration with Metal
- Leverage Metal Performance Shaders for image processing
- Implement custom compute shaders for volume rendering
- Optimize buffer management for large datasets
- Support fallback CPU paths

## Clinical Workflow Integration
- Design for physician efficiency and workflow
- Implement proper error handling and user feedback
- Ensure accessibility compliance for clinical users
- Include appropriate medical disclaimers

## Regulatory Compliance
- Follow FDA medical device software guidelines
- Implement HIPAA-compliant data handling
- Maintain audit trails for clinical environments
- Consider IEC 62304 software lifecycle requirements`,
          },
        ],
      };

    case 'ios-development://optimization-guide':
      return {
        contents: [
          {
            uri,
            mimeType: 'text/markdown',
            text: `# iOS Medical App Optimization Guide

## Memory Optimization
### Large Dataset Handling
- Stream DICOM files instead of loading entirely into memory
- Use memory mapping for read-only access to large files
- Implement progressive loading for multi-frame datasets

### Caching Strategy
\`\`\`swift
private let imageCache = NSCache<NSString, UIImage>()
imageCache.countLimit = 50
imageCache.totalCostLimit = 100 * 1024 * 1024  // 100MB
\`\`\`

## Performance Optimization
### Async Processing
\`\`\`swift
await withTaskGroup(of: ProcessedImage.self) { group in
    for dicomFile in files {
        group.addTask {
            await processDICOMFile(dicomFile)
        }
    }
}
\`\`\`

### Metal GPU Acceleration
\`\`\`swift
let gaussianBlur = MPSImageGaussianBlur(device: device, sigma: 2.0)
gaussianBlur.encode(commandBuffer: commandBuffer, 
                   sourceTexture: input, 
                   destinationTexture: output)
\`\`\`

## Battery Optimization
- Use background processing judiciously
- Implement adaptive quality based on device capabilities
- Reduce CPU/GPU usage when app is in background

## Network Optimization
- Implement DICOM Web (WADO-RS) for efficient transfers
- Use compression for non-pixel data
- Cache frequently accessed studies locally`,
          },
        ],
      };

    case 'dicom-standards://compliance-checklist':
      return {
        contents: [
          {
            uri,
            mimeType: 'text/markdown',
            text: `# DICOM Compliance Checklist for iOS Development

## Essential DICOM Parts
- [ ] Part 3: Information Object Definitions
- [ ] Part 5: Data Structures and Encoding
- [ ] Part 6: Data Dictionary
- [ ] Part 10: Media Storage and File Format
- [ ] Part 14: Grayscale Standard Display Function

## Transfer Syntax Support
- [ ] Implicit VR Little Endian (1.2.840.10008.1.2)
- [ ] Explicit VR Little Endian (1.2.840.10008.1.2.1)
- [ ] JPEG Baseline (1.2.840.10008.1.2.4.50)
- [ ] JPEG Lossless (1.2.840.10008.1.2.4.57)
- [ ] RLE Lossless (1.2.840.10008.1.2.5)

## Data Integrity
- [ ] Validate DICOM file headers
- [ ] Verify transfer syntax compatibility
- [ ] Check required data elements
- [ ] Validate pixel data integrity

## Display Compliance
- [ ] Implement GSDF (Grayscale Standard Display Function)
- [ ] Support proper window/level transformations
- [ ] Handle different photometric interpretations
- [ ] Support calibrated display output

## Conformance Statement
- [ ] Document supported SOP Classes
- [ ] Specify transfer syntax support
- [ ] Detail implementation limitations
- [ ] Include testing methodology

## Security and Privacy
- [ ] Implement de-identification capabilities
- [ ] Support secure transport (TLS)
- [ ] Maintain audit logs
- [ ] Follow HIPAA guidelines for PHI`,
          },
        ],
      };

    default:
      throw new Error(`Unknown resource: ${uri}`);
  }
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'generate_medical_ios_code':
        const codeResult = await codeGenerator.generateCode(args as any);
        return {
          content: [
            {
              type: 'text',
              text: `## Generated Code

\`\`\`swift
${codeResult.code}
\`\`\`

## Explanation
${codeResult.explanation}

## Best Practices Applied
${codeResult.bestPractices.map(practice => `- ${practice}`).join('\n')}

${codeResult.medicalCompliance ? `
## Medical Compliance
- Standard: ${codeResult.medicalCompliance.standard}
- Level: ${codeResult.medicalCompliance.level}
- Audit Trail: ${codeResult.medicalCompliance.auditTrail ? 'Enabled' : 'Disabled'}
` : ''}

${codeResult.iosOptimization ? `
## iOS Optimizations
- Memory Efficient: ${codeResult.iosOptimization.memoryEfficient ? 'Yes' : 'No'}
- Metal Compatible: ${codeResult.iosOptimization.metalCompatible ? 'Yes' : 'No'}
- Background Processing: ${codeResult.iosOptimization.backgroundProcessing ? 'Yes' : 'No'}
` : ''}`,
            },
          ],
        };

      case 'get_medical_prompt_template':
        const templateResult = await promptTemplates.getPromptTemplate(args as any);
        return {
          content: [
            {
              type: 'text',
              text: `## Prompt Template

${templateResult.template}

## Context
${templateResult.context}

## Examples
${templateResult.examples.map(example => `- ${example}`).join('\n')}

## Best Practices
${templateResult.bestPractices.map(practice => `- ${practice}`).join('\n')}`,
            },
          ],
        };

      case 'analyze_ios_optimization':
        const analysisResult = await optimizationAdvisor.analyzeCode(args as any);
        return {
          content: [
            {
              type: 'text',
              text: `## Code Analysis Results

### Issues Found
${analysisResult.issues.map(issue => `
**${issue.severity.toUpperCase()} - ${issue.category}**
- Issue: ${issue.issue}
- Recommendation: ${issue.recommendation}
${issue.codeExample ? `
\`\`\`swift
${issue.codeExample}
\`\`\`` : ''}
`).join('\n')}

### Optimization Suggestions
${analysisResult.optimizations.map(opt => `
**${opt.type}**
- Benefit: ${opt.benefit}
- Implementation: ${opt.implementation}
\`\`\`swift
${opt.codeExample}
\`\`\`
`).join('\n')}

### Medical-Specific Advice
${analysisResult.medicalSpecificAdvice.map(advice => `- ${advice}`).join('\n')}`,
            },
          ],
        };

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});