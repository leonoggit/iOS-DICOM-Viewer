# Python Poetry MCP Server

A comprehensive Model Context Protocol (MCP) server for Python dependency management using Poetry. This server provides powerful tools for creating, managing, and maintaining Python projects with a special focus on ML/AI projects with complex dependencies.

## Features

- 🎯 **Complete Poetry Integration**: All essential Poetry commands available as MCP tools
- 🐍 **Python Version Management**: Integrated pyenv support for managing Python versions
- 🤖 **ML/AI Project Support**: Specialized setup for TensorFlow, PyTorch, JAX, and more
- 📊 **Dependency Visualization**: Tree view and conflict resolution tools
- 📦 **Publishing Support**: Build and publish packages to PyPI
- 🔧 **Advanced Configuration**: Manage sources, repositories, and Poetry settings
- 🏗️ **Project Templates**: Quick setup with best practices included

## Installation

### Prerequisites

1. **Poetry**: Install Poetry if you haven't already:
   ```bash
   curl -sSL https://install.python-poetry.org | python3 -
   ```

2. **Pyenv** (optional but recommended):
   ```bash
   # macOS
   brew install pyenv
   
   # Linux
   curl https://pyenv.run | bash
   ```

3. **Node.js**: Required for running the MCP server

### Setup

1. Navigate to the MCP directory:
   ```bash
   cd /Users/leandroalmeida/iOS_DICOM/MCPs/python-poetry-mcp
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Build the TypeScript code:
   ```bash
   npm run build
   ```

4. Configure your MCP client (e.g., in Claude Desktop):
   ```json
   {
     "python-poetry": {
       "command": "node",
       "args": ["/Users/leandroalmeida/iOS_DICOM/MCPs/python-poetry-mcp/build/index.js"]
     }
   }
   ```

## Available Tools

### Project Management

#### `poetry_create_project`
Create a new Python project with Poetry initialization.

**Parameters:**
- `name` (required): Project name
- `path` (required): Directory path where to create the project
- `python`: Python version (e.g., '3.11')
- `src`: Use src layout (default: false)
- `readme`: Create README.md (default: true)

**Example:**
```typescript
await mcp.call("poetry_create_project", {
  name: "my-ml-project",
  path: "/Users/username/projects",
  python: "3.11",
  src: true
});
```

### Dependency Management

#### `poetry_add_dependency`
Add dependencies to a Poetry project.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `packages` (required): Array of package names to add
- `dev`: Add as development dependency (default: false)
- `group`: Dependency group name
- `extras`: Package extras to install
- `source`: Repository source name

**Example:**
```typescript
// Add production dependencies
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  packages: ["numpy", "pandas", "scikit-learn"]
});

// Add dev dependencies with extras
await mcp.call("poetry_add_dependency", {
  projectPath: "/path/to/project",
  packages: ["pytest", "black[jupyter]"],
  dev: true
});
```

#### `poetry_remove_dependency`
Remove dependencies from a Poetry project.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `packages` (required): Array of package names to remove
- `dev`: Remove from development dependencies
- `group`: Dependency group name

#### `poetry_update_dependency`
Update dependencies in a Poetry project.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `packages`: Specific packages to update (all if not specified)
- `dry`: Dry run to see what would be updated

### ML/AI Project Setup

#### `poetry_ml_setup`
Set up ML/AI project dependencies with framework-specific packages.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `framework` (required): One of: `tensorflow`, `pytorch`, `jax`, `scikit-learn`, `transformers`
- `cuda`: Install CUDA support (default: false)
- `extras`: Additional ML packages

**Example:**
```typescript
// Set up PyTorch project with CUDA
await mcp.call("poetry_ml_setup", {
  projectPath: "/path/to/project",
  framework: "pytorch",
  cuda: true,
  extras: ["wandb", "timm", "albumentations"]
});
```

This automatically installs:
- Framework-specific packages (with CUDA support if requested)
- Common data science libraries (numpy, pandas, matplotlib, etc.)
- Jupyter and development tools
- Testing and linting tools

### Environment Management

#### `poetry_install`
Install project dependencies.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `extras`: Extras to install
- `withDev`: Install development dependencies (default: true)
- `groups`: Dependency groups to install
- `sync`: Synchronize the environment

#### `poetry_env_info`
Show Poetry environment information.

**Parameters:**
- `projectPath` (required): Path to the Poetry project

#### `poetry_pyenv`
Manage Python versions with pyenv.

**Parameters:**
- `action` (required): One of: `install`, `local`, `global`, `versions`
- `version`: Python version (required for install/local/global)
- `projectPath`: Project path (required for local)

**Example:**
```typescript
// Install Python 3.11
await mcp.call("poetry_pyenv", {
  action: "install",
  version: "3.11.7"
});

// Set local Python version for project
await mcp.call("poetry_pyenv", {
  action: "local",
  version: "3.11.7",
  projectPath: "/path/to/project"
});
```

### Dependency Analysis

#### `poetry_dependency_tree`
Show project dependency tree.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `package`: Show tree for specific package
- `depth`: Tree depth (default: 3)

#### `poetry_check_conflicts`
Check and resolve dependency conflicts.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `fix`: Attempt to fix conflicts (default: false)

### Export and Publishing

#### `poetry_export_requirements`
Export dependencies to requirements.txt format.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `format`: Export format (`requirements` or `constraints`)
- `output`: Output file path
- `withDev`: Include development dependencies
- `extras`: Include extras
- `withoutHashes`: Exclude hashes

**Example:**
```typescript
// Export production requirements
await mcp.call("poetry_export_requirements", {
  projectPath: "/path/to/project",
  output: "requirements.txt",
  withoutHashes: true
});

