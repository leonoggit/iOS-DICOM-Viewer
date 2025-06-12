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
