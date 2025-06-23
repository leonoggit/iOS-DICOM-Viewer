#!/bin/bash

# Test script for Python Poetry MCP

echo "Testing Python Poetry MCP..."

# Test with the MCP inspector
npx @modelcontextprotocol/inspector node build/index.js

# Or run directly
# node build/index.js