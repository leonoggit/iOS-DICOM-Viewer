# MCP Troubleshooting Guide
## Comprehensive Solutions for iOS DICOM Viewer MCP Environment Issues

---

## 🚨 Common Issues & Solutions

This guide provides solutions for the most common issues encountered when setting up and using the MCP ecosystem for iOS DICOM Viewer development.

---

## 📋 Table of Contents

1. [Environment Setup Issues](#environment-setup-issues)
2. [Server Installation Problems](#server-installation-problems)
3. [Server Startup Failures](#server-startup-failures)
4. [Claude Code Integration Issues](#claude-code-integration-issues)
5. [Custom Server Build Problems](#custom-server-build-problems)
6. [GitHub Integration Issues](#github-integration-issues)
7. [Performance Problems](#performance-problems)
8. [Medical Compliance Issues](#medical-compliance-issues)
9. [Diagnostic Commands](#diagnostic-commands)
10. [Recovery Procedures](#recovery-procedures)

---

## 🛠️ Environment Setup Issues

### Issue 1: Node.js Version Incompatibility

**Symptoms**: 
```
Node.js version v23.11.0 may not be compatible. Recommended: v18.x, v20.x, or v22.x
```

**Root Cause**: MCP servers require specific Node.js versions for optimal compatibility.

**Solutions**:

1. **Install Compatible Node.js Version**:
   ```bash
   # Using nvm (recommended)
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   source ~/.bashrc
   nvm install 20
   nvm use 20
   
   # Or using Homebrew
   brew uninstall node
   brew install node@20
   brew link node@20
   ```

2. **Verify Installation**:
   ```bash
   node --version  # Should show v20.x.x
   npm --version   # Should show compatible npm version
   ```

3. **Update PATH if needed**:
   ```bash
   echo 'export PATH="/opt/homebrew/opt/node@20/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

### Issue 2: Missing Environment Variables

**Symptoms**:
```
Required environment variable GITHUB_TOKEN is not set
```

**Root Cause**: MCP servers require specific environment variables for authentication.

**Solutions**:

1. **Create GitHub Token**:
   - Go to GitHub Settings → Developer Settings → Personal Access Tokens
   - Generate new token with permissions: `repo`, `read:org`, `read:user`
   - Copy the token (you won't see it again)

2. **Set Environment Variables**:
   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   export GITHUB_TOKEN="ghp_your_token_here"
   
   # Optional but recommended
   export BRAVE_API_KEY="your_brave_api_key"
   export POSTGRES_CONNECTION_STRING="postgresql://user:pass@host:port/db"
   
   # Reload shell
   source ~/.zshrc
   ```

3. **Verify Environment**:
   ```bash
   echo $GITHUB_TOKEN  # Should show your token
   node -e "console.log(process.env.GITHUB_TOKEN ? 'Token set' : 'Token missing')"
   ```

---

## 📦 Server Installation Problems

### Issue 3: Missing MCP Server Packages

**Symptoms**:
```
Package @modelcontextprotocol/server-github is not installed or accessible
```

**Root Cause**: Required MCP server packages are not installed.

**Solutions**:

1. **Install Missing Packages**:
   ```bash
   cd /Users/leandroalmeida/iOS_DICOM/MCPs
   
   # Install all required packages
   npm install @modelcontextprotocol/server-filesystem
   npm install @modelcontextprotocol/server-memory
   npm install @modelcontextprotocol/server-github
   npm install @modelcontextprotocol/server-brave-search
   npm install @modelcontextprotocol/server-postgres
   ```

2. **Verify Installation**:
   ```bash
   npm list --depth=0
   # Should show all @modelcontextprotocol packages
   ```

3. **Fix npm Cache Issues**:
   ```bash
   npm cache clean --force
   rm -rf node_modules package-lock.json
   npm install
   ```

### Issue 4: Custom Server Build Failures

**Symptoms**:
```
Built server custom-dicom-mcp/dist/index.js not found. Run npm run build in custom-dicom-mcp
```

**Root Cause**: Custom MCP servers need to be compiled from TypeScript.

**Solutions**:

1. **Build All Custom Servers**:
   ```bash
   cd /Users/leandroalmeida/iOS_DICOM/MCPs
   
   # Build custom DICOM server
   cd custom-dicom-mcp
   npm install
   npm run build
   cd ..
   
   # Build Swift tools server
   cd swift-tools-mcp
   npm install
   npm run build
   cd ..
   
   # Build GitHub Copilot server
   cd github-copilot-medical-ios
   npm install
   npm run build
   cd ..
   ```

2. **Check Build Results**:
   ```bash
   ls -la custom-dicom-mcp/dist/
   ls -la swift-tools-mcp/dist/
   ls -la github-copilot-medical-ios/dist/
   # Should show index.js files
   ```

3. **Fix TypeScript Compilation Errors**:
   ```bash
   # Check for TypeScript errors
   cd custom-dicom-mcp
   npx tsc --noEmit
   
   # Install missing dependencies
   npm install --save-dev typescript @types/node
   ```

---

## 🚀 Server Startup Failures

### Issue 5: Server Timeout During Startup

**Symptoms**:
```
Server filesystem startup timeout after 30000ms
```

**Root Cause**: Servers taking too long to start or failing silently.

**Solutions**:

1. **Test Individual Server Startup**:
   ```bash
   # Test filesystem server
   npx @modelcontextprotocol/server-filesystem /Users/leandroalmeida/iOS_DICOM
   
   # Test memory server
   npx @modelcontextprotocol/server-memory
   
   # Test custom server
   node custom-dicom-mcp/dist/index.js
   ```

2. **Check Server Logs**:
   ```bash
   # Run with debug output
   DEBUG=* npx @modelcontextprotocol/server-filesystem /Users/leandroalmeida/iOS_DICOM
   ```

3. **Increase Timeout**:
   ```javascript
   // In test files, increase timeout values
   const testTimeout = 60000; // Increase from 30000 to 60000ms
   ```

### Issue 6: Permission Errors

**Symptoms**:
```
EACCES: permission denied, open '/Users/leandroalmeida/iOS_DICOM'
```

**Root Cause**: File system permissions preventing server access.

**Solutions**:

1. **Fix Directory Permissions**:
   ```bash
   chmod -R 755 /Users/leandroalmeida/iOS_DICOM
   chown -R $(whoami) /Users/leandroalmeida/iOS_DICOM
   ```

2. **Check macOS Privacy Settings**:
   - System Preferences → Security & Privacy → Privacy
   - Full Disk Access → Add Terminal/VS Code
   - Files and Folders → Add applications as needed

3. **Test Access**:
   ```bash
   ls -la /Users/leandroalmeida/iOS_DICOM
   touch /Users/leandroalmeida/iOS_DICOM/test.txt
   rm /Users/leandroalmeida/iOS_DICOM/test.txt
   ```

---

## 🤖 Claude Code Integration Issues

### Issue 7: Claude Code Not Recognizing MCP Servers

**Symptoms**:
```
Claude Code configuration not found. MCP servers may need manual configuration.
```

**Root Cause**: Claude Code needs to be configured to use MCP servers.

**Solutions**:

1. **Create Claude Code Configuration**:
   ```bash
   mkdir -p ~/.config/claude-code
   ```

2. **Copy MCP Configuration**:
   ```bash
   cd /Users/leandroalmeida/iOS_DICOM/MCPs
   cp master-mcp-config.json ~/.config/claude-code/config.json
   ```

3. **Verify Configuration**:
   ```bash
   cat ~/.config/claude-code/config.json
   # Should show all MCP server definitions
   ```

4. **Restart Claude Code**:
   - Close Claude Code completely
   - Reopen and verify MCP servers are available

### Issue 8: MCP Server Connection Errors

**Symptoms**: Claude Code shows "Server connection failed" or similar errors.

**Root Cause**: Network issues, firewall blocking, or server configuration problems.

**Solutions**:

1. **Check Server Status**:
   ```bash
   # Test if servers are responding
   curl -X POST http://localhost:3000/health || echo "Server not responding"
   ```

2. **Verify Network Configuration**:
   ```bash
   # Check for port conflicts
   lsof -i :3000
   netstat -an | grep LISTEN
   ```

3. **Update Firewall Settings**:
   ```bash
   # Allow local connections (macOS)
   sudo pfctl -d  # Disable firewall temporarily for testing
   ```

---

## 🏥 GitHub Integration Issues

### Issue 9: GitHub Authentication Failures

**Symptoms**:
```
GitHub server fails to authenticate
Environment not ready: 5/6 checks passed
```

**Root Cause**: Invalid or expired GitHub token, or insufficient permissions.

**Solutions**:

1. **Verify Token Validity**:
   ```bash
   curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
   # Should return user information
   ```

2. **Check Token Permissions**:
   - Token needs: `repo`, `read:org`, `read:user`, `write:repo_hook`
   - For private repos: also need `repo:status`

3. **Generate New Token**:
   ```bash
   # If token is expired or invalid
   # Go to GitHub → Settings → Developer settings → Personal access tokens
   # Generate new token with required scopes
   export GITHUB_TOKEN="new_token_here"
   ```

4. **Test GitHub Server**:
   ```bash
   GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN npx @modelcontextprotocol/server-github
   ```

---

## 🔧 Custom Server Build Problems

### Issue 10: TypeScript Compilation Errors

**Symptoms**:
```
Error: Cannot find module '@types/node'
TypeScript compilation failed
```

**Root Cause**: Missing TypeScript dependencies or configuration issues.

**Solutions**:

1. **Install TypeScript Dependencies**:
   ```bash
   cd custom-dicom-mcp
   npm install --save-dev typescript @types/node ts-node
   npm install --save-dev @types/uuid @types/lodash
   ```

2. **Fix TypeScript Configuration**:
   ```json
   // tsconfig.json
   {
     "compilerOptions": {
       "target": "ES2020",
       "module": "commonjs",
       "outDir": "./dist",
       "rootDir": "./src",
       "strict": true,
       "esModuleInterop": true,
       "skipLibCheck": true,
       "forceConsistentCasingInFileNames": true,
       "resolveJsonModule": true
     },
     "include": ["src/**/*"],
     "exclude": ["node_modules", "dist"]
   }
   ```

3. **Clean and Rebuild**:
   ```bash
   rm -rf dist node_modules package-lock.json
   npm install
   npm run build
   ```

### Issue 11: Module Import Errors

**Symptoms**:
```
Error: Cannot resolve module './tools/dicom-parser'
Module not found: Error: Can't resolve
```

**Root Cause**: Incorrect import paths or missing module exports.

**Solutions**:

1. **Fix Import Paths**:
   ```typescript
   // Use explicit file extensions
   import { DICOMParser } from './tools/dicom-parser.js';
   
   // Or use index files
   import { DICOMParser } from './tools/';
   ```

2. **Add Missing Exports**:
   ```typescript
   // src/tools/index.ts
   export { DICOMParser } from './dicom-parser';
   export { MetadataParser } from './metadata-parser';
   export { ComplianceChecker } from './compliance-checker';
   ```

3. **Check File Structure**:
   ```bash
   find src -name "*.ts" | sort
   # Verify all referenced files exist
   ```

---

## ⚡ Performance Problems

### Issue 12: Slow Server Response Times

**Symptoms**: MCP servers responding slowly, causing timeouts.

**Root Cause**: Resource constraints, inefficient algorithms, or blocking operations.

**Solutions**:

1. **Monitor Resource Usage**:
   ```bash
   # Check CPU and memory usage
   top -o cpu
   htop  # If installed
   
   # Check disk I/O
   iostat -d 1
   ```

2. **Optimize Server Code**:
   ```typescript
   // Use async/await properly
   async function processDICOM(data: Buffer): Promise<DICOMMetadata> {
     // Avoid blocking operations
     return new Promise((resolve) => {
       setImmediate(() => {
         const result = parseData(data);
         resolve(result);
       });
     });
   }
   ```

3. **Increase System Limits**:
   ```bash
   # Increase Node.js memory limit
   export NODE_OPTIONS="--max-old-space-size=8192"
   
   # Increase file descriptor limits
   ulimit -n 65536
   ```

### Issue 13: Memory Leaks

**Symptoms**: Servers consuming increasing amounts of memory over time.

**Root Cause**: Unclosed resources, circular references, or accumulating cache.

**Solutions**:

1. **Profile Memory Usage**:
   ```bash
   # Use Node.js built-in profiler
   node --inspect custom-dicom-mcp/dist/index.js
   # Open Chrome DevTools → Memory tab
   ```

2. **Fix Common Memory Leaks**:
   ```typescript
   // Close resources properly
   class DICOMProcessor {
     private cleanup() {
       this.cache.clear();
       this.eventListeners.forEach(listener => listener.remove());
       this.fileHandles.forEach(handle => handle.close());
     }
   }
   
   // Use WeakMap for caching
   private cache = new WeakMap<DICOMFile, Metadata>();
   ```

3. **Monitor Memory Usage**:
   ```typescript
   // Add memory monitoring
   setInterval(() => {
     const usage = process.memoryUsage();
     console.log(`Memory: ${Math.round(usage.heapUsed / 1024 / 1024)}MB`);
   }, 30000);
   ```

---

## 🏥 Medical Compliance Issues

### Issue 14: DICOM Validation Failures

**Symptoms**: DICOM files not parsing correctly or validation errors.

**Root Cause**: Non-standard DICOM files or strict validation rules.

**Solutions**:

1. **Validate DICOM Files**:
   ```bash
   # Use DCMTK tools to validate
   dcmdump your_file.dcm
   dciodvfy your_file.dcm
   ```

2. **Implement Tolerant Parsing**:
   ```typescript
   class DICOMParser {
     parseWithFallback(data: Buffer): DICOMMetadata {
       try {
         return this.strictParse(data);
       } catch (error) {
         console.warn('Strict parsing failed, trying tolerant mode:', error);
         return this.tolerantParse(data);
       }
     }
   }
   ```

3. **Add Comprehensive Error Handling**:
   ```typescript
   try {
     const metadata = await parseDICOM(file);
     auditLogger.logSuccess('DICOM_PARSED', file.name);
   } catch (error) {
     auditLogger.logError('DICOM_PARSE_FAILED', file.name, error);
     throw new MedicalError('DICOM parsing failed', error);
   }
   ```

---

## 🔍 Diagnostic Commands

### Quick Diagnostics

```bash
# Environment check
node --version
npm --version
echo $GITHUB_TOKEN | cut -c1-10  # Show first 10 chars only

# Package verification
npm list @modelcontextprotocol/server-filesystem
npm list @modelcontextprotocol/server-memory
npm list @modelcontextprotocol/server-github

# Server build verification
ls -la custom-dicom-mcp/dist/index.js
ls -la swift-tools-mcp/dist/index.js
ls -la github-copilot-medical-ios/dist/index.js

# Project structure verification
ls -la /Users/leandroalmeida/iOS_DICOM/iOS_DICOMViewer.xcodeproj
find /Users/leandroalmeida/iOS_DICOM/iOS_DICOMViewer -name "*.swift" | wc -l
find /Users/leandroalmeida/iOS_DICOM/iOS_DICOMViewer -name "*.metal" | wc -l

# Permission check
touch /Users/leandroalmeida/iOS_DICOM/test.tmp && rm /Users/leandroalmeida/iOS_DICOM/test.tmp

# Network connectivity
curl -s https://api.github.com/zen
ping -c 3 8.8.8.8
```

### Comprehensive Test Run

```bash
cd /Users/leandroalmeida/iOS_DICOM/MCPs

# Run all tests
node comprehensive-mcp-test-suite.js
node integration-test-scenarios.js

# Individual server tests
npx @modelcontextprotocol/server-filesystem /Users/leandroalmeida/iOS_DICOM &
sleep 3
kill %1

# Custom server tests
node custom-dicom-mcp/dist/index.js &
sleep 3
kill %1
```

---

## 🛡️ Recovery Procedures

### Complete Environment Reset

If all else fails, use this nuclear option:

```bash
# 1. Backup current state
cp -r /Users/leandroalmeida/iOS_DICOM/MCPs /Users/leandroalmeida/iOS_DICOM/MCPs.backup

# 2. Clean Node.js environment
rm -rf node_modules package-lock.json
npm cache clean --force

# 3. Reinstall everything
npm install
npm run build --workspaces

# 4. Rebuild custom servers
cd custom-dicom-mcp && npm install && npm run build && cd ..
cd swift-tools-mcp && npm install && npm run build && cd ..
cd github-copilot-medical-ios && npm install && npm run build && cd ..

# 5. Verify environment
node comprehensive-mcp-test-suite.js
```

### Configuration Reset

```bash
# Reset Claude Code configuration
rm -rf ~/.config/claude-code
mkdir -p ~/.config/claude-code
cp master-mcp-config.json ~/.config/claude-code/config.json

# Reset environment variables
unset GITHUB_TOKEN BRAVE_API_KEY POSTGRES_CONNECTION_STRING
# Re-add them to ~/.zshrc
```

---

## 📞 Getting Help

### Log Collection

Before seeking help, collect diagnostic information:

```bash
# Create diagnostic report
echo "=== Environment ===" > diagnostic-report.txt
node --version >> diagnostic-report.txt
npm --version >> diagnostic-report.txt
echo "GITHUB_TOKEN: $(echo $GITHUB_TOKEN | cut -c1-10)..." >> diagnostic-report.txt

echo -e "\n=== Package List ===" >> diagnostic-report.txt
npm list --depth=0 >> diagnostic-report.txt

echo -e "\n=== Test Results ===" >> diagnostic-report.txt
node comprehensive-mcp-test-suite.js >> diagnostic-report.txt 2>&1

echo -e "\n=== File Structure ===" >> diagnostic-report.txt
find . -name "*.js" -o -name "*.json" -o -name "*.md" | grep -E "(dist|config)" >> diagnostic-report.txt
```

### Common Support Resources

- **MCP Protocol Issues**: [MCP GitHub Repository](https://github.com/modelcontextprotocol)
- **Node.js Issues**: [Node.js Documentation](https://nodejs.org/docs/)
- **iOS Development**: [Apple Developer Documentation](https://developer.apple.com/)
- **DICOM Standards**: [DICOM Standard Documentation](https://www.dicomstandard.org/)

---

## 📈 Prevention

### Regular Maintenance

```bash
# Weekly maintenance script
#!/bin/bash

# Update packages
npm update

# Rebuild custom servers
npm run build --workspaces

# Run health checks
node comprehensive-mcp-test-suite.js

# Clean caches
npm cache clean --force
```

### Monitoring

```bash
# Add to crontab for daily health checks
0 9 * * * cd /Users/leandroalmeida/iOS_DICOM/MCPs && node comprehensive-mcp-test-suite.js > /tmp/mcp-health.log 2>&1
```

---

**Last Updated**: January 6, 2025  
**Version**: 1.0.0  
**Tested With**: Node.js 20.x, macOS 14+, Claude Code 1.0+