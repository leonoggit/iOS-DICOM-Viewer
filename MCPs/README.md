# MCPs (Model Context Protocol) Setup

This directory contains the MCP setup for the iOS_DICOM project, providing enhanced Claude Code capabilities for medical imaging development.

## Directory Structure

- `custom-dicom-mcp/` - Custom MCP server for DICOM-specific functionality
- `swift-tools-mcp/` - Swift development tools MCP server
- `config/` - Configuration files for MCP servers
- `scripts/` - Setup and utility scripts

## Getting Started

1. Install free MCP servers from the official repository
2. Configure custom DICOM-specific MCP tools
3. Set up Swift development enhancement tools
4. Configure Claude Code to use these MCP servers

## Available MCP Servers

### Official MCP Servers (Installed)
- **@modelcontextprotocol/server-filesystem** v2025.3.28 - File system operations
- **@modelcontextprotocol/server-everything** v2025.5.12 - Comprehensive MCP protocol testing
- **@modelcontextprotocol/server-memory** v2025.4.25 - Memory and knowledge graph capabilities
- **@modelcontextprotocol/server-postgres** v0.6.2 - PostgreSQL database operations
- **@modelcontextprotocol/sdk** v1.12.1 - MCP development SDK (dev dependency)

### Attempted but Not Available
- **@modelcontextprotocol/server-git** - Git operations (package not found in registry)

### Custom MCP Servers
- **custom-dicom-mcp**: DICOM file parsing, metadata extraction, medical imaging utilities
- **swift-tools-mcp**: Swift/iOS development tools, Xcode project management, iOS simulators

## Usage

### Running MCP Servers
```bash
# Navigate to MCPs directory
cd MCPs/

# Filesystem server
npx @modelcontextprotocol/server-filesystem /path/to/directory

# Everything server (MCP protocol testing)
npx @modelcontextprotocol/server-everything

# Memory server
npx @modelcontextprotocol/server-memory
```

### Package Management
```bash
# Install all MCP servers at once
npm run install-mcps

# List installed packages
npm run test-mcps

# Update to latest versions
npm update
```

### Installation Details
- **npm version**: 10.9.2
- **Installation date**: June 10, 2025
- **Total packages installed**: 176 packages
- **Vulnerabilities**: 4 low severity (run `npm audit fix --force` to resolve)
- **Test script**: Run `node test-mcps.js` to verify installations

## Configuration

MCP configurations are stored in the `config/` directory and can be customized for different development environments.