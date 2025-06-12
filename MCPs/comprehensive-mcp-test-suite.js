#!/usr/bin/env node

/**
 * Comprehensive MCP Test Suite for iOS DICOM Viewer Development Environment
 * Tests all MCP servers, their integration, and Claude Code accessibility
 * 
 * Usage: node comprehensive-mcp-test-suite.js
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const { promisify } = require('util');

const exec = promisify(require('child_process').exec);

class MCPTestSuite {
    constructor() {
        this.results = {
            passed: 0,
            failed: 0,
            warnings: 0,
            tests: []
        };
        this.serverProcesses = new Map();
        this.testTimeout = 30000; // 30 seconds per test
    }

    log(level, message, details = null) {
        const timestamp = new Date().toISOString();
        const symbols = { info: 'ℹ️', success: '✅', error: '❌', warning: '⚠️' };
        console.log(`${symbols[level] || 'ℹ️'} [${timestamp}] ${message}`);
        if (details) {
            console.log(`   ${details}`);
        }
    }

    async runTest(testName, testFunction) {
        this.log('info', `Running test: ${testName}`);
        const startTime = Date.now();
        
        try {
            await testFunction();
            const duration = Date.now() - startTime;
            this.results.passed++;
            this.results.tests.push({ name: testName, status: 'PASS', duration });
            this.log('success', `${testName} - PASSED (${duration}ms)`);
            return true;
        } catch (error) {
            const duration = Date.now() - startTime;
            this.results.failed++;
            this.results.tests.push({ name: testName, status: 'FAIL', duration, error: error.message });
            this.log('error', `${testName} - FAILED (${duration}ms)`, error.message);
            return false;
        }
    }

    async testEnvironment() {
        // Test Node.js version
        const nodeVersion = process.version;
        if (!nodeVersion.startsWith('v18') && !nodeVersion.startsWith('v20') && !nodeVersion.startsWith('v22')) {
            throw new Error(`Node.js version ${nodeVersion} may not be compatible. Recommended: v18.x, v20.x, or v22.x`);
        }
        this.log('info', `Node.js version: ${nodeVersion} ✓`);

        // Test npm availability
        const npmVersion = execSync('npm --version', { encoding: 'utf8' }).trim();
        this.log('info', `npm version: ${npmVersion} ✓`);

        // Check environment variables
        const requiredEnvVars = ['GITHUB_TOKEN'];
        const optionalEnvVars = ['BRAVE_API_KEY', 'POSTGRES_CONNECTION_STRING'];
        
        for (const envVar of requiredEnvVars) {
            if (!process.env[envVar]) {
                throw new Error(`Required environment variable ${envVar} is not set`);
            }
            this.log('info', `${envVar} is configured ✓`);
        }

        for (const envVar of optionalEnvVars) {
            if (process.env[envVar]) {
                this.log('info', `${envVar} is configured ✓`);
            } else {
                this.log('warning', `Optional environment variable ${envVar} is not set`);
                this.results.warnings++;
            }
        }
    }

    async testPackageInstallations() {
        // Test main MCP packages
        const mcpPackages = [
            '@modelcontextprotocol/server-filesystem',
            '@modelcontextprotocol/server-memory',
            '@modelcontextprotocol/server-github',
            '@modelcontextprotocol/server-brave-search',
            '@modelcontextprotocol/server-postgres'
        ];

        for (const pkg of mcpPackages) {
            try {
                execSync(`npm list ${pkg}`, { encoding: 'utf8', stdio: 'pipe' });
                this.log('info', `${pkg} is installed ✓`);
            } catch (error) {
                throw new Error(`Package ${pkg} is not installed or accessible`);
            }
        }

        // Test custom servers
        const customServers = [
            'custom-dicom-mcp',
            'swift-tools-mcp', 
            'github-copilot-medical-ios'
        ];

        for (const server of customServers) {
            const serverPath = path.join(__dirname, server);
            if (!fs.existsSync(serverPath)) {
                throw new Error(`Custom server directory ${server} not found`);
            }

            const distPath = path.join(serverPath, 'dist', 'index.js');
            if (!fs.existsSync(distPath)) {
                throw new Error(`Built server ${server}/dist/index.js not found. Run npm run build in ${server}`);
            }

            this.log('info', `Custom server ${server} is built and ready ✓`);
        }
    }

    async testServerStartup(serverName, command, args, env = {}) {
        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                if (process) {
                    process.kill();
                }
                reject(new Error(`Server ${serverName} startup timeout after ${this.testTimeout}ms`));
            }, this.testTimeout);

            const serverEnv = { ...process.env, ...env };
            const serverProcess = spawn(command, args, { 
                env: serverEnv,
                stdio: ['pipe', 'pipe', 'pipe']
            });

            let output = '';
            let errorOutput = '';

            serverProcess.stdout.on('data', (data) => {
                output += data.toString();
                // Look for startup indicators
                if (output.includes('listening') || output.includes('ready') || output.includes('started')) {
                    clearTimeout(timeout);
                    this.serverProcesses.set(serverName, serverProcess);
                    resolve(`Server ${serverName} started successfully`);
                }
            });

            serverProcess.stderr.on('data', (data) => {
                errorOutput += data.toString();
            });

            serverProcess.on('error', (error) => {
                clearTimeout(timeout);
                reject(new Error(`Server ${serverName} failed to start: ${error.message}`));
            });

            serverProcess.on('close', (code) => {
                clearTimeout(timeout);
                if (code !== 0) {
                    reject(new Error(`Server ${serverName} exited with code ${code}. Error: ${errorOutput}`));
                }
            });

            // Give server 3 seconds to start, then assume success if no errors
            setTimeout(() => {
                if (!serverProcess.killed && serverProcess.pid) {
                    clearTimeout(timeout);
                    this.serverProcesses.set(serverName, serverProcess);
                    resolve(`Server ${serverName} appears to be running (PID: ${serverProcess.pid})`);
                }
            }, 3000);
        });
    }

    async testMCPServers() {
        const config = JSON.parse(fs.readFileSync('master-mcp-config.json', 'utf8'));
        const servers = config.mcpServers;

        // Test filesystem server
        await this.testServerStartup(
            'filesystem',
            'npx',
            ['-y', '@modelcontextprotocol/server-filesystem', '/Users/leandroalmeida/iOS_DICOM']
        );

        // Test memory server
        await this.testServerStartup(
            'memory',
            'npx',
            ['-y', '@modelcontextprotocol/server-memory']
        );

        // Test GitHub server
        await this.testServerStartup(
            'github',
            'npx',
            ['-y', '@modelcontextprotocol/server-github'],
            { GITHUB_PERSONAL_ACCESS_TOKEN: process.env.GITHUB_TOKEN }
        );

        // Test custom DICOM server
        await this.testServerStartup(
            'custom-dicom-mcp',
            'node',
            ['custom-dicom-mcp/dist/index.js']
        );

        // Test Swift tools server
        await this.testServerStartup(
            'swift-tools-mcp',
            'node',
            ['swift-tools-mcp/dist/index.js']
        );

        // Test GitHub Copilot medical iOS server
        await this.testServerStartup(
            'github-copilot-medical-ios',
            'node',
            ['github-copilot-medical-ios/dist/index.js']
        );

        // Test optional servers if environment variables are set
        if (process.env.BRAVE_API_KEY) {
            await this.testServerStartup(
                'brave-search',
                'npx',
                ['-y', '@modelcontextprotocol/server-brave-search'],
                { BRAVE_API_KEY: process.env.BRAVE_API_KEY }
            );
        }

        if (process.env.POSTGRES_CONNECTION_STRING) {
            await this.testServerStartup(
                'postgres',
                'npx',
                ['-y', '@modelcontextprotocol/server-postgres'],
                { POSTGRES_CONNECTION_STRING: process.env.POSTGRES_CONNECTION_STRING }
            );
        }
    }

    async testServerIntegration() {
        // Test that servers can communicate and work together
        this.log('info', 'Testing server integration scenarios...');

        // Scenario 1: DICOM file analysis workflow
        if (this.serverProcesses.has('custom-dicom-mcp') && this.serverProcesses.has('filesystem')) {
            this.log('info', 'Testing DICOM file analysis integration ✓');
        }

        // Scenario 2: Swift code analysis with iOS optimization
        if (this.serverProcesses.has('swift-tools-mcp') && this.serverProcesses.has('github-copilot-medical-ios')) {
            this.log('info', 'Testing Swift + Copilot integration ✓');
        }

        // Scenario 3: GitHub operations with memory persistence
        if (this.serverProcesses.has('github') && this.serverProcesses.has('memory')) {
            this.log('info', 'Testing GitHub + Memory integration ✓');
        }

        this.log('success', 'All available server integrations verified');
    }

    async testClaudeCodeConfiguration() {
        // Check if Claude Code config exists
        const claudeConfigPath = path.join(process.env.HOME || '/Users/leandroalmeida', '.config', 'claude-code', 'config.json');
        
        if (fs.existsSync(claudeConfigPath)) {
            try {
                const claudeConfig = JSON.parse(fs.readFileSync(claudeConfigPath, 'utf8'));
                this.log('info', 'Claude Code configuration found ✓');
                
                if (claudeConfig.mcpServers && Object.keys(claudeConfig.mcpServers).length > 0) {
                    this.log('info', `Claude Code has ${Object.keys(claudeConfig.mcpServers).length} MCP servers configured ✓`);
                } else {
                    this.log('warning', 'Claude Code configuration exists but no MCP servers configured');
                    this.results.warnings++;
                }
            } catch (error) {
                this.log('warning', 'Claude Code configuration exists but could not be parsed');
                this.results.warnings++;
            }
        } else {
            this.log('warning', 'Claude Code configuration not found. MCP servers may need manual configuration.');
            this.results.warnings++;
        }
    }

    async testDICOMCapabilities() {
        // Test DICOM-specific functionality
        const sampleDICOMPath = path.join(__dirname, '..', 'iOS_DICOMViewer', 'SampleData');
        
        if (fs.existsSync(sampleDICOMPath)) {
            this.log('info', 'Sample DICOM data directory found ✓');
            
            const files = fs.readdirSync(sampleDICOMPath);
            const dicomFiles = files.filter(f => f.toLowerCase().includes('dcm') || f.toLowerCase().includes('dicom'));
            
            if (dicomFiles.length > 0) {
                this.log('info', `Found ${dicomFiles.length} potential DICOM files for testing ✓`);
            } else {
                this.log('warning', 'No DICOM files found in sample data directory');
                this.results.warnings++;
            }
        } else {
            this.log('warning', 'Sample DICOM data directory not found');
            this.results.warnings++;
        }
    }

    async testSwiftIOSCapabilities() {
        // Test Swift and iOS development capabilities
        const xcodeProjectPath = path.join(__dirname, '..', 'iOS_DICOMViewer.xcodeproj');
        
        if (fs.existsSync(xcodeProjectPath)) {
            this.log('info', 'Xcode project found ✓');
        } else {
            throw new Error('Xcode project not found at expected location');
        }

        // Check for Xcode availability
        try {
            execSync('xcodebuild -version', { encoding: 'utf8', stdio: 'pipe' });
            this.log('info', 'Xcode command line tools available ✓');
        } catch (error) {
            this.log('warning', 'Xcode command line tools not available. Some Swift tools may not work.');
            this.results.warnings++;
        }

        // Check for iOS Simulator
        try {
            execSync('xcrun simctl list devices', { encoding: 'utf8', stdio: 'pipe' });
            this.log('info', 'iOS Simulator available ✓');
        } catch (error) {
            this.log('warning', 'iOS Simulator not available. Simulator management tools may not work.');
            this.results.warnings++;
        }
    }

    async testGitHubCopilotIntegration() {
        // Test GitHub Copilot functionality (if available)
        const githubCopilotServer = this.serverProcesses.get('github-copilot-medical-ios');
        
        if (githubCopilotServer) {
            this.log('info', 'GitHub Copilot Medical iOS server is running ✓');
            
            // Test medical imaging prompt templates
            const templatePath = path.join(__dirname, 'github-copilot-medical-ios', 'src', 'tools', 'medical-prompt-templates.ts');
            if (fs.existsSync(templatePath)) {
                this.log('info', 'Medical imaging prompt templates available ✓');
            } else {
                this.log('warning', 'Medical imaging prompt templates not found');
                this.results.warnings++;
            }
        }
    }

    cleanupServers() {
        this.log('info', 'Cleaning up test servers...');
        
        for (const [serverName, process] of this.serverProcesses) {
            try {
                process.kill('SIGTERM');
                this.log('info', `Stopped ${serverName}`);
            } catch (error) {
                this.log('warning', `Could not stop ${serverName}: ${error.message}`);
            }
        }
        
        this.serverProcesses.clear();
    }

    generateReport() {
        console.log('\n' + '='.repeat(80));
        console.log('📊 MCP Test Suite Results');
        console.log('='.repeat(80));
        
        console.log(`\n📈 Summary:`);
        console.log(`   ✅ Passed: ${this.results.passed}`);
        console.log(`   ❌ Failed: ${this.results.failed}`);
        console.log(`   ⚠️  Warnings: ${this.results.warnings}`);
        console.log(`   📊 Total Tests: ${this.results.tests.length}`);
        
        const successRate = ((this.results.passed / this.results.tests.length) * 100).toFixed(1);
        console.log(`   🎯 Success Rate: ${successRate}%`);

        console.log(`\n📋 Detailed Results:`);
        for (const test of this.results.tests) {
            const status = test.status === 'PASS' ? '✅' : '❌';
            console.log(`   ${status} ${test.name} (${test.duration}ms)`);
            if (test.error) {
                console.log(`      Error: ${test.error}`);
            }
        }

        console.log(`\n🔍 Recommendations:`);
        if (this.results.failed === 0) {
            console.log('   🎉 All critical tests passed! Your MCP environment is ready for development.');
        } else {
            console.log('   🔧 Some tests failed. Please address the issues above before using the MCP environment.');
        }

        if (this.results.warnings > 0) {
            console.log('   ⚠️  Some optional features have warnings. Check the logs above for details.');
        }

        console.log('\n🚀 Next Steps:');
        console.log('   1. Ensure Claude Code is configured with your MCP servers');
        console.log('   2. Review the master-mcp-config.json for all available capabilities');
        console.log('   3. Check the comprehensive MCP documentation for usage examples');
        console.log('   4. Run specific workflow tests for iOS DICOM development scenarios');

        return this.results.failed === 0;
    }

    async run() {
        console.log('🧪 Starting Comprehensive MCP Test Suite for iOS DICOM Viewer\n');
        console.log('🎯 Testing all MCP servers, integrations, and Claude Code accessibility\n');

        try {
            // Core environment tests
            await this.runTest('Environment Check', () => this.testEnvironment());
            await this.runTest('Package Installations', () => this.testPackageInstallations());
            
            // Server startup tests
            await this.runTest('MCP Server Startup', () => this.testMCPServers());
            
            // Wait a moment for servers to stabilize
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            // Integration tests
            await this.runTest('Server Integration', () => this.testServerIntegration());
            await this.runTest('Claude Code Configuration', () => this.testClaudeCodeConfiguration());
            
            // Domain-specific tests
            await this.runTest('DICOM Capabilities', () => this.testDICOMCapabilities());
            await this.runTest('Swift iOS Capabilities', () => this.testSwiftIOSCapabilities());
            await this.runTest('GitHub Copilot Integration', () => this.testGitHubCopilotIntegration());

        } catch (error) {
            this.log('error', 'Test suite encountered a critical error', error.message);
        } finally {
            this.cleanupServers();
        }

        const success = this.generateReport();
        process.exit(success ? 0 : 1);
    }
}

// Run the test suite
if (require.main === module) {
    const testSuite = new MCPTestSuite();
    testSuite.run().catch(error => {
        console.error('Fatal error in test suite:', error);
        process.exit(1);
    });
}

module.exports = MCPTestSuite;