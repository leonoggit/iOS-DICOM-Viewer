#!/usr/bin/env node

/**
 * Final Validation Suite for Complete MCP Setup
 * Comprehensive validation of entire iOS DICOM Viewer MCP ecosystem
 * 
 * Usage: node final-validation-suite.js
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class FinalValidationSuite {
    constructor() {
        this.results = {
            passed: 0,
            failed: 0,
            warnings: 0,
            critical: 0,
            tests: []
        };
        this.criticalIssues = [];
        this.recommendations = [];
    }

    log(level, message, details = null) {
        const symbols = { info: 'ℹ️', success: '✅', error: '❌', warning: '⚠️', critical: '🚨' };
        console.log(`${symbols[level] || 'ℹ️'} ${message}`);
        if (details) {
            console.log(`   ${details}`);
        }
    }

    async runValidation(name, validationFunction, critical = false) {
        this.log('info', `Validating: ${name}`);
        const startTime = Date.now();
        
        try {
            const result = await validationFunction();
            const duration = Date.now() - startTime;
            this.results.passed++;
            this.results.tests.push({ name, status: 'PASS', duration, result });
            this.log('success', `${name} - VALIDATED (${duration}ms)`);
            return result;
        } catch (error) {
            const duration = Date.now() - startTime;
            if (critical) {
                this.results.critical++;
                this.criticalIssues.push({ name, error: error.message });
                this.log('critical', `${name} - CRITICAL FAILURE (${duration}ms)`, error.message);
            } else {
                this.results.failed++;
                this.log('error', `${name} - FAILED (${duration}ms)`, error.message);
            }
            this.results.tests.push({ name, status: critical ? 'CRITICAL' : 'FAIL', duration, error: error.message });
            return null;
        }
    }

    async validateEnvironmentReadiness() {
        // Critical environment checks
        const nodeVersion = process.version;
        if (!nodeVersion.match(/v(18|20|22)\./)) {
            throw new Error(`Node.js version ${nodeVersion} incompatible. Need v18.x, v20.x, or v22.x`);
        }

        if (!process.env.GITHUB_TOKEN) {
            throw new Error('GITHUB_TOKEN environment variable required');
        }

        if (!fs.existsSync('/Users/leandroalmeida/iOS_DICOM/iOS_DICOMViewer.xcodeproj')) {
            throw new Error('iOS DICOM Viewer project not found');
        }

        return { nodeVersion, hasGitHubToken: true, hasProject: true };
    }

    async validateMCPServers() {
        const requiredServers = [
            '@modelcontextprotocol/server-filesystem',
            '@modelcontextprotocol/server-memory',
            '@modelcontextprotocol/server-github'
        ];

        const customServers = [
            'custom-dicom-mcp/dist/index.js',
            'swift-tools-mcp/dist/index.js',
            'github-copilot-medical-ios/dist/index.js'
        ];

        // Check npm packages
        for (const server of requiredServers) {
            try {
                execSync(`npm list ${server}`, { stdio: 'pipe' });
            } catch (error) {
                throw new Error(`Required MCP server missing: ${server}`);
            }
        }

        // Check custom servers
        for (const server of customServers) {
            if (!fs.existsSync(server)) {
                throw new Error(`Custom server not built: ${server}`);
            }
        }

        return { npmServers: requiredServers.length, customServers: customServers.length };
    }

    async validateConfiguration() {
        const configFiles = [
            'master-mcp-config.json',
            'custom-dicom-mcp/package.json',
            'swift-tools-mcp/package.json',
            'github-copilot-medical-ios/package.json'
        ];

        for (const configFile of configFiles) {
            if (!fs.existsSync(configFile)) {
                throw new Error(`Configuration file missing: ${configFile}`);
            }

            try {
                JSON.parse(fs.readFileSync(configFile, 'utf8'));
            } catch (error) {
                throw new Error(`Invalid JSON in ${configFile}: ${error.message}`);
            }
        }

        // Validate master configuration structure
        const masterConfig = JSON.parse(fs.readFileSync('master-mcp-config.json', 'utf8'));
        
        if (!masterConfig.mcpServers) {
            throw new Error('Master config missing mcpServers section');
        }

        if (!masterConfig.contexts) {
            throw new Error('Master config missing contexts section');
        }

        if (!masterConfig.workflows) {
            throw new Error('Master config missing workflows section');
        }

        return { configFiles: configFiles.length, contexts: Object.keys(masterConfig.contexts).length };
    }

    async validateDocumentation() {
        const requiredDocs = [
            'MCP-ECOSYSTEM-DOCUMENTATION.md',
            'iOS-DICOM-USAGE-EXAMPLES.md',
            'TROUBLESHOOTING-GUIDE.md',
            'QUICK-START-GUIDE.md'
        ];

        const minDocSizes = {
            'MCP-ECOSYSTEM-DOCUMENTATION.md': 50000,  // 50KB minimum
            'iOS-DICOM-USAGE-EXAMPLES.md': 30000,     // 30KB minimum
            'TROUBLESHOOTING-GUIDE.md': 25000,        // 25KB minimum
            'QUICK-START-GUIDE.md': 15000             // 15KB minimum
        };

        for (const doc of requiredDocs) {
            if (!fs.existsSync(doc)) {
                throw new Error(`Required documentation missing: ${doc}`);
            }

            const stats = fs.statSync(doc);
            if (stats.size < (minDocSizes[doc] || 1000)) {
                throw new Error(`Documentation too small: ${doc} (${stats.size} bytes)`);
            }
        }

        return { documents: requiredDocs.length };
    }

    async validateTestingSuite() {
        const testFiles = [
            'comprehensive-mcp-test-suite.js',
            'integration-test-scenarios.js',
            'test-copilot-medical-prompts.js',
            'final-validation-suite.js'
        ];

        for (const testFile of testFiles) {
            if (!fs.existsSync(testFile)) {
                throw new Error(`Test file missing: ${testFile}`);
            }

            // Validate test files are executable
            try {
                const content = fs.readFileSync(testFile, 'utf8');
                if (!content.includes('#!/usr/bin/env node')) {
                    this.recommendations.push(`Add shebang to ${testFile} for direct execution`);
                }
            } catch (error) {
                throw new Error(`Cannot read test file: ${testFile}`);
            }
        }

        return { testFiles: testFiles.length };
    }

    async validateiOSProjectIntegration() {
        const projectRoot = '/Users/leandroalmeida/iOS_DICOM';
        
        // Check iOS project structure
        const requiredPaths = [
            'iOS_DICOMViewer/Core/Models',
            'iOS_DICOMViewer/DICOM/Parser',
            'iOS_DICOMViewer/Rendering',
            'iOS_DICOMViewer/Shaders'
        ];

        for (const requiredPath of requiredPaths) {
            const fullPath = path.join(projectRoot, requiredPath);
            if (!fs.existsSync(fullPath)) {
                throw new Error(`Required iOS project path missing: ${requiredPath}`);
            }
        }

        // Count Swift and Metal files
        const swiftFiles = [];
        const metalFiles = [];
        
        function findFiles(dir) {
            try {
                const items = fs.readdirSync(dir);
                for (const item of items) {
                    const fullPath = path.join(dir, item);
                    if (fs.statSync(fullPath).isDirectory()) {
                        if (!item.startsWith('.') && !item.includes('node_modules')) {
                            findFiles(fullPath);
                        }
                    } else {
                        if (item.endsWith('.swift')) swiftFiles.push(fullPath);
                        if (item.endsWith('.metal')) metalFiles.push(fullPath);
                    }
                }
            } catch (error) {
                // Skip inaccessible directories
            }
        }
        
        findFiles(path.join(projectRoot, 'iOS_DICOMViewer'));

        if (swiftFiles.length < 10) {
            this.recommendations.push('Consider adding more Swift source files for comprehensive coverage');
        }

        if (metalFiles.length < 3) {
            this.recommendations.push('Consider adding more Metal shader files for advanced rendering');
        }

        return { swiftFiles: swiftFiles.length, metalFiles: metalFiles.length };
    }

    async validateMedicalCompliance() {
        // Check for medical compliance indicators in the project
        const complianceIndicators = [
            'HIPAA',
            'DICOM',
            'FDA',
            'audit',
            'compliance',
            'medical',
            'patient',
            'privacy'
        ];

        let foundIndicators = 0;
        const searchPaths = [
            'custom-dicom-mcp/src',
            'MCP-ECOSYSTEM-DOCUMENTATION.md',
            'iOS-DICOM-USAGE-EXAMPLES.md'
        ];

        for (const searchPath of searchPaths) {
            if (fs.existsSync(searchPath)) {
                try {
                    const content = fs.statSync(searchPath).isDirectory() 
                        ? this.readDirectoryContents(searchPath)
                        : fs.readFileSync(searchPath, 'utf8');
                    
                    for (const indicator of complianceIndicators) {
                        if (content.toLowerCase().includes(indicator.toLowerCase())) {
                            foundIndicators++;
                            break;
                        }
                    }
                } catch (error) {
                    // Skip files we can't read
                }
            }
        }

        if (foundIndicators < complianceIndicators.length * 0.6) {
            this.recommendations.push('Consider enhancing medical compliance documentation and code');
        }

        return { indicators: foundIndicators, total: complianceIndicators.length };
    }

    readDirectoryContents(dir) {
        let content = '';
        try {
            const items = fs.readdirSync(dir);
            for (const item of items) {
                const fullPath = path.join(dir, item);
                if (fs.statSync(fullPath).isFile() && (item.endsWith('.ts') || item.endsWith('.js'))) {
                    content += fs.readFileSync(fullPath, 'utf8') + '\n';
                }
            }
        } catch (error) {
            // Skip unreadable directories
        }
        return content;
    }

    async validatePerformanceReadiness() {
        // Check if performance monitoring and optimization features are in place
        const performanceFeatures = [
            'performance',
            'optimization',
            'memory',
            'GPU',
            'Metal',
            'rendering'
        ];

        let featureCount = 0;
        const files = [
            'swift-tools-mcp/src/tools/ios-memory-profiler.ts',
            'swift-tools-mcp/src/tools/metal-shader-validator.ts',
            'iOS-DICOM-USAGE-EXAMPLES.md'
        ];

        for (const file of files) {
            if (fs.existsSync(file)) {
                try {
                    const content = fs.readFileSync(file, 'utf8');
                    for (const feature of performanceFeatures) {
                        if (content.toLowerCase().includes(feature.toLowerCase())) {
                            featureCount++;
                            break;
                        }
                    }
                } catch (error) {
                    // Skip unreadable files
                }
            }
        }

        return { features: featureCount, files: files.length };
    }

    generateFinalReport() {
        console.log('\n' + '='.repeat(100));
        console.log('🎯 FINAL MCP ECOSYSTEM VALIDATION REPORT');
        console.log('='.repeat(100));
        
        console.log(`\n📊 Validation Summary:`);
        console.log(`   ✅ Passed: ${this.results.passed}`);
        console.log(`   ❌ Failed: ${this.results.failed}`);
        console.log(`   ⚠️  Warnings: ${this.results.warnings}`);
        console.log(`   🚨 Critical: ${this.results.critical}`);
        console.log(`   📊 Total: ${this.results.tests.length}`);
        
        const successRate = ((this.results.passed / this.results.tests.length) * 100).toFixed(1);
        console.log(`   🎯 Success Rate: ${successRate}%`);

        console.log(`\n📋 Detailed Results:`);
        for (const test of this.results.tests) {
            const symbols = { PASS: '✅', FAIL: '❌', CRITICAL: '🚨' };
            console.log(`   ${symbols[test.status]} ${test.name} (${test.duration}ms)`);
            if (test.error) {
                console.log(`      Error: ${test.error}`);
            } else if (test.result) {
                const resultStr = typeof test.result === 'object' 
                    ? JSON.stringify(test.result).substring(0, 100) + '...'
                    : String(test.result);
                console.log(`      Result: ${resultStr}`);
            }
        }

        if (this.criticalIssues.length > 0) {
            console.log(`\n🚨 Critical Issues:`);
            for (const issue of this.criticalIssues) {
                console.log(`   • ${issue.name}: ${issue.error}`);
            }
        }

        if (this.recommendations.length > 0) {
            console.log(`\n💡 Recommendations:`);
            for (const rec of this.recommendations) {
                console.log(`   • ${rec}`);
            }
        }

        console.log(`\n🎯 Overall Assessment:`);
        if (this.results.critical > 0) {
            console.log('   🚨 CRITICAL ISSUES DETECTED - System not ready for production use');
            console.log('   🔧 Fix critical issues before proceeding with development');
        } else if (this.results.failed > 0) {
            console.log('   ⚠️  SOME ISSUES DETECTED - System functional but needs improvements');
            console.log('   🔧 Address failed validations for optimal performance');
        } else {
            console.log('   🎉 ALL VALIDATIONS PASSED - System ready for enhanced development!');
            console.log('   🚀 Your MCP ecosystem is fully configured and operational');
        }

        console.log(`\n🚀 Next Steps:`);
        if (this.results.critical === 0 && this.results.failed === 0) {
            console.log('   1. ✅ Start using Claude Code with enhanced MCP assistance');
            console.log('   2. ✅ Try the examples in iOS-DICOM-USAGE-EXAMPLES.md');
            console.log('   3. ✅ Explore medical imaging development workflows');
            console.log('   4. ✅ Leverage specialized DICOM and iOS tooling');
        } else {
            console.log('   1. 🔧 Review and fix the issues listed above');
            console.log('   2. 🔧 Re-run this validation suite after fixes');
            console.log('   3. 📖 Check TROUBLESHOOTING-GUIDE.md for solutions');
            console.log('   4. 🔄 Use QUICK-START-GUIDE.md for setup verification');
        }

        console.log(`\n📚 Documentation Available:`);
        console.log('   • MCP-ECOSYSTEM-DOCUMENTATION.md - Complete system overview');
        console.log('   • iOS-DICOM-USAGE-EXAMPLES.md - Practical examples');
        console.log('   • TROUBLESHOOTING-GUIDE.md - Problem resolution');
        console.log('   • QUICK-START-GUIDE.md - 10-minute setup guide');

        console.log(`\n🎯 Success Criteria Met:`);
        console.log(`   ${this.results.critical === 0 ? '✅' : '❌'} Zero critical issues`);
        console.log(`   ${successRate >= 80 ? '✅' : '❌'} 80%+ validation success rate`);
        console.log(`   ${this.results.passed >= 6 ? '✅' : '❌'} Core components validated`);

        return this.results.critical === 0 && successRate >= 80;
    }

    async run() {
        console.log('🎯 Starting Final MCP Ecosystem Validation\n');
        console.log('🚀 Comprehensive validation of iOS DICOM Viewer MCP setup\n');

        // Critical validations (system won't work without these)
        await this.runValidation('Environment Readiness', () => this.validateEnvironmentReadiness(), true);
        await this.runValidation('MCP Servers', () => this.validateMCPServers(), true);
        await this.runValidation('Configuration Files', () => this.validateConfiguration(), true);

        // Important validations (system will work but may be suboptimal)
        await this.runValidation('Documentation Suite', () => this.validateDocumentation());
        await this.runValidation('Testing Suite', () => this.validateTestingSuite());
        await this.runValidation('iOS Project Integration', () => this.validateiOSProjectIntegration());

        // Supplementary validations (enhancements and best practices)
        await this.runValidation('Medical Compliance Features', () => this.validateMedicalCompliance());
        await this.runValidation('Performance Readiness', () => this.validatePerformanceReadiness());

        const success = this.generateFinalReport();
        return success;
    }
}

// Run final validation
if (require.main === module) {
    const validator = new FinalValidationSuite();
    validator.run().then(success => {
        process.exit(success ? 0 : 1);
    }).catch(error => {
        console.error('🚨 Fatal error in final validation:', error);
        process.exit(1);
    });
}

module.exports = FinalValidationSuite;