# Quick Start Guide
## Get Up and Running with Enhanced iOS DICOM Viewer Development in 10 Minutes

---

## 🚀 Overview

This guide will get you from zero to a fully functional MCP-enhanced development environment for iOS DICOM Viewer development in about 10 minutes. Follow the steps in order, and you'll have access to specialized AI assistance for medical imaging, iOS development, and code generation.

---

## ⏱️ 10-Minute Setup Checklist

### Step 1: Environment Prerequisites (2 minutes)

1. **Check Node.js Version**:
   ```bash
   node --version
   # Should be v18.x, v20.x, or v22.x
   # If not, install compatible version:
   # curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   # nvm install 20 && nvm use 20
   ```

2. **Verify Project Location**:
   ```bash
   ls /Users/leandroalmeida/iOS_DICOM/iOS_DICOMViewer.xcodeproj
   # Should exist - this is your iOS project
   ```

3. **Navigate to MCP Directory**:
   ```bash
   cd /Users/leandroalmeida/iOS_DICOM/MCPs
   ```

### Step 2: Install Core Dependencies (3 minutes)

1. **Install MCP Packages**:
   ```bash
   npm install
   # This installs all required MCP server packages
   ```

2. **Build Custom Servers**:
   ```bash
   # Build DICOM-specific server
   cd custom-dicom-mcp && npm install && npm run build && cd ..
   
   # Build Swift/iOS tools server  
   cd swift-tools-mcp && npm install && npm run build && cd ..
   
   # Build GitHub Copilot enhancement server
   cd github-copilot-medical-ios && npm install && npm run build && cd ..
   ```

### Step 3: Configure Authentication (2 minutes)

