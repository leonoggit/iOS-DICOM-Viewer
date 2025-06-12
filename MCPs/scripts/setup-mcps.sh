#!/bin/bash

# Setup script for MCP servers in iOS_DICOM project
# This script installs and configures MCP servers for enhanced Claude Code capabilities

set -e

echo "🔧 Setting up MCP servers for iOS_DICOM project..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is required but not installed. Please install npm first."
    exit 1
fi

# Navigate to MCPs directory
cd "$(dirname "$0")/.."

echo "📁 Current directory: $(pwd)"

# Setup custom-dicom-mcp
echo "🔧 Setting up custom-dicom-mcp..."
cd custom-dicom-mcp
if [ ! -f "package.json" ]; then
    echo "📦 Initializing custom-dicom-mcp package..."
    npm init -y
    # Will be configured later when we build the custom MCP
fi
cd ..

# Setup swift-tools-mcp  
echo "🔧 Setting up swift-tools-mcp..."
cd swift-tools-mcp
if [ ! -f "package.json" ]; then
    echo "📦 Initializing swift-tools-mcp package..."
    npm init -y
    # Will be configured later when we build the custom MCP
fi
cd ..

echo "✅ MCP directory structure created successfully!"
echo "📋 Next steps:"
echo "   1. Install free MCP servers from official repository"
echo "   2. Develop custom DICOM MCP server"
echo "   3. Develop Swift tools MCP server"
echo "   4. Configure Claude Code to use these MCP servers"

echo "🎯 Ready for MCP development!"