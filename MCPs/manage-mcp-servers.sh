#!/bin/bash

# MCP Server Management Script for iOS DICOM Viewer

MCP_DIR="/Users/leandroalmeida/iOS_DICOM/MCPs"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

case "$1" in
    "build")
        echo "Building all MCP servers..."
        
        # Build custom DICOM MCP
        echo "Building custom DICOM MCP..."
        cd "$MCP_DIR/custom-dicom-mcp" && npm run build
        print_status "Custom DICOM MCP built"
        
        # Build Swift tools MCP
        echo "Building Swift tools MCP..."
        cd "$MCP_DIR/swift-tools-mcp" && npm run build
        print_status "Swift tools MCP built"
        
        # Build GitHub Copilot medical iOS MCP
        echo "Building GitHub Copilot medical iOS MCP..."
        cd "$MCP_DIR/github-copilot-medical-ios" && npm run build
        print_status "GitHub Copilot medical iOS MCP built"
        ;;
    
    "test")
        echo "Testing MCP servers..."
        
        # Test custom DICOM MCP
        if [ -f "$MCP_DIR/custom-dicom-mcp/dist/index.js" ]; then
            print_status "Custom DICOM MCP build found"
        else
            print_error "Custom DICOM MCP build not found"
        fi
        
        # Test Swift tools MCP
        if [ -f "$MCP_DIR/swift-tools-mcp/dist/index.js" ]; then
            print_status "Swift tools MCP build found"
        else
            print_error "Swift tools MCP build not found"
        fi
        
        # Test GitHub Copilot medical iOS MCP
        if [ -f "$MCP_DIR/github-copilot-medical-ios/dist/index.js" ]; then
            print_status "GitHub Copilot medical iOS MCP build found"
        else
            print_error "GitHub Copilot medical iOS MCP build not found"
        fi
        ;;
    
    "clean")
        echo "Cleaning MCP server builds..."
        rm -rf "$MCP_DIR/custom-dicom-mcp/dist"
        rm -rf "$MCP_DIR/swift-tools-mcp/dist"
        rm -rf "$MCP_DIR/github-copilot-medical-ios/dist"
        print_status "All builds cleaned"
        ;;
    
    "status")
        echo "MCP Server Status:"
        echo "=================="
        
        # Check custom DICOM MCP
        if [ -f "$MCP_DIR/custom-dicom-mcp/dist/index.js" ]; then
            print_status "Custom DICOM MCP: Ready"
        else
            print_warning "Custom DICOM MCP: Not built"
        fi
        
        # Check Swift tools MCP
        if [ -f "$MCP_DIR/swift-tools-mcp/dist/index.js" ]; then
            print_status "Swift tools MCP: Ready"
        else
            print_warning "Swift tools MCP: Not built"
        fi
        
        # Check GitHub Copilot medical iOS MCP
        if [ -f "$MCP_DIR/github-copilot-medical-ios/dist/index.js" ]; then
            print_status "GitHub Copilot medical iOS MCP: Ready"
        else
            print_warning "GitHub Copilot medical iOS MCP: Not built"
        fi
        
        echo ""
        echo "Environment Variables:"
        if [ -n "$GITHUB_TOKEN" ]; then
            print_status "GITHUB_TOKEN: Set"
        else
            print_warning "GITHUB_TOKEN: Not set"
        fi
        
        if [ -n "$BRAVE_API_KEY" ]; then
            print_status "BRAVE_API_KEY: Set"
        else
            print_warning "BRAVE_API_KEY: Not set (optional)"
        fi
        ;;
    
    *)
        echo "Usage: $0 {build|test|clean|status}"
        echo ""
        echo "Commands:"
        echo "  build   - Build all MCP servers"
        echo "  test    - Test MCP server builds"
        echo "  clean   - Clean all builds"
        echo "  status  - Show status of all servers"
        exit 1
        ;;
esac
