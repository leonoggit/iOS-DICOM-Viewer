#!/bin/bash

# Setup script for Claude Code MCP integration with iOS DICOM Viewer project
# This script configures all MCP servers for optimal medical imaging and iOS development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/Users/leandroalmeida/iOS_DICOM"
MCP_DIR="$PROJECT_ROOT/MCPs"
CLAUDE_CONFIG_DIR="$HOME/.config/claude-code"
CLAUDE_MCP_CONFIG="$CLAUDE_CONFIG_DIR/mcp_settings.json"

echo -e "${BLUE}🏥 iOS DICOM Viewer - Claude Code MCP Setup${NC}"
echo "=============================================="

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check prerequisites
echo -e "\n${BLUE}Checking prerequisites...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//')
REQUIRED_VERSION="18.0.0"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    print_error "Node.js version $NODE_VERSION is too old. Please install Node.js 18+ first."
    exit 1
fi
print_status "Node.js $NODE_VERSION detected"

# Check npm
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm first."
    exit 1
fi
print_status "npm $(npm -v) detected"

# Check if we're in the right directory
if [ ! -d "$PROJECT_ROOT" ]; then
    print_error "iOS DICOM project not found at $PROJECT_ROOT"
    exit 1
fi
print_status "iOS DICOM project found at $PROJECT_ROOT"

# Check GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    print_warning "GITHUB_TOKEN environment variable not set. GitHub MCP server will have limited functionality."
    echo "To set up GitHub integration, run: export GITHUB_TOKEN=your_token_here"
else
    print_status "GitHub token configured"
fi

# Create Claude Code config directory
echo -e "\n${BLUE}Setting up Claude Code configuration...${NC}"
mkdir -p "$CLAUDE_CONFIG_DIR"
print_status "Claude Code config directory created"

# Build all MCP servers
echo -e "\n${BLUE}Building MCP servers...${NC}"

# Build custom DICOM MCP
print_info "Building custom DICOM MCP server..."
cd "$MCP_DIR/custom-dicom-mcp"
if [ ! -d "node_modules" ]; then
    npm install
fi
npm run build
print_status "Custom DICOM MCP server built"

# Build Swift tools MCP
print_info "Building Swift tools MCP server..."
cd "$MCP_DIR/swift-tools-mcp"
if [ ! -d "node_modules" ]; then
    npm install
fi
npm run build
print_status "Swift tools MCP server built"

# Build GitHub Copilot medical iOS MCP
print_info "Building GitHub Copilot medical iOS MCP server..."
cd "$MCP_DIR/github-copilot-medical-ios"
if [ ! -d "node_modules" ]; then
    npm install
fi
npm run build
print_status "GitHub Copilot medical iOS MCP server built"

# Generate Claude Code MCP configuration
echo -e "\n${BLUE}Generating Claude Code MCP configuration...${NC}"

# Create the main MCP configuration for Claude Code
cat > "$CLAUDE_MCP_CONFIG" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$PROJECT_ROOT"
      ]
    },
    "memory": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ]
    },
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "\${GITHUB_TOKEN}"
      }
    },
    "custom-dicom-mcp": {
      "command": "node",
      "args": [
        "$MCP_DIR/custom-dicom-mcp/dist/index.js"
      ]
    },
    "swift-tools-mcp": {
      "command": "node",
      "args": [
        "$MCP_DIR/swift-tools-mcp/dist/index.js"
      ]
    },
    "github-copilot-medical-ios": {
      "command": "node",
      "args": [
        "$MCP_DIR/github-copilot-medical-ios/dist/index.js"
      ]
    }
  }
}
EOF

print_status "Claude Code MCP configuration generated at $CLAUDE_MCP_CONFIG"

# Create a workspace-specific .vscode/mcp.json for VS Code integration
echo -e "\n${BLUE}Setting up VS Code MCP integration...${NC}"
VSCODE_CONFIG_DIR="$PROJECT_ROOT/.vscode"
VSCODE_MCP_CONFIG="$VSCODE_CONFIG_DIR/mcp.json"

mkdir -p "$VSCODE_CONFIG_DIR"

cat > "$VSCODE_MCP_CONFIG" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$PROJECT_ROOT"
      ]
    },
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "\${GITHUB_TOKEN}"
      }
    },
    "custom-dicom-mcp": {
      "command": "node",
      "args": [
        "$MCP_DIR/custom-dicom-mcp/dist/index.js"
      ]
    },
    "swift-tools-mcp": {
      "command": "node",
      "args": [
        "$MCP_DIR/swift-tools-mcp/dist/index.js"
      ]
    },
    "github-copilot-medical-ios": {
      "command": "node",
      "args": [
        "$MCP_DIR/github-copilot-medical-ios/dist/index.js"
      ]
    }
  }
}
EOF

