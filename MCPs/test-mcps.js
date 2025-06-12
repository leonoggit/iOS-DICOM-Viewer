#!/usr/bin/env node

/**
 * Test script to verify MCP server installations
 * Run with: node test-mcps.js
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🧪 Testing MCP Server Installations...\n');

// Test 1: Check if all expected packages are installed
console.log('1. Checking installed packages...');
try {
    const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    const dependencies = { ...packageJson.dependencies, ...packageJson.devDependencies };
    
    console.log('✅ Found dependencies:');
    Object.entries(dependencies).forEach(([pkg, version]) => {
        console.log(`   • ${pkg}@${version}`);
    });
} catch (error) {
    console.error('❌ Error reading package.json:', error.message);
}

// Test 2: Check if node_modules exist
console.log('\n2. Verifying node_modules structure...');
const mcpPath = 'node_modules/@modelcontextprotocol';
if (fs.existsSync(mcpPath)) {
    const mcpModules = fs.readdirSync(mcpPath);
    console.log('✅ Found MCP modules:');
    mcpModules.forEach(module => {
        console.log(`   • @modelcontextprotocol/${module}`);
    });
} else {
    console.error('❌ MCP modules not found in node_modules');
}

// Test 3: Test npm list command
console.log('\n3. Running npm list...');
try {
    const output = execSync('npm list --depth=0', { encoding: 'utf8' });
    console.log('✅ npm list successful');
    console.log(output);
} catch (error) {
    console.error('❌ npm list failed:', error.message);
}

// Test 4: Check if servers can be invoked
console.log('\n4. Testing server availability...');
const servers = [
    'server-filesystem',
    'server-everything', 
    'server-memory'
];

servers.forEach(server => {
    try {
        const serverPath = path.join('node_modules/@modelcontextprotocol', server);
        if (fs.existsSync(serverPath)) {
            console.log(`✅ ${server} is installed`);
        } else {
            console.log(`❌ ${server} not found`);
        }
    } catch (error) {
        console.log(`❌ Error checking ${server}:`, error.message);
    }
});

console.log('\n🎉 MCP Server Installation Test Complete!');
console.log('\nNext steps:');
console.log('• Configure Claude Code to use these MCP servers');
console.log('• Run servers with: npx @modelcontextprotocol/server-{name}');
console.log('• Check the README.md for usage examples');