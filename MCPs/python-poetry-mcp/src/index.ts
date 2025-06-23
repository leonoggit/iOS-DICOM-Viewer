#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { execa } from "execa";
import fs from "fs-extra";
import path from "path";

// Validation schemas
const createProjectSchema = z.object({
  name: z.string().describe("Project name"),
  path: z.string().describe("Directory path where to create the project"),
  python: z.string().optional().describe("Python version (e.g., '3.11')"),
  src: z.boolean().optional().default(false).describe("Use src layout"),
  readme: z.boolean().optional().default(true).describe("Create README.md"),
});

const addDependencySchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  packages: z.array(z.string()).describe("Package names to add"),
  dev: z.boolean().optional().default(false).describe("Add as development dependency"),
  group: z.string().optional().describe("Dependency group name"),
  extras: z.array(z.string()).optional().describe("Package extras to install"),
  source: z.string().optional().describe("Repository source name"),
});

const removeDependencySchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  packages: z.array(z.string()).describe("Package names to remove"),
  dev: z.boolean().optional().default(false).describe("Remove from development dependencies"),
  group: z.string().optional().describe("Dependency group name"),
});

const updateDependencySchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  packages: z.array(z.string()).optional().describe("Specific packages to update (all if not specified)"),
  dry: z.boolean().optional().default(false).describe("Dry run to see what would be updated"),
});

const installSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  extras: z.array(z.string()).optional().describe("Extras to install"),
  withDev: z.boolean().optional().default(true).describe("Install development dependencies"),
  groups: z.array(z.string()).optional().describe("Dependency groups to install"),
  sync: z.boolean().optional().default(false).describe("Synchronize the environment"),
});

const exportRequirementsSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  format: z.enum(["requirements", "constraints"]).optional().default("requirements"),
  output: z.string().optional().describe("Output file path"),
  withDev: z.boolean().optional().default(false).describe("Include development dependencies"),
  extras: z.array(z.string()).optional().describe("Include extras"),
  withoutHashes: z.boolean().optional().default(false).describe("Exclude hashes"),
});

const runCommandSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  command: z.string().describe("Command to run"),
  args: z.array(z.string()).optional().describe("Command arguments"),
});

const pyenvSchema = z.object({
  action: z.enum(["install", "local", "global", "versions"]).describe("Pyenv action"),
  version: z.string().optional().describe("Python version"),
  projectPath: z.string().optional().describe("Project path for local version"),
});

const mlProjectSetupSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  framework: z.enum(["tensorflow", "pytorch", "jax", "scikit-learn", "transformers"]).describe("ML framework"),
  cuda: z.boolean().optional().default(false).describe("Install CUDA support"),
  extras: z.array(z.string()).optional().describe("Additional ML packages"),
});

const dependencyTreeSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  package: z.string().optional().describe("Show tree for specific package"),
  depth: z.number().optional().default(3).describe("Tree depth"),
});

const checkConflictsSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  fix: z.boolean().optional().default(false).describe("Attempt to fix conflicts"),
});

const publishSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  repository: z.string().optional().describe("Repository name (default: pypi)"),
  username: z.string().optional().describe("Repository username"),
  password: z.string().optional().describe("Repository password"),
  token: z.string().optional().describe("API token"),
  build: z.boolean().optional().default(true).describe("Build before publishing"),
});

const envInfoSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
});

const lockSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  update: z.boolean().optional().default(false).describe("Update dependencies to latest"),
  check: z.boolean().optional().default(false).describe("Check if lock file is up to date"),
});

const configSchema = z.object({
  projectPath: z.string().optional().describe("Path to the Poetry project (for local config)"),
  key: z.string().optional().describe("Config key to get/set"),
  value: z.string().optional().describe("Config value to set"),
  unset: z.boolean().optional().default(false).describe("Unset the config key"),
  list: z.boolean().optional().default(false).describe("List all config"),
});

const sourceSchema = z.object({
  projectPath: z.string().describe("Path to the Poetry project"),
  action: z.enum(["add", "remove", "list"]).describe("Source action"),
  name: z.string().optional().describe("Source name"),
  url: z.string().optional().describe("Source URL"),
  priority: z.enum(["default", "primary", "supplemental", "explicit"]).optional(),
});