// Export with dev dependencies and extras
await mcp.call("poetry_export_requirements", {
  projectPath: "/path/to/project",
  output: "requirements-dev.txt",
  withDev: true,
  extras: ["ml", "viz"]
});
```

#### `poetry_publish`
Build and publish package to PyPI.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `repository`: Repository name (default: pypi)
- `username`: Repository username
- `password`: Repository password
- `token`: API token
- `build`: Build before publishing (default: true)

### Running Commands

#### `poetry_run`
Run a command in the Poetry environment.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `command` (required): Command to run
- `args`: Command arguments

**Example:**
```typescript
// Run tests
await mcp.call("poetry_run", {
  projectPath: "/path/to/project",
  command: "pytest",
  args: ["-v", "--cov=mypackage"]
});

// Run Python script
await mcp.call("poetry_run", {
  projectPath: "/path/to/project",
  command: "python",
  args: ["train.py", "--epochs", "100"]
});
```

### Configuration

#### `poetry_config`
Manage Poetry configuration.

**Parameters:**
- `projectPath`: Path for local config
- `key`: Config key to get/set
- `value`: Config value to set
- `unset`: Unset the config key
- `list`: List all config

#### `poetry_source`
Manage package sources.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `action` (required): One of: `add`, `remove`, `list`
- `name`: Source name (required for add/remove)
- `url`: Source URL (required for add)
- `priority`: Source priority

**Example:**
```typescript
// Add private PyPI repository
await mcp.call("poetry_source", {
  projectPath: "/path/to/project",
  action: "add",
  name: "private-pypi",
  url: "https://pypi.company.com/simple/",
  priority: "supplemental"
});
```

### Lock File Management

#### `poetry_lock`
Lock or update project dependencies.

**Parameters:**
- `projectPath` (required): Path to the Poetry project
- `update`: Update dependencies to latest
- `check`: Check if lock file is up to date

## Common Workflows

### 1. Create a New ML Project

```typescript
// Create project
await mcp.call("poetry_create_project", {
  name: "awesome-ml",
  path: "/Users/username/projects",
  python: "3.11",
  src: true
});

// Set up ML dependencies
await mcp.call("poetry_ml_setup", {
  projectPath: "/Users/username/projects/awesome-ml",
  framework: "pytorch",
  cuda: true
});

// Add specific ML tools
await mcp.call("poetry_add_dependency", {
  projectPath: "/Users/username/projects/awesome-ml",
  packages: ["wandb", "hydra-core", "pytorch-lightning"]
});
```

### 2. Resolve Dependency Conflicts

```typescript
// Check for conflicts
const conflicts = await mcp.call("poetry_check_conflicts", {
  projectPath: "/path/to/project"
});

// View dependency tree
const tree = await mcp.call("poetry_dependency_tree", {
  projectPath: "/path/to/project",
  depth: 2
});

// Update specific packages
await mcp.call("poetry_update_dependency", {
  projectPath: "/path/to/project",
  packages: ["numpy", "pandas"],
  dry: true  // Check what would be updated first
});
```

### 3. Prepare for Production

```typescript
// Export requirements
await mcp.call("poetry_export_requirements", {
  projectPath: "/path/to/project",
  output: "requirements.txt",
  withoutHashes: true
});

// Build package
await mcp.call("poetry_run", {
  projectPath: "/path/to/project",
  command: "poetry",
  args: ["build"]
});

// Publish to PyPI
await mcp.call("poetry_publish", {
  projectPath: "/path/to/project",
  token: process.env.PYPI_TOKEN
});
```

### 4. Managing Multiple Python Versions

```typescript
// Install Python versions
await mcp.call("poetry_pyenv", {
  action: "install",
  version: "3.10.13"
});

await mcp.call("poetry_pyenv", {
  action: "install",
  version: "3.11.7"
});

// Set project-specific version
await mcp.call("poetry_pyenv", {
  action: "local",
  version: "3.11.7",
  projectPath: "/path/to/project"
});

// Check environment
await mcp.call("poetry_env_info", {
  projectPath: "/path/to/project"
});
```

## Best Practices

1. **Always use virtual environments**: Poetry creates them automatically in project directories
2. **Lock dependencies**: Commit `poetry.lock` for reproducible builds
3. **Use dependency groups**: Separate dev, test, and docs dependencies
4. **Specify Python version**: Use `python = "^3.11"` in pyproject.toml
5. **Regular updates**: Use `poetry_update_dependency` with dry run first
6. **Export for Docker**: Use `poetry_export_requirements` for container builds

## Troubleshooting

### Common Issues

1. **Poetry not found**: Ensure Poetry is in your PATH
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

2. **Pyenv Python not recognized**: Initialize pyenv in your shell
   ```bash
   eval "$(pyenv init -)"
   ```

3. **Dependency conflicts**: Use `poetry_check_conflicts` with `fix: true`

4. **Lock file out of sync**: Run `poetry_lock` with `update: true`

## Development

To contribute or modify the MCP server:

1. Clone and install dependencies:
   ```bash
   npm install
   ```

2. Run in development mode:
   ```bash
   npm run dev
   ```

3. Test with MCP inspector:
   ```bash
   npm run inspector
   ```

## License

MIT License - See LICENSE file for details.