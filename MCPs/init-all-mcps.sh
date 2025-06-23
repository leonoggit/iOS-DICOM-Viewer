#!/bin/bash

# Automatic MCP Server Initialization Script for iOS DICOM Viewer
# This script ensures all required MCP servers are configured when Claude starts in this project

set -e

PROJECT_ROOT="/Users/leandroalmeida/iOS_DICOM"
MCP_DIR="$PROJECT_ROOT/MCPs"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=== iOS DICOM Viewer - MCP Initialization ===${NC}"
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

check_claude_available() {
    if ! command -v claude &> /dev/null; then
        print_error "Claude CLI not found. Please install Claude Code first."
        exit 1
    fi
}

check_and_add_mcp() {
    local name=$1
    local command=$2
    
    if claude mcp get "$name" &> /dev/null; then
        print_status "$name already configured"
    else
        print_warning "Adding $name..."
        claude mcp add "$name" "$command"
        print_status "$name added successfully"
    fi
}

print_header

# Check if Claude CLI is available
check_claude_available

# Check if we're in the correct project directory
if [ ! -f "$PROJECT_ROOT/iOS_DICOMViewer.xcodeproj/project.pbxproj" ]; then
    print_error "Not in iOS DICOM Viewer project directory"
    exit 1
fi

print_status "Found iOS DICOM Viewer project"

# Build custom MCP servers if needed
echo -e "\n${BLUE}Building custom MCP servers...${NC}"

# Build custom DICOM MCP
if [ ! -f "$MCP_DIR/custom-dicom-mcp/dist/index.js" ]; then
    print_warning "Building custom DICOM MCP..."
    cd "$MCP_DIR/custom-dicom-mcp" && npm install && npm run build
    print_status "Custom DICOM MCP built"
else
    print_status "Custom DICOM MCP already built"
fi

# Build Swift tools MCP
if [ ! -f "$MCP_DIR/swift-tools-mcp/dist/index.js" ]; then
    print_warning "Building Swift tools MCP..."
    cd "$MCP_DIR/swift-tools-mcp" && npm install && npm run build
    print_status "Swift tools MCP built"
else
    print_status "Swift tools MCP already built"
fi

# Build GitHub Copilot medical iOS MCP
if [ ! -f "$MCP_DIR/github-copilot-medical-ios/dist/index.js" ]; then
    print_warning "Building GitHub Copilot medical iOS MCP..."
    cd "$MCP_DIR/github-copilot-medical-ios" && npm install && npm run build
    print_status "GitHub Copilot medical iOS MCP built"
else
    print_status "GitHub Copilot medical iOS MCP already built"
fi

# Build CoreML conversion MCP
if [ ! -f "$MCP_DIR/coreml-conversion-mcp/dist/index.js" ]; then
    print_warning "Building CoreML conversion MCP..."
    cd "$MCP_DIR/coreml-conversion-mcp" && npm install && npm run build
    print_status "CoreML conversion MCP built"
else
    print_status "CoreML conversion MCP already built"
fi

# Build Python Poetry MCP
if [ ! -f "$MCP_DIR/python-poetry-mcp/build/index.js" ]; then
    print_warning "Building Python Poetry MCP..."
    cd "$MCP_DIR/python-poetry-mcp" && npm install && npm run build
    print_status "Python Poetry MCP built"
else
    print_status "Python Poetry MCP already built"
fi

cd "$PROJECT_ROOT"

echo -e "\n${BLUE}Configuring MCP servers...${NC}"

# Add all MCP servers
check_and_add_mcp "filesystem" "npx -y @modelcontextprotocol/server-filesystem $PROJECT_ROOT"
check_and_add_mcp "memory" "npx -y @modelcontextprotocol/server-memory"
check_and_add_mcp "github" "npx -y @modelcontextprotocol/server-github"
check_and_add_mcp "brave-search" "npx -y @modelcontextprotocol/server-brave-search"
check_and_add_mcp "postgres" "npx -y @modelcontextprotocol/server-postgres"
check_and_add_mcp "XcodeBuildMCP" "npx -y xcodebuildmcp@latest"
check_and_add_mcp "custom-dicom-mcp" "$MCP_DIR/custom-dicom-mcp/dist/index.js"
check_and_add_mcp "swift-tools-mcp" "$MCP_DIR/swift-tools-mcp/dist/index.js"
check_and_add_mcp "github-copilot-medical-ios" "$MCP_DIR/github-copilot-medical-ios/dist/index.js"
check_and_add_mcp "coreml-conversion-mcp" "$MCP_DIR/coreml-conversion-mcp/dist/index.js"
check_and_add_mcp "python-poetry-mcp" "$MCP_DIR/python-poetry-mcp/build/index.js"

echo -e "\n${BLUE}Verifying configuration...${NC}"

# List all configured servers
echo -e "\n${BLUE}Configured MCP servers:${NC}"
claude mcp list

echo -e "\n${BLUE}Environment variables status:${NC}"
if [ -n "$GITHUB_TOKEN" ]; then
    print_status "GITHUB_TOKEN: Set"
else
    print_warning "GITHUB_TOKEN: Not set (required for GitHub integration)"
fi

if [ -n "$BRAVE_API_KEY" ]; then
    print_status "BRAVE_API_KEY: Set"
else
    print_warning "BRAVE_API_KEY: Not set (optional for web search)"
fi

if [ -n "$POSTGRES_CONNECTION_STRING" ]; then
    print_status "POSTGRES_CONNECTION_STRING: Set"
else
    print_warning "POSTGRES_CONNECTION_STRING: Not set (optional for database)"
fi

echo -e "\n${GREEN}✅ All MCP servers initialized successfully!${NC}"
echo -e "${BLUE}You can now use all medical imaging and iOS development tools in Claude.${NC}"