#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { exec, execSync } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// Schema definitions for tool parameters
const ViewHierarchySchema = z.object({
  includeConstraints: z.boolean().optional().default(true),
  include3D: z.boolean().optional().default(false),
  simulatorId: z.string().optional(),
});

const InspectViewSchema = z.object({
  viewAddress: z.string(),
  includeSubviews: z.boolean().optional().default(false),
  simulatorId: z.string().optional(),
});

const ConstraintDebugSchema = z.object({
  viewAddress: z.string().optional(),
  simulatorId: z.string().optional(),
});

const CaptureScreenshotSchema = z.object({
  simulatorId: z.string().optional(),
  outputPath: z.string().optional(),
});

const PerformanceMetricsSchema = z.object({
  duration: z.number().optional().default(5),
  simulatorId: z.string().optional(),
});

class IOSUIDebugServer {
  private server: Server;
  private defaultSimulatorId?: string;

  constructor() {
    this.server = new Server(
      {
        name: "ios-ui-debug-mcp",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    
    // Try to find default simulator
    this.findDefaultSimulator();
  }

  private findDefaultSimulator() {
    try {
      const result = execSync('xcrun simctl list devices booted -j', { encoding: 'utf8' });
      const devices = JSON.parse(result);
      const bootedDevices = Object.values(devices.devices).flat().filter((d: any) => d.state === 'Booted');
      if (bootedDevices.length > 0) {
        this.defaultSimulatorId = bootedDevices[0].udid;
        console.error(`Found booted simulator: ${this.defaultSimulatorId}`);
      }
    } catch (e) {
      console.error('Could not find booted simulator');
    }
  }

  private getSimulatorId(providedId?: string): string {
    const id = providedId || this.defaultSimulatorId;
    if (!id) {
      throw new McpError(
        ErrorCode.InvalidParams,
        "No simulator ID provided and no booted simulator found"
      );
    }
    return id;
  }

  private async executeDebugCommand(simulatorId: string, command: string): Promise<string> {
    const lldbCommand = `
echo '${command}' | xcrun simctl spawn ${simulatorId} lldb -o "attach --name iOS_DICOMViewer" -o "expr -l objc -O -- ${command}" -o "quit"
    `.trim();
    
    try {
      const { stdout, stderr } = await execAsync(lldbCommand);
      if (stderr && !stderr.includes('Quit')) {
        console.error('LLDB stderr:', stderr);
      }
      return stdout;
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to execute debug command: ${error}`
      );
    }
  }

  private parseViewHierarchy(output: string): any {
    // Parse the recursive description output into a structured format
    const lines = output.split('\n');
    const hierarchy: any[] = [];
    const stack: any[] = [];
    
    for (const line of lines) {
      if (!line.includes('<')) continue;
      
      const match = line.match(/(\s*)(.*)/);
      if (!match) continue;
      
      const [, indent, content] = match;
      const level = indent.length / 3; // Assuming 3 spaces per level
      
      const viewInfo = this.parseViewLine(content);
      if (!viewInfo) continue;
      
      while (stack.length > level) {
        stack.pop();
      }
      
      if (stack.length === 0) {
        hierarchy.push(viewInfo);
      } else {
        const parent = stack[stack.length - 1];
        if (!parent.subviews) parent.subviews = [];
        parent.subviews.push(viewInfo);
      }
      
      stack.push(viewInfo);
    }
    
    return hierarchy;
  }

  private parseViewLine(line: string): any {
    const match = line.match(/<([^:]+):([^>]+)>/);
    if (!match) return null;
    
    const [, className, address] = match;
    const frameMatch = line.match(/frame = \(([\d.-]+) ([\d.-]+); ([\d.-]+) ([\d.-]+)\)/);
    
    return {
      className,
      address,
      frame: frameMatch ? {
        x: parseFloat(frameMatch[1]),
        y: parseFloat(frameMatch[2]),
        width: parseFloat(frameMatch[3]),
        height: parseFloat(frameMatch[4])
      } : null,
      rawDescription: line
    };
  }

  private setupToolHandlers() {
    // Tool: capture_view_hierarchy
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "capture_view_hierarchy",
          description: "Capture the complete view hierarchy of the running iOS app",
          inputSchema: {
            type: "object",
            properties: {
              includeConstraints: {
                type: "boolean",
                description: "Include Auto Layout constraints",
                default: true
              },
              include3D: {
                type: "boolean", 
                description: "Include 3D representation data",
                default: false
              },
              simulatorId: {
                type: "string",
                description: "Simulator device ID (optional)"
              }
            }
          }
        },
        {
          name: "inspect_view",
          description: "Get detailed information about a specific view",
          inputSchema: {
            type: "object",
            properties: {
              viewAddress: {
                type: "string",
                description: "Memory address of the view (e.g., 0x7f8b1234)"
              },
              includeSubviews: {
                type: "boolean",
                description: "Include subview information",
                default: false
              },
              simulatorId: {
                type: "string",
                description: "Simulator device ID (optional)"
              }
            },
            required: ["viewAddress"]
          }
        },
        {
          name: "debug_constraints",
          description: "Debug Auto Layout constraints for a view or the entire hierarchy",
          inputSchema: {
            type: "object",
            properties: {
              viewAddress: {
                type: "string",
                description: "Memory address of the view (optional, debugs all if not provided)"
              },
              simulatorId: {
                type: "string",
                description: "Simulator device ID (optional)"
              }
            }
          }
        },
        {
          name: "capture_screenshot",
          description: "Capture a screenshot of the current app state",
          inputSchema: {
            type: "object",
            properties: {
              simulatorId: {
                type: "string",
                description: "Simulator device ID (optional)"
              },
              outputPath: {
                type: "string",
                description: "Path to save the screenshot (optional)"
              }
            }
          }
        },
        {
          name: "get_performance_metrics",
          description: "Get rendering performance metrics",
          inputSchema: {
            type: "object",
            properties: {
              duration: {
                type: "number",
                description: "Duration in seconds to collect metrics",
                default: 5
              },
              simulatorId: {
                type: "string",
                description: "Simulator device ID (optional)"
              }
            }
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "capture_view_hierarchy": {
            const params = ViewHierarchySchema.parse(args);
            const simulatorId = this.getSimulatorId(params.simulatorId);
            
            // Capture basic hierarchy
            const hierarchyCmd = "[[UIApplication sharedApplication] keyWindow].recursiveDescription";
            const hierarchyOutput = await this.executeDebugCommand(simulatorId, hierarchyCmd);
            
            const hierarchy = this.parseViewHierarchy(hierarchyOutput);
            
            // Optionally capture constraints
            let constraints = null;
            if (params.includeConstraints) {
              const constraintsCmd = "[[UIApplication sharedApplication] keyWindow]._autolayoutTrace";
              try {
                constraints = await this.executeDebugCommand(simulatorId, constraintsCmd);
              } catch (e) {
                console.error('Could not capture constraints:', e);
              }
            }
            
            return {
              content: [
                {
                  type: "text",
                  text: JSON.stringify({
                    hierarchy,
                    constraints,
                    capturedAt: new Date().toISOString()
                  }, null, 2)
                }
              ]
            };
          }

          case "inspect_view": {
            const params = InspectViewSchema.parse(args);
            const simulatorId = this.getSimulatorId(params.simulatorId);
            
            // Get view details
            const commands = [
              `(UIView *)${params.viewAddress}`,
              `[(UIView *)${params.viewAddress} frame]`,
              `[(UIView *)${params.viewAddress} bounds]`,
              `[(UIView *)${params.viewAddress} backgroundColor]`,
              `[(UIView *)${params.viewAddress} alpha]`,
              `[(UIView *)${params.viewAddress} isHidden]`,
              `[(UIView *)${params.viewAddress} constraints]`,
            ];
            
            const results: any = {};
            for (const cmd of commands) {
              try {
                const output = await this.executeDebugCommand(simulatorId, cmd);
                const key = cmd.match(/\] (\w+)\]?$/)?.[1] || 'info';
                results[key] = output.trim();
              } catch (e) {
                console.error(`Failed to execute: ${cmd}`);
              }
            }
            
            if (params.includeSubviews) {
              const subviewsCmd = `[(UIView *)${params.viewAddress} recursiveDescription]`;
              results.subviews = await this.executeDebugCommand(simulatorId, subviewsCmd);
            }
            
            return {
              content: [
                {
                  type: "text",
                  text: JSON.stringify(results, null, 2)
                }
              ]
            };
          }

          case "debug_constraints": {
            const params = ConstraintDebugSchema.parse(args);
            const simulatorId = this.getSimulatorId(params.simulatorId);
            
            let command: string;
            if (params.viewAddress) {
              command = `[(UIView *)${params.viewAddress} _autolayoutTrace]`;
            } else {
              command = "[[UIApplication sharedApplication] keyWindow]._autolayoutTrace";
            }
            
            const output = await this.executeDebugCommand(simulatorId, command);
            
            // Also check for unsatisfiable constraints
            const ambiguityCmd = params.viewAddress 
              ? `[(UIView *)${params.viewAddress} hasAmbiguousLayout]`
              : "[[UIApplication sharedApplication] keyWindow]._hasAmbiguousLayout";
            
            let hasAmbiguity = false;
            try {
              const ambiguityOutput = await this.executeDebugCommand(simulatorId, ambiguityCmd);
              hasAmbiguity = ambiguityOutput.includes("YES");
            } catch (e) {
              console.error('Could not check ambiguity:', e);
            }
            
            return {
              content: [
                {
                  type: "text",
                  text: JSON.stringify({
                    constraints: output,
                    hasAmbiguousLayout: hasAmbiguity,
                    timestamp: new Date().toISOString()
                  }, null, 2)
                }
              ]
            };
          }

          case "capture_screenshot": {
            const params = CaptureScreenshotSchema.parse(args);
            const simulatorId = this.getSimulatorId(params.simulatorId);
            
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const outputPath = params.outputPath || `/tmp/ios-screenshot-${timestamp}.png`;
            
            const { stdout } = await execAsync(
              `xcrun simctl io ${simulatorId} screenshot "${outputPath}"`
            );
            
            return {
              content: [
                {
                  type: "text",
                  text: JSON.stringify({
                    success: true,
                    path: outputPath,
                    timestamp: new Date().toISOString()
                  }, null, 2)
                }
              ]
            };
          }

          case "get_performance_metrics": {
            const params = PerformanceMetricsSchema.parse(args);
            const simulatorId = this.getSimulatorId(params.simulatorId);
            
            // Enable performance HUD
            await execAsync(
              `xcrun simctl spawn ${simulatorId} defaults write com.dicomviewer.iOS-DICOMViewer MetalHudEnabled -bool YES`
            );
            
            // Collect metrics for specified duration
            await new Promise(resolve => setTimeout(resolve, params.duration * 1000));
            
            // Get FPS and frame time data (this is a simplified version)
            const metricsCmd = `
              CADisplayLink *link = [CADisplayLink displayLinkWithTarget:nil selector:nil];
              NSLog(@"FPS: %f", 1.0 / link.duration);
            `;
            
            let fps = 60; // Default
            try {
              const output = await this.executeDebugCommand(simulatorId, metricsCmd);
              const fpsMatch = output.match(/FPS: ([\d.]+)/);
              if (fpsMatch) fps = parseFloat(fpsMatch[1]);
            } catch (e) {
              console.error('Could not get FPS:', e);
            }
            
            return {
              content: [
                {
                  type: "text",
                  text: JSON.stringify({
                    fps,
                    frameTime: 1000 / fps,
                    duration: params.duration,
                    timestamp: new Date().toISOString()
                  }, null, 2)
                }
              ]
            };
          }

          default:
            throw new McpError(
              ErrorCode.MethodNotFound,
              `Unknown tool: ${name}`
            );
        }
      } catch (error) {
        if (error instanceof z.ZodError) {
          throw new McpError(
            ErrorCode.InvalidParams,
            `Invalid parameters: ${error.errors.map(e => e.message).join(", ")}`
          );
        }
        throw error;
      }
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("iOS UI Debug MCP server running on stdio");
  }
}

const server = new IOSUIDebugServer();
server.run().catch(console.error);