// Helper functions
async function executePoetryCommand(args: string[], cwd?: string): Promise<string> {
  try {
    const { stdout, stderr } = await execa("poetry", args, {
      cwd,
      env: { ...process.env, POETRY_VIRTUALENVS_IN_PROJECT: "true" },
    });
    return stdout || stderr;
  } catch (error: any) {
    throw new McpError(
      ErrorCode.InternalError,
      `Poetry command failed: ${error.message}\n${error.stderr || ""}`
    );
  }
}

async function executePyenvCommand(args: string[]): Promise<string> {
  try {
    const { stdout, stderr } = await execa("pyenv", args);
    return stdout || stderr;
  } catch (error: any) {
    throw new McpError(
      ErrorCode.InternalError,
      `Pyenv command failed: ${error.message}\n${error.stderr || ""}`
    );
  }
}

// Removed unused readPyprojectToml function - can be added back if needed in future

async function getMLPackages(framework: string, cuda: boolean): Promise<string[]> {
  const packages: string[] = [];
  
  switch (framework) {
    case "tensorflow":
      packages.push(cuda ? "tensorflow[and-cuda]" : "tensorflow");
      packages.push("tensorboard", "keras", "tensorflow-datasets");
      break;
    case "pytorch":
      if (cuda) {
        packages.push("torch", "torchvision", "torchaudio", "--index-url", "https://download.pytorch.org/whl/cu118");
      } else {
        packages.push("torch", "torchvision", "torchaudio");
      }
      packages.push("tensorboard");
      break;
    case "jax":
      packages.push(cuda ? "jax[cuda]" : "jax[cpu]");
      packages.push("jaxlib", "flax", "optax");
      break;
    case "scikit-learn":
      packages.push("scikit-learn", "scipy", "statsmodels");
      break;
    case "transformers":
      packages.push("transformers", "datasets", "tokenizers", "accelerate");
      if (cuda) packages.push("torch");
      break;
  }
  
  // Common ML/Data science packages
  packages.push(
    "numpy",
    "pandas",
    "matplotlib",
    "seaborn",
    "jupyter",
    "ipython",
    "tqdm",
    "pillow",
    "opencv-python"
  );
  
  return packages;
}

