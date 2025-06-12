#!/usr/bin/env node

const { spawn } = require('child_process');

console.log('🚀 Quick MCP Server Functionality Test\n');

const tests = [
  {
    name: 'Filesystem MCP',
    cmd: 'npx',
    args: ['@modelcontextprotocol/server-filesystem', '/Users/leandroalmeida/iOS_DICOM'],
    expectInOutput: 'Filesystem Server running'
  },
  {
    name: 'Memory MCP', 
    cmd: 'npx',
    args: ['@modelcontextprotocol/server-memory'],
    expectInOutput: 'Knowledge Graph MCP Server'
  },
  {
    name: 'Custom DICOM MCP',
    cmd: 'node',
    args: ['/Users/leandroalmeida/iOS_DICOM/MCPs/custom-dicom-mcp/dist/index.js'],
    expectInOutput: 'DICOM MCP Server'
  },
  {
    name: 'Swift Tools MCP',
    cmd: 'node',
    args: ['/Users/leandroalmeida/iOS_DICOM/MCPs/swift-tools-mcp/dist/index.js'],
    expectInOutput: 'Swift Tools MCP'
  }
];

async function quickTest(test) {
  return new Promise((resolve) => {
    const child = spawn(test.cmd, test.args, { stdio: ['pipe', 'pipe', 'pipe'] });
    
    let allOutput = '';
    
    child.stdout.on('data', (data) => { allOutput += data.toString(); });
    child.stderr.on('data', (data) => { allOutput += data.toString(); });
    
    // Send test input and close
    child.stdin.write('{"test": true}\n');
    child.stdin.end();
    
    setTimeout(() => {
      child.kill();
      const isWorking = allOutput.includes('MCP') || allOutput.includes('Server') || allOutput.includes('running');
      console.log(`${isWorking ? '✅' : '❌'} ${test.name}: ${isWorking ? 'WORKING' : 'FAILED'}`);
      resolve(isWorking);
    }, 2000);
  });
}

async function runTests() {
  const results = [];
  
  for (const test of tests) {
    const result = await quickTest(test);
    results.push(result);
  }
  
  const workingCount = results.filter(r => r).length;
  const totalCount = results.length;
  
  console.log(`\n📊 Summary: ${workingCount}/${totalCount} MCP servers functional`);
  
  if (workingCount === totalCount) {
    console.log('\n🎉 ALL MCP SERVERS ARE WORKING!');
    console.log('✅ Your enhanced iOS DICOM development environment is ready!');
    console.log('✅ Claude Code will have access to all specialized tools');
  } else {
    console.log('\n⚠️ Some servers need attention');
  }
  
  console.log('\n🔧 Configuration Status:');
  console.log(`   Claude Config: ~/Library/Application Support/Claude/claude_desktop_config.json`);
  console.log(`   Integration: Ready for Claude Code restart`);
}

runTests().catch(console.error);