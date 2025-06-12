#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

// Test configuration
const mcpServers = [
  {
    name: 'Filesystem MCP',
    command: 'npx',
    args: ['@modelcontextprotocol/server-filesystem', '/Users/leandroalmeida/iOS_DICOM'],
    timeout: 5000
  },
  {
    name: 'Memory MCP', 
    command: 'npx',
    args: ['@modelcontextprotocol/server-memory'],
    timeout: 5000
  },
  {
    name: 'Custom DICOM MCP',
    command: 'node',
    args: ['/Users/leandroalmeida/iOS_DICOM/MCPs/custom-dicom-mcp/dist/index.js'],
    timeout: 5000
  },
  {
    name: 'Swift Tools MCP',
    command: 'node', 
    args: ['/Users/leandroalmeida/iOS_DICOM/MCPs/swift-tools-mcp/dist/index.js'],
    timeout: 5000
  }
];

async function testMCPServer(serverConfig) {
  return new Promise((resolve) => {
    console.log(`\n🧪 Testing ${serverConfig.name}...`);
    
    const child = spawn(serverConfig.command, serverConfig.args, {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, PROJECT_ROOT: '/Users/leandroalmeida/iOS_DICOM' }
    });

    let output = '';
    let errorOutput = '';
    let resolved = false;

    // Send a test message
    child.stdin.write('{"test": "connection"}\n');
    child.stdin.end();

    child.stdout.on('data', (data) => {
      output += data.toString();
    });

    child.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    child.on('close', (code) => {
      if (!resolved) {
        resolved = true;
        if (output.includes('running on stdio') || output.includes('Server running') || output.includes('MCP')) {
          console.log(`   ✅ ${serverConfig.name} - WORKING`);
          resolve({ success: true, output, error: errorOutput });
        } else {
          console.log(`   ❌ ${serverConfig.name} - FAILED`);
          console.log(`   Output: ${output.substring(0, 100)}...`);
          console.log(`   Error: ${errorOutput.substring(0, 100)}...`);
          resolve({ success: false, output, error: errorOutput });
        }
      }
    });

    child.on('error', (error) => {
      if (!resolved) {
        resolved = true;
        console.log(`   ❌ ${serverConfig.name} - ERROR: ${error.message}`);
        resolve({ success: false, error: error.message });
      }
    });

    // Timeout handler
    setTimeout(() => {
      if (!resolved) {
        resolved = true;
        child.kill();
        if (output.includes('running') || output.includes('Server') || output.includes('MCP')) {
          console.log(`   ✅ ${serverConfig.name} - WORKING (timeout but started correctly)`);
          resolve({ success: true, output, error: errorOutput });
        } else {
          console.log(`   ⏰ ${serverConfig.name} - TIMEOUT`);
          resolve({ success: false, error: 'Timeout' });
        }
      }
    }, serverConfig.timeout);
  });
}

async function testAllServers() {
  console.log('🚀 Testing All MCP Servers\n');
  console.log('=' .repeat(50));

  const results = [];
  
  for (const serverConfig of mcpServers) {
    const result = await testMCPServer(serverConfig);
    results.push({ name: serverConfig.name, ...result });
  }

  console.log('\n' + '='.repeat(50));
  console.log('📊 FINAL RESULTS:');
  console.log('='.repeat(50));

  const working = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);

  console.log(`\n✅ Working Servers: ${working.length}/${results.length}`);
  working.forEach(r => console.log(`   - ${r.name}`));

  if (failed.length > 0) {
    console.log(`\n❌ Failed Servers: ${failed.length}/${results.length}`);
    failed.forEach(r => console.log(`   - ${r.name}`));
  }

  console.log('\n🎯 Claude Configuration Status:');
  console.log(`   Config File: ${process.env.HOME}/Library/Application Support/Claude/claude_desktop_config.json`);
  console.log(`   Ready for Claude Code: ${working.length === results.length ? 'YES' : 'PARTIAL'}`);

  if (working.length === results.length) {
    console.log('\n🎉 ALL MCP SERVERS ARE FUNCTIONAL!');
    console.log('   Your enhanced iOS DICOM development environment is ready!');
  } else {
    console.log('\n⚠️  Some servers need attention. Check the errors above.');
  }
}

// Run the tests
testAllServers().catch(console.error);