print_status "VS Code MCP configuration created at $VSCODE_MCP_CONFIG"

# Test MCP servers
echo -e "\n${BLUE}Testing MCP servers...${NC}"

test_mcp_server() {
    local server_name=$1
    local server_path=$2
    
    print_info "Testing $server_name..."
    
    # Test if the server can start (just basic validation)
    if timeout 5s node "$server_path" --version &> /dev/null || timeout 5s node "$server_path" --help &> /dev/null; then
        print_status "$server_name is working"
    else
        # Even if --version/--help fails, test if the file exists and is valid JS
        if [ -f "$server_path" ]; then
            if node -c "$server_path" &> /dev/null; then
                print_status "$server_name syntax is valid"
            else
                print_warning "$server_name has syntax errors"
            fi
        else
            print_error "$server_name not found at $server_path"
        fi
    fi
}

test_mcp_server "Custom DICOM MCP" "$MCP_DIR/custom-dicom-mcp/dist/index.js"
test_mcp_server "Swift Tools MCP" "$MCP_DIR/swift-tools-mcp/dist/index.js"
test_mcp_server "GitHub Copilot Medical iOS MCP" "$MCP_DIR/github-copilot-medical-ios/dist/index.js"

# Create environment setup script
echo -e "\n${BLUE}Creating environment setup script...${NC}"

cat > "$MCP_DIR/setup-environment.sh" << 'EOF'
#!/bin/bash

# Environment setup for iOS DICOM Viewer MCP servers
# Run this script to set up your environment variables

echo "Setting up environment for iOS DICOM Viewer MCP servers..."

# GitHub token (required for GitHub MCP server)
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Please set your GitHub token:"
    echo "export GITHUB_TOKEN=your_github_token_here"
    echo ""
    echo "To create a GitHub token:"
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Generate a new token with repo, issues, and pull_requests scopes"
    echo "3. Copy the token and export it as GITHUB_TOKEN"
else
    echo "✓ GITHUB_TOKEN is set"
fi

# Optional: Brave Search API key
if [ -z "$BRAVE_API_KEY" ]; then
    echo ""
    echo "Optional: Set up Brave Search API key for web search capabilities:"
    echo "export BRAVE_API_KEY=your_brave_api_key_here"
else
    echo "✓ BRAVE_API_KEY is set"
fi

# Optional: PostgreSQL connection string
if [ -z "$POSTGRES_CONNECTION_STRING" ]; then
    echo ""
    echo "Optional: Set up PostgreSQL connection for DICOM metadata storage:"
    echo "export POSTGRES_CONNECTION_STRING=postgresql://user:password@localhost:5432/dicom_db"
else
    echo "✓ POSTGRES_CONNECTION_STRING is set"
fi

echo ""
echo "Add these exports to your ~/.bashrc, ~/.zshrc, or ~/.profile to make them permanent"
EOF

chmod +x "$MCP_DIR/setup-environment.sh"
print_status "Environment setup script created"

# Create MCP server management script
echo -e "\n${BLUE}Creating MCP server management script...${NC}"

cat > "$MCP_DIR/manage-mcp-servers.sh" << 'EOF'
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
EOF

chmod +x "$MCP_DIR/manage-mcp-servers.sh"
print_status "MCP server management script created"

# Final success message
echo -e "\n${GREEN}🎉 Setup Complete!${NC}"
echo "==================="
echo ""
echo "Your iOS DICOM Viewer project is now configured with the following MCP servers:"
echo ""
echo "🔧 Core Servers:"
echo "  • Filesystem - File operations for the project"
echo "  • Memory - Persistent conversation context"
echo "  • GitHub - Repository management and integration"
echo ""
echo "🏥 Medical Imaging Servers:"
echo "  • Custom DICOM MCP - DICOM parsing, compliance, and medical tools"
echo "  • GitHub Copilot Medical iOS - Enhanced code generation with medical context"
echo ""
echo "📱 iOS Development Servers:"
echo "  • Swift Tools MCP - Swift analysis, Xcode integration, iOS deployment"
echo ""
echo "📋 Next Steps:"
echo "1. Set up environment variables:"
echo "   source $MCP_DIR/setup-environment.sh"
echo ""
echo "2. Test the setup:"
echo "   $MCP_DIR/manage-mcp-servers.sh status"
echo ""
echo "3. Start using Claude Code with enhanced medical imaging and iOS development capabilities!"
echo ""
echo "📁 Configuration files created:"
echo "  • Claude Code: $CLAUDE_MCP_CONFIG"
echo "  • VS Code: $VSCODE_MCP_CONFIG"
echo "  • Master config: $MCP_DIR/master-mcp-config.json"
echo ""
echo -e "${BLUE}Happy coding! 🚀${NC}"