// Create server instance
const server = new Server(
  {
    name: "python-poetry-mcp",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool handlers
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "poetry_create_project",
      description: "Create a new Python project with Poetry",
      inputSchema: {
        type: "object",
        properties: createProjectSchema.shape,
        required: ["name", "path"],
      },
    },
    {
      name: "poetry_add_dependency",
      description: "Add dependencies to a Poetry project",
      inputSchema: {
        type: "object",
        properties: addDependencySchema.shape,
        required: ["projectPath", "packages"],
      },
    },
    {
      name: "poetry_remove_dependency",
      description: "Remove dependencies from a Poetry project",
      inputSchema: {
        type: "object",
        properties: removeDependencySchema.shape,
        required: ["projectPath", "packages"],
      },
    },
    {
      name: "poetry_update_dependency",
      description: "Update dependencies in a Poetry project",
      inputSchema: {
        type: "object",
        properties: updateDependencySchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_install",
      description: "Install project dependencies",
      inputSchema: {
        type: "object",
        properties: installSchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_export_requirements",
      description: "Export dependencies to requirements.txt format",
      inputSchema: {
        type: "object",
        properties: exportRequirementsSchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_run",
      description: "Run a command in the Poetry environment",
      inputSchema: {
        type: "object",
        properties: runCommandSchema.shape,
        required: ["projectPath", "command"],
      },
    },
    {
      name: "poetry_pyenv",
      description: "Manage Python versions with pyenv",
      inputSchema: {
        type: "object",
        properties: pyenvSchema.shape,
        required: ["action"],
      },
    },
    {
      name: "poetry_ml_setup",
      description: "Set up ML/AI project dependencies",
      inputSchema: {
        type: "object",
        properties: mlProjectSetupSchema.shape,
        required: ["projectPath", "framework"],
      },
    },
    {
      name: "poetry_dependency_tree",
      description: "Show project dependency tree",
      inputSchema: {
        type: "object",
        properties: dependencyTreeSchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_check_conflicts",
      description: "Check and resolve dependency conflicts",
      inputSchema: {
        type: "object",
        properties: checkConflictsSchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_publish",
      description: "Build and publish package to PyPI",
      inputSchema: {
        type: "object",
        properties: publishSchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_env_info",
      description: "Show Poetry environment information",
      inputSchema: {
        type: "object",
        properties: envInfoSchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_lock",
      description: "Lock or update project dependencies",
      inputSchema: {
        type: "object",
        properties: lockSchema.shape,
        required: ["projectPath"],
      },
    },
    {
      name: "poetry_config",
      description: "Manage Poetry configuration",
      inputSchema: {
        type: "object",
        properties: configSchema.shape,
      },
    },
    {
      name: "poetry_source",
      description: "Manage package sources",
      inputSchema: {
        type: "object",
        properties: sourceSchema.shape,
        required: ["projectPath", "action"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "poetry_create_project": {
        const { name: projectName, path: projectPath, python, src, readme } = createProjectSchema.parse(args);
        const fullPath = path.join(projectPath, projectName);
        
        // Create project directory
        await fs.ensureDir(fullPath);
        
        // Initialize Poetry project
        const initArgs = ["init", "--no-interaction", "--name", projectName];
        if (python) initArgs.push("--python", python);
        await executePoetryCommand(initArgs, fullPath);
        
        // Create additional structure
        if (src) {
          await fs.ensureDir(path.join(fullPath, "src", projectName));
          await fs.writeFile(
            path.join(fullPath, "src", projectName, "__init__.py"),
            '"""Package initialization."""\n__version__ = "0.1.0"\n'
          );
        } else {
          await fs.ensureDir(path.join(fullPath, projectName));
          await fs.writeFile(
            path.join(fullPath, projectName, "__init__.py"),
            '"""Package initialization."""\n__version__ = "0.1.0"\n'
          );
        }
        
        // Create tests directory
        await fs.ensureDir(path.join(fullPath, "tests"));
        await fs.writeFile(path.join(fullPath, "tests", "__init__.py"), "");
        
        if (readme) {
          await fs.writeFile(
            path.join(fullPath, "README.md"),
            `# ${projectName}\n\nA Python project managed with Poetry.\n\n## Installation\n\n\`\`\`bash\npoetry install\n\`\`\`\n`
          );
        }
        
        // Create .gitignore
        await fs.writeFile(
          path.join(fullPath, ".gitignore"),
          `# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/
*.egg-info/
dist/
build/

# Poetry
poetry.lock

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Testing
.coverage
.pytest_cache/
.tox/
htmlcov/

# Jupyter
.ipynb_checkpoints/
*.ipynb
`
        );
        
        return {
          content: [
            {
              type: "text",
              text: `Created Poetry project '${projectName}' at ${fullPath}`,
            },
          ],
        };
      }

      case "poetry_add_dependency": {
        const { projectPath, packages, dev, group, extras, source } = addDependencySchema.parse(args);
        
        const addArgs = ["add"];
        if (dev) addArgs.push("--dev");
        if (group) addArgs.push("--group", group);
        if (source) addArgs.push("--source", source);
        
        // Handle packages with extras
        const processedPackages = packages.map(pkg => {
          if (extras && extras.length > 0) {
            return `${pkg}[${extras.join(",")}]`;
          }
          return pkg;
        });
        
        addArgs.push(...processedPackages);
        
        const result = await executePoetryCommand(addArgs, projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: `Added dependencies: ${packages.join(", ")}\n\n${result}`,
            },
          ],
        };
      }

      case "poetry_remove_dependency": {
        const { projectPath, packages, dev, group } = removeDependencySchema.parse(args);
        
        const removeArgs = ["remove"];
        if (dev) removeArgs.push("--dev");
        if (group) removeArgs.push("--group", group);
        removeArgs.push(...packages);
        
        const result = await executePoetryCommand(removeArgs, projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: `Removed dependencies: ${packages.join(", ")}\n\n${result}`,
            },
          ],
        };
      }

      case "poetry_update_dependency": {
        const { projectPath, packages, dry } = updateDependencySchema.parse(args);
        
        const updateArgs = ["update"];
        if (dry) updateArgs.push("--dry-run");
        if (packages && packages.length > 0) {
          updateArgs.push(...packages);
        }
        
        const result = await executePoetryCommand(updateArgs, projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_install": {
        const { projectPath, extras, withDev, groups, sync } = installSchema.parse(args);
        
        const installArgs = ["install"];
        if (!withDev) installArgs.push("--no-dev");
        if (sync) installArgs.push("--sync");
        if (extras && extras.length > 0) {
          extras.forEach(extra => installArgs.push("--extras", extra));
        }
        if (groups && groups.length > 0) {
          groups.forEach(group => installArgs.push("--with", group));
        }
        
        const result = await executePoetryCommand(installArgs, projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_export_requirements": {
        const { projectPath, format, output, withDev, extras, withoutHashes } = exportRequirementsSchema.parse(args);
        
        const exportArgs = ["export", "--format", format];
        if (withDev) exportArgs.push("--dev");
        if (withoutHashes) exportArgs.push("--without-hashes");
        if (extras && extras.length > 0) {
          extras.forEach(extra => exportArgs.push("--extras", extra));
        }
        
        const result = await executePoetryCommand(exportArgs, projectPath);
        
        if (output) {
          await fs.writeFile(path.resolve(projectPath, output), result);
          return {
            content: [
              {
                type: "text",
                text: `Exported requirements to ${output}`,
              },
            ],
          };
        }
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_run": {
        const { projectPath, command, args: commandArgs } = runCommandSchema.parse(args);
        
        const runArgs = ["run", command];
        if (commandArgs && commandArgs.length > 0) {
          runArgs.push(...commandArgs);
        }
        
        const result = await executePoetryCommand(runArgs, projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_pyenv": {
        const { action, version, projectPath } = pyenvSchema.parse(args);
        
        let result: string;
        
        switch (action) {
          case "install":
            if (!version) throw new McpError(ErrorCode.InvalidRequest, "Version required for install");
            result = await executePyenvCommand(["install", version]);
            break;
          
          case "local":
            if (!version || !projectPath) {
              throw new McpError(ErrorCode.InvalidRequest, "Version and projectPath required for local");
            }
            result = await executePyenvCommand(["local", version]);
            // Update Poetry to use this version
            await executePoetryCommand(["env", "use", version], projectPath);
            break;
          
          case "global":
            if (!version) throw new McpError(ErrorCode.InvalidRequest, "Version required for global");
            result = await executePyenvCommand(["global", version]);
            break;
          
          case "versions":
            result = await executePyenvCommand(["versions"]);
            break;
          
          default:
            throw new McpError(ErrorCode.InvalidRequest, "Invalid pyenv action");
        }
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_ml_setup": {
        const { projectPath, framework, cuda, extras } = mlProjectSetupSchema.parse(args);
        
        const packages = await getMLPackages(framework, cuda);
        if (extras) packages.push(...extras);
        
        // Add packages in batches to avoid command line length issues
        const batchSize = 10;
        let results: string[] = [];
        
        for (let i = 0; i < packages.length; i += batchSize) {
          const batch = packages.slice(i, i + batchSize);
          const addArgs = ["add", ...batch];
          const result = await executePoetryCommand(addArgs, projectPath);
          results.push(result);
        }
        
        // Add dev dependencies for ML projects
        const devPackages = [
          "pytest",
          "pytest-cov",
          "black",
          "flake8",
          "mypy",
          "isort",
          "pre-commit",
          "notebook",
          "ipykernel",
        ];
        
        const devResult = await executePoetryCommand(["add", "--group", "dev", ...devPackages], projectPath);
        results.push(devResult);
        
        return {
          content: [
            {
              type: "text",
              text: `Set up ML project with ${framework} framework.\nInstalled packages: ${packages.join(", ")}\n\nDev packages: ${devPackages.join(", ")}`,
            },
          ],
        };
      }

      case "poetry_dependency_tree": {
        const { projectPath, package: pkg, depth } = dependencyTreeSchema.parse(args);
        
        const treeArgs = ["show", "--tree"];
        if (pkg) treeArgs.push(pkg);
        
        const result = await executePoetryCommand(treeArgs, projectPath);
        
        // Limit depth if specified
        if (depth < 10) {
          const lines = result.split("\n");
          const filtered = lines.filter(line => {
            const indent = line.search(/\S/);
            return indent / 4 <= depth;
          });
          return {
            content: [
              {
                type: "text",
                text: filtered.join("\n"),
              },
            ],
          };
        }
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_check_conflicts": {
        const { projectPath, fix } = checkConflictsSchema.parse(args);
        
        // Check for conflicts
        const checkResult = await executePoetryCommand(["check"], projectPath);
        
        if (fix && checkResult.includes("error")) {
          // Try to resolve conflicts
          const lockResult = await executePoetryCommand(["lock", "--no-update"], projectPath);
          const installResult = await executePoetryCommand(["install", "--sync"], projectPath);
          
          return {
            content: [
              {
                type: "text",
                text: `Attempted to fix conflicts:\n\nCheck result:\n${checkResult}\n\nLock result:\n${lockResult}\n\nInstall result:\n${installResult}`,
              },
            ],
          };
        }
        
        return {
          content: [
            {
              type: "text",
              text: checkResult,
            },
          ],
        };
      }

      case "poetry_publish": {
        const { projectPath, repository, username, password, token, build } = publishSchema.parse(args);
        
        let results: string[] = [];
        
        // Build if requested
        if (build) {
          const buildResult = await executePoetryCommand(["build"], projectPath);
          results.push(`Build result:\n${buildResult}`);
        }
        
        // Configure repository if needed
        if (repository && repository !== "pypi") {
          const configArgs = ["config", `repositories.${repository}`, repository];
          await executePoetryCommand(configArgs, projectPath);
        }
        
        // Set credentials if provided
        if (token) {
          const tokenArgs = ["config", "pypi-token.pypi", token];
          await executePoetryCommand(tokenArgs, projectPath);
        } else if (username && password) {
          const userArgs = ["config", "http-basic.pypi", username, password];
          await executePoetryCommand(userArgs, projectPath);
        }
        
        // Publish
        const publishArgs = ["publish"];
        if (repository) publishArgs.push("--repository", repository);
        
        const publishResult = await executePoetryCommand(publishArgs, projectPath);
        results.push(`Publish result:\n${publishResult}`);
        
        return {
          content: [
            {
              type: "text",
              text: results.join("\n\n"),
            },
          ],
        };
      }

      case "poetry_env_info": {
        const { projectPath } = envInfoSchema.parse(args);
        
        const infoResult = await executePoetryCommand(["env", "info"], projectPath);
        const listResult = await executePoetryCommand(["env", "list"], projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: `Environment Info:\n${infoResult}\n\nAvailable Environments:\n${listResult}`,
            },
          ],
        };
      }

      case "poetry_lock": {
        const { projectPath, update, check } = lockSchema.parse(args);
        
        const lockArgs = ["lock"];
        if (update) {
          lockArgs.push("--no-update");
        }
        if (check) {
          lockArgs.push("--check");
        }
        
        const result = await executePoetryCommand(lockArgs, projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_config": {
        const { projectPath, key, value, unset, list } = configSchema.parse(args);
        
        let configArgs = ["config"];
        if (projectPath) configArgs.push("--local");
        
        if (list) {
          configArgs.push("--list");
        } else if (unset && key) {
          configArgs.push("--unset", key);
        } else if (key && value) {
          configArgs.push(key, value);
        } else if (key) {
          configArgs.push(key);
        } else {
          configArgs.push("--list");
        }
        
        const result = await executePoetryCommand(configArgs, projectPath);
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "poetry_source": {
        const { projectPath, action, name, url, priority } = sourceSchema.parse(args);
        
        let result: string;
        
        switch (action) {
          case "add":
            if (!name || !url) {
              throw new McpError(ErrorCode.InvalidRequest, "Name and URL required for adding source");
            }
            const addArgs = ["source", "add", name, url];
            if (priority) addArgs.push("--priority", priority);
            result = await executePoetryCommand(addArgs, projectPath);
            break;
          
          case "remove":
            if (!name) {
              throw new McpError(ErrorCode.InvalidRequest, "Name required for removing source");
            }
            result = await executePoetryCommand(["source", "remove", name], projectPath);
            break;
          
          case "list":
            result = await executePoetryCommand(["source", "show"], projectPath);
            break;
          
          default:
            throw new McpError(ErrorCode.InvalidRequest, "Invalid source action");
        }
        
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      default:
        throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new McpError(
        ErrorCode.InvalidParams,
        `Invalid parameters: ${error.errors.map(e => `${e.path.join(".")}: ${e.message}`).join(", ")}`
      );
    }
    throw error;
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Python Poetry MCP server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});