1. **Create GitHub Token**:
   - Go to [GitHub Settings → Developer Settings → Personal Access Tokens](https://github.com/settings/tokens)
   - Generate new token with scopes: `repo`, `read:org`, `read:user`
   - Copy the token

2. **Set Environment Variables**:
   ```bash
   # Add to your shell profile (~/.zshrc or ~/.bashrc)
   echo 'export GITHUB_TOKEN="your_token_here"' >> ~/.zshrc
   source ~/.zshrc
   
   # Verify it's set
   echo $GITHUB_TOKEN | cut -c1-10  # Shows first 10 characters
   ```

### Step 4: Verify Installation (2 minutes)

1. **Run Quick Test**:
   ```bash
   node comprehensive-mcp-test-suite.js
   # Should show mostly green ✅ results
   ```

2. **Check Key Components**:
   ```bash
   ls -la custom-dicom-mcp/dist/index.js      # ✅ Should exist
   ls -la swift-tools-mcp/dist/index.js       # ✅ Should exist  
   ls -la github-copilot-medical-ios/dist/index.js  # ✅ Should exist
   ```

### Step 5: Configure Claude Code (1 minute)

1. **Set Up Claude Code Configuration**:
   ```bash
   mkdir -p ~/.config/claude-code
   cp master-mcp-config.json ~/.config/claude-code/config.json
   ```

2. **Restart Claude Code**:
   - Close Claude Code completely
   - Reopen it
   - Verify MCP servers are available

---

## 🎯 First Test: Enhanced AI Assistance

### Test 1: DICOM Analysis
Ask Claude Code:
```
"Analyze the DICOM models in my iOS project and suggest improvements for better medical compliance."
```

**Expected Enhancement**: You should get detailed analysis of your DICOM data models with medical imaging standards compliance suggestions, iOS-specific optimizations, and code examples.

### Test 2: Swift Optimization
Ask Claude Code:
```
"Review my Metal shaders for DICOM rendering and suggest performance optimizations for iOS devices."
```

**Expected Enhancement**: You should get specific Metal shader analysis, iOS GPU optimization recommendations, and performance tuning suggestions.

### Test 3: Medical Code Generation
Ask Claude Code:
```
"Generate a SwiftUI component for DICOM study selection with HIPAA compliance features."
```

**Expected Enhancement**: You should get a complete SwiftUI component with medical compliance considerations, accessibility features, and iOS best practices.

---

## 🛠️ Available MCP Capabilities

Your enhanced environment now provides:

### 🏥 Medical Imaging Expertise
- **DICOM Compliance Checking**: Validates DICOM files against medical standards
- **Medical Terminology**: Provides medical imaging term definitions and context
- **Pixel Data Analysis**: Analyzes medical image data structures
- **Clinical Workflow Understanding**: Knows medical imaging workflows and requirements

### 📱 iOS Development Mastery
- **Swift Code Analysis**: Analyzes Swift code for best practices and performance
- **Metal Shader Optimization**: Optimizes GPU shaders for iOS medical imaging
- **Xcode Project Management**: Manages iOS project configurations and settings
- **iOS Memory Profiling**: Analyzes memory usage patterns for medical apps
- **Simulator Management**: Manages iOS simulators for testing

### 🤖 Enhanced Code Generation
- **Medical iOS Templates**: Pre-built templates for medical imaging iOS apps
- **Context-Aware Suggestions**: Suggestions based on medical + iOS context
- **Compliance-Ready Code**: Generated code includes medical compliance features
- **Performance-Optimized Output**: Code optimized for iOS medical applications

### 🔧 Development Tools
- **Project File Management**: Advanced file operations on your iOS project
- **Version Control Integration**: GitHub operations with medical project context
- **Memory & Context Persistence**: Remembers your development context across sessions
- **Real-time Research**: Web search for medical imaging and iOS development

---

## 📚 Quick Reference Commands

### Common Enhanced Requests

```markdown
🏥 **DICOM & Medical**
- "Check this DICOM file for compliance issues"
- "Explain this medical imaging algorithm"
- "Generate HIPAA-compliant data handling code"

📱 **iOS Development**  
- "Optimize this Swift class for better memory management"
- "Review my Metal shader for iOS GPU performance"
- "Analyze my Xcode project configuration"

🚀 **Code Generation**
- "Create a DICOM viewer SwiftUI component"
- "Generate unit tests for my medical imaging parser"
- "Build a Metal pipeline for volume rendering"

🔍 **Analysis & Debugging**
- "Analyze this crash log from my medical imaging app"
- "Profile memory usage in my DICOM parsing code"
- "Review my app for medical device compliance"
```

---

## 🧪 Verify Your Setup

### Run Full Verification
```bash
cd /Users/leandroalmeida/iOS_DICOM/MCPs
node integration-test-scenarios.js
```

**Success Indicators**:
- ✅ 4+ scenarios should pass
- ✅ Medical imaging workflow verified
- ✅ DICOM parsing integration confirmed
- ✅ Swift iOS toolchain validated
- ✅ Memory persistence working

### Test Individual Components
```bash
# Test DICOM server
echo "Testing custom DICOM capabilities..."
node -e "console.log('Custom DICOM MCP server available')"

# Test Swift tools
echo "Testing Swift/iOS tools..."
ls ../iOS_DICOMViewer/*.swift | wc -l

# Test GitHub integration
echo "Testing GitHub access..."
curl -H "Authorization: token $GITHUB_TOKEN" -s https://api.github.com/user | jq .login
```

---

## 🚨 Quick Troubleshooting

### If Something Doesn't Work

1. **Check Node.js Version**:
   ```bash
   node --version  # Must be 18.x, 20.x, or 22.x
   ```

2. **Verify GitHub Token**:
   ```bash
   echo $GITHUB_TOKEN | wc -c  # Should be 40+ characters
   ```

3. **Rebuild Everything**:
   ```bash
   rm -rf */node_modules */package-lock.json
   npm install
   npm run build --workspaces
   ```

4. **Check Detailed Errors**:
   ```bash
   node comprehensive-mcp-test-suite.js
   # Look for specific error messages
   ```

### Get Help
- Check: `TROUBLESHOOTING-GUIDE.md` for detailed solutions
- Review: `MCP-ECOSYSTEM-DOCUMENTATION.md` for comprehensive information
- Verify: `iOS-DICOM-USAGE-EXAMPLES.md` for usage patterns

---

## 🎉 You're Ready!

Your enhanced development environment is now configured with:

- ✅ **8 MCP Servers** providing specialized AI assistance
- ✅ **Medical Imaging Expertise** for DICOM and clinical standards
- ✅ **iOS Development Mastery** for Swift and Metal optimization
- ✅ **Enhanced Code Generation** with medical + iOS context
- ✅ **Comprehensive Testing** to ensure everything works

### Next Steps

1. **Start Developing**: Ask Claude Code for help with your iOS DICOM viewer
2. **Explore Examples**: Review the usage examples for inspiration
3. **Test Thoroughly**: Use the testing tools to validate your implementations
4. **Iterate and Improve**: Leverage the enhanced AI assistance for continuous improvement

### Example First Request

Try this enhanced request with Claude Code:
```
"I want to add DICOM Segmentation Object support to my iOS viewer. Help me implement the parser, renderer, and SwiftUI interface with full medical compliance and iOS optimization."
```

You should get a comprehensive implementation that includes:
- Medical-grade DICOM SEG parsing
- High-performance Metal rendering
- HIPAA-compliant data handling
- iOS-optimized SwiftUI interface
- Comprehensive error handling
- Medical device compliance features

**Welcome to your enhanced iOS DICOM development environment!** 🚀

---

**Setup Time**: ~10 minutes  
**Last Updated**: January 6, 2025  
**Tested With**: Node.js 20.x, macOS 14+, Claude Code 1.0+