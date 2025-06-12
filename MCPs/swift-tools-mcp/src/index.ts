#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  McpError,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import * as fs from 'fs-extra';
import * as path from 'path';
import { execSync, spawn } from 'child_process';
import * as plist from 'plist';
import * as xml2js from 'xml2js';
import glob from 'fast-glob';

// Import tool implementations
import { XcodeProjectManager } from './tools/xcode-project-manager.js';
import { SwiftCodeAnalyzer } from './tools/swift-code-analyzer.js';
import { iOSDeploymentValidator } from './tools/ios-deployment-validator.js';
import { MetalShaderValidator } from './tools/metal-shader-validator.js';
import { iOSMemoryProfiler } from './tools/ios-memory-profiler.js';
import { SimulatorManager } from './tools/simulator-manager.js';
import { SwiftUIBestPractices } from './tools/swiftui-best-practices.js';

interface IOSProjectInfo {
  projectPath: string;
  scheme?: string;
  target?: string;
  deploymentTarget?: string;
  buildConfiguration?: string;
}

class SwiftToolsMCPServer {
  private server: Server;
  private xcodeProjectManager: XcodeProjectManager;
  private swiftCodeAnalyzer: SwiftCodeAnalyzer;
  private iosDeploymentValidator: iOSDeploymentValidator;
  private metalShaderValidator: MetalShaderValidator;
  private iosMemoryProfiler: iOSMemoryProfiler;
  private simulatorManager: SimulatorManager;
  private swiftUIBestPractices: SwiftUIBestPractices;

  constructor() {
    this.server = new Server(
      {
        name: 'swift-tools-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          resources: {},
          tools: {},
        },
      }
    );

    // Initialize tool managers
    this.xcodeProjectManager = new XcodeProjectManager();
    this.swiftCodeAnalyzer = new SwiftCodeAnalyzer();
    this.iosDeploymentValidator = new iOSDeploymentValidator();
    this.metalShaderValidator = new MetalShaderValidator();
    this.iosMemoryProfiler = new iOSMemoryProfiler();
    this.simulatorManager = new SimulatorManager();
    this.swiftUIBestPractices = new SwiftUIBestPractices();

    this.setupHandlers();
  }

  private setupHandlers() {
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => ({
      resources: [
        {
          uri: 'swift://project-info',
          mimeType: 'application/json',
          name: 'iOS Project Information',
          description: 'Current iOS project configuration and status',
        },
        {
          uri: 'swift://build-settings',
          mimeType: 'application/json',
          name: 'Xcode Build Settings',
          description: 'Current build configuration and settings',
        },
        {
          uri: 'swift://simulators',
          mimeType: 'application/json',
          name: 'iOS Simulators',
          description: 'Available iOS simulators and their status',
        },
      ],
    }));

    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const uri = request.params.uri;
      
      try {
        switch (uri) {
          case 'swift://project-info':
            return {
              contents: [{
                uri,
                mimeType: 'application/json',
                text: JSON.stringify(await this.getProjectInfo(), null, 2),
              }],
            };
          
          case 'swift://build-settings':
            return {
              contents: [{
                uri,
                mimeType: 'application/json',
                text: JSON.stringify(await this.getBuildSettings(), null, 2),
              }],
            };
          
          case 'swift://simulators':
            return {
              contents: [{
                uri,
                mimeType: 'application/json',
                text: JSON.stringify(await this.simulatorManager.listSimulators(), null, 2),
              }],
            };
          
          default:
            throw new McpError(ErrorCode.InvalidRequest, `Unknown resource: ${uri}`);
        }
      } catch (error) {
        throw new McpError(ErrorCode.InternalError, `Failed to read resource: ${error}`);
      }
    });

    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        // Xcode Project Management Tools
        {
          name: 'analyze_xcode_project',
          description: 'Analyze Xcode project structure, targets, schemes, and configurations',
          inputSchema: {
            type: 'object',
            properties: {
              projectPath: {
                type: 'string',
                description: 'Path to the .xcodeproj or .xcworkspace file',
              },
              analyzeTargets: {
                type: 'boolean',
                description: 'Include detailed target analysis',
                default: true,
              },
              analyzeSchemes: {
                type: 'boolean',
                description: 'Include scheme analysis',
                default: true,
              },
            },
            required: ['projectPath'],
          },
        },
        
        {
          name: 'validate_build_settings',
          description: 'Validate Xcode build settings for iOS deployment and best practices',
          inputSchema: {
            type: 'object',
            properties: {
              projectPath: { type: 'string', description: 'Path to Xcode project' },
              target: { type: 'string', description: 'Specific target to validate' },
              configuration: { type: 'string', description: 'Build configuration (Debug/Release)' },
            },
            required: ['projectPath'],
          },
        },

        // Swift Code Analysis Tools
        {
          name: 'analyze_swift_code',
          description: 'Analyze Swift code for syntax, best practices, and potential issues',
          inputSchema: {
            type: 'object',
            properties: {
              filePath: { type: 'string', description: 'Path to Swift file or directory' },
              checkSyntax: { type: 'boolean', description: 'Check syntax validity', default: true },
              checkStyle: { type: 'boolean', description: 'Check Swift style guidelines', default: true },
              checkPerformance: { type: 'boolean', description: 'Check for performance issues', default: true },
            },
            required: ['filePath'],
          },
        },

        {
          name: 'compile_swift_file',
          description: 'Compile a Swift file and check for compilation errors',
          inputSchema: {
            type: 'object',
            properties: {
              filePath: { type: 'string', description: 'Path to Swift file' },
              target: { type: 'string', description: 'iOS deployment target version' },
              sdk: { type: 'string', description: 'SDK to use (iphoneos, iphonesimulator)', default: 'iphonesimulator' },
            },
            required: ['filePath'],
          },
        },

        // iOS Deployment Tools
        {
          name: 'validate_ios_deployment',
          description: 'Validate iOS deployment configuration and requirements',
          inputSchema: {
            type: 'object',
            properties: {
              projectPath: { type: 'string', description: 'Path to Xcode project' },
              targetVersion: { type: 'string', description: 'Target iOS version' },
              validateCapabilities: { type: 'boolean', description: 'Validate app capabilities', default: true },
            },
            required: ['projectPath'],
          },
        },

        // Metal Shader Tools
        {
          name: 'compile_metal_shaders',
          description: 'Compile and validate Metal shaders for iOS',
          inputSchema: {
            type: 'object',
            properties: {
              shaderPath: { type: 'string', description: 'Path to .metal file or directory' },
              target: { type: 'string', description: 'Metal target (ios, ios-simulator)', default: 'ios' },
              optimizationLevel: { type: 'string', description: 'Optimization level (none, speed, size)', default: 'speed' },
            },
            required: ['shaderPath'],
          },
        },

        {
          name: 'analyze_metal_performance',
          description: 'Analyze Metal shader performance and provide optimization suggestions',
          inputSchema: {
            type: 'object',
            properties: {
              shaderPath: { type: 'string', description: 'Path to .metal file' },
              deviceFamily: { type: 'string', description: 'Target device family (iPhone, iPad)', default: 'iPhone' },
            },
            required: ['shaderPath'],
          },
        },

        // Memory Profiling Tools
        {
          name: 'analyze_memory_usage',
          description: 'Analyze iOS app memory usage patterns and provide optimization suggestions',
          inputSchema: {
            type: 'object',
            properties: {
              projectPath: { type: 'string', description: 'Path to Xcode project' },
              target: { type: 'string', description: 'Target to analyze' },
              analyzeLeaks: { type: 'boolean', description: 'Check for potential memory leaks', default: true },
            },
            required: ['projectPath'],
          },
        },

        // Simulator Management Tools
        {
          name: 'list_ios_simulators',
          description: 'List available iOS simulators and their status',
          inputSchema: {
            type: 'object',
            properties: {
              runtime: { type: 'string', description: 'Filter by iOS runtime version' },
              deviceType: { type: 'string', description: 'Filter by device type' },
            },
          },
        },

        {
          name: 'boot_simulator',
          description: 'Boot an iOS simulator for testing',
          inputSchema: {
            type: 'object',
            properties: {
              deviceId: { type: 'string', description: 'Simulator device ID or name' },
              waitForBoot: { type: 'boolean', description: 'Wait for simulator to fully boot', default: true },
            },
            required: ['deviceId'],
          },
        },

        {
          name: 'install_app_simulator',
          description: 'Install and launch app on iOS simulator',
          inputSchema: {
            type: 'object',
            properties: {
              appPath: { type: 'string', description: 'Path to .app bundle' },
              deviceId: { type: 'string', description: 'Simulator device ID' },
              launch: { type: 'boolean', description: 'Launch app after installation', default: true },
            },
            required: ['appPath', 'deviceId'],
          },
        },

        // SwiftUI and UIKit Best Practices
        {
          name: 'check_swiftui_best_practices',
          description: 'Check SwiftUI code for best practices and common issues',
          inputSchema: {
            type: 'object',
            properties: {
              filePath: { type: 'string', description: 'Path to SwiftUI file or directory' },
              checkPerformance: { type: 'boolean', description: 'Check for performance issues', default: true },
              checkAccessibility: { type: 'boolean', description: 'Check accessibility compliance', default: true },
            },
            required: ['filePath'],
          },
        },

        {
          name: 'check_uikit_best_practices',
          description: 'Check UIKit code for best practices and modernization opportunities',
          inputSchema: {
            type: 'object',
            properties: {
              filePath: { type: 'string', description: 'Path to UIKit file or directory' },
              suggestSwiftUI: { type: 'boolean', description: 'Suggest SwiftUI alternatives', default: true },
              checkMemoryManagement: { type: 'boolean', description: 'Check memory management', default: true },
            },
            required: ['filePath'],
          },
        },

        // Build and Deployment Tools
        {
          name: 'build_ios_project',
          description: 'Build iOS project with specified configuration',
          inputSchema: {
            type: 'object',
            properties: {
              projectPath: { type: 'string', description: 'Path to Xcode project' },
              scheme: { type: 'string', description: 'Build scheme' },
              configuration: { type: 'string', description: 'Build configuration', default: 'Debug' },
              destination: { type: 'string', description: 'Build destination', default: 'generic/platform=iOS Simulator' },
              clean: { type: 'boolean', description: 'Clean before building', default: false },
            },
            required: ['projectPath'],
          },
        },

        {
          name: 'run_ios_tests',
          description: 'Run iOS unit and UI tests',
          inputSchema: {
            type: 'object',
            properties: {
              projectPath: { type: 'string', description: 'Path to Xcode project' },
              scheme: { type: 'string', description: 'Test scheme' },
              testType: { type: 'string', description: 'Type of tests (unit, ui, all)', default: 'all' },
              destination: { type: 'string', description: 'Test destination' },
            },
            required: ['projectPath'],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const toolName = request.params.name;
      const args = request.params.arguments || {};

      try {
        switch (toolName) {
          case 'analyze_xcode_project':
            return await this.xcodeProjectManager.analyzeProject(args.projectPath as string, {
              analyzeTargets: args.analyzeTargets as boolean,
              analyzeSchemes: args.analyzeSchemes as boolean,
            });

          case 'validate_build_settings':
            return await this.xcodeProjectManager.validateBuildSettings(
              args.projectPath as string,
              args.target as string,
              args.configuration as string
            );

          case 'analyze_swift_code':
            return await this.swiftCodeAnalyzer.analyzeCode(args.filePath as string, {
              checkSyntax: args.checkSyntax as boolean,
              checkStyle: args.checkStyle as boolean,
              checkPerformance: args.checkPerformance as boolean,
            });

          case 'compile_swift_file':
            return await this.swiftCodeAnalyzer.compileSwiftFile(
              args.filePath as string,
              args.target as string,
              args.sdk as string
            );

          case 'validate_ios_deployment':
            return await this.iosDeploymentValidator.validateDeployment(
              args.projectPath as string,
              args.targetVersion as string,
              { validateCapabilities: args.validateCapabilities as boolean }
            );

          case 'compile_metal_shaders':
            return await this.metalShaderValidator.compileShaders(
              args.shaderPath as string,
              args.target as string,
              args.optimizationLevel as string
            );

          case 'analyze_metal_performance':
            return await this.metalShaderValidator.analyzePerformance(
              args.shaderPath as string,
              args.deviceFamily as string
            );

          case 'analyze_memory_usage':
            return await this.iosMemoryProfiler.analyzeMemoryUsage(
              args.projectPath as string,
              args.target as string,
              { analyzeLeaks: args.analyzeLeaks as boolean }
            );

          case 'list_ios_simulators':
            return await this.simulatorManager.listSimulators(args.runtime as string, args.deviceType as string);

          case 'boot_simulator':
            return await this.simulatorManager.bootSimulator(args.deviceId as string, args.waitForBoot as boolean);

          case 'install_app_simulator':
            return await this.simulatorManager.installApp(
              args.appPath as string,
              args.deviceId as string,
              args.launch as boolean
            );

          case 'check_swiftui_best_practices':
            return await this.swiftUIBestPractices.checkSwiftUI(args.filePath as string, {
              checkPerformance: args.checkPerformance as boolean,
              checkAccessibility: args.checkAccessibility as boolean,
            });

          case 'check_uikit_best_practices':
            return await this.swiftUIBestPractices.checkUIKit(args.filePath as string, {
              suggestSwiftUI: args.suggestSwiftUI as boolean,
              checkMemoryManagement: args.checkMemoryManagement as boolean,
            });

          case 'build_ios_project':
            return await this.buildProject(args);

          case 'run_ios_tests':
            return await this.runTests(args);

          default:
            throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${toolName}`);
        }
      } catch (error) {
        throw new McpError(ErrorCode.InternalError, `Tool execution failed: ${error}`);
      }
    });
  }

  private async getProjectInfo(): Promise<any> {
    try {
      const currentDir = process.cwd();
      const xcodeProjects = await glob(['**/*.xcodeproj', '**/*.xcworkspace'], {
        cwd: currentDir,
        onlyDirectories: true,
      });

      if (xcodeProjects.length === 0) {
        return { error: 'No Xcode project found in current directory' };
      }

      const projectPath = path.join(currentDir, xcodeProjects[0]);
      return await this.xcodeProjectManager.getProjectInfo(projectPath);
    } catch (error) {
      return { error: `Failed to get project info: ${error}` };
    }
  }

  private async getBuildSettings(): Promise<any> {
    try {
      const currentDir = process.cwd();
      const xcodeProjects = await glob(['**/*.xcodeproj'], {
        cwd: currentDir,
        onlyDirectories: true,
      });

      if (xcodeProjects.length === 0) {
        return { error: 'No Xcode project found' };
      }

      const projectPath = path.join(currentDir, xcodeProjects[0]);
      return await this.xcodeProjectManager.getBuildSettings(projectPath);
    } catch (error) {
      return { error: `Failed to get build settings: ${error}` };
    }
  }

  private async buildProject(args: any): Promise<any> {
    try {
      const buildArgs = [
        'xcodebuild',
        '-project', args.projectPath,
      ];

      if (args.scheme) buildArgs.push('-scheme', args.scheme);
      if (args.configuration) buildArgs.push('-configuration', args.configuration);
      if (args.destination) buildArgs.push('-destination', args.destination);
      if (args.clean) buildArgs.push('clean');

      buildArgs.push('build');

      const result = execSync(buildArgs.join(' '), { 
        encoding: 'utf8',
        timeout: 300000, // 5 minutes timeout
      });

      return {
        content: [{
          type: 'text',
          text: `Build completed successfully:\n\n${result}`,
        }],
      };
    } catch (error: any) {
      return {
        content: [{
          type: 'text',
          text: `Build failed:\n\n${error.message}\n\nOutput:\n${error.stdout || ''}\n\nError:\n${error.stderr || ''}`,
        }],
        isError: true,
      };
    }
  }

  private async runTests(args: any): Promise<any> {
    try {
      const testArgs = [
        'xcodebuild',
        'test',
        '-project', args.projectPath,
      ];

      if (args.scheme) testArgs.push('-scheme', args.scheme);
      if (args.destination) testArgs.push('-destination', args.destination);

      const result = execSync(testArgs.join(' '), { 
        encoding: 'utf8',
        timeout: 600000, // 10 minutes timeout for tests
      });

      return {
        content: [{
          type: 'text',
          text: `Tests completed successfully:\n\n${result}`,
        }],
      };
    } catch (error: any) {
      return {
        content: [{
          type: 'text',
          text: `Tests failed:\n\n${error.message}\n\nOutput:\n${error.stdout || ''}\n\nError:\n${error.stderr || ''}`,
        }],
        isError: true,
      };
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Swift Tools MCP server running on stdio');
  }
}

const server = new SwiftToolsMCPServer();
server.run().catch(console.error);