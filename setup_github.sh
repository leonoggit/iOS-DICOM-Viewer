#!/bin/bash

# GitHub Repository Setup Script for iOS DICOM Viewer
# Run this script after creating the repository on GitHub

echo "🚀 iOS DICOM Viewer - GitHub Repository Setup"
echo "=============================================="

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository. Please run from project root."
    exit 1
fi

# Get GitHub username and repository name
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter repository name (default: iOS-DICOM-Viewer): " REPO_NAME
REPO_NAME=${REPO_NAME:-iOS-DICOM-Viewer}

# GitHub repository URL
GITHUB_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

echo ""
echo "📋 Repository Details:"
echo "Username: $GITHUB_USERNAME"
echo "Repository: $REPO_NAME"
echo "URL: $GITHUB_URL"
echo ""

# Confirm before proceeding
read -p "Continue with this setup? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled."
    exit 1
fi

# Configure Git user (if not already configured)
if [ -z "$(git config user.name)" ]; then
    read -p "Enter your name for Git: " GIT_NAME
    git config user.name "$GIT_NAME"
fi

if [ -z "$(git config user.email)" ]; then
    read -p "Enter your email for Git: " GIT_EMAIL
    git config user.email "$GIT_EMAIL"
fi

echo ""
echo "🔗 Setting up remote repository..."

# Add GitHub remote
git remote add origin "$GITHUB_URL"

# Verify remote
echo "✅ Remote repository added:"
git remote -v

echo ""
echo "📤 Pushing to GitHub..."

# Set upstream and push
git branch -M main
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! Repository pushed to GitHub:"
    echo "   $GITHUB_URL"
    echo ""
    echo "📱 Your iOS DICOM Viewer is now available on GitHub!"
    echo ""
    echo "🔧 Next steps:"
    echo "1. Visit your repository: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
    echo "2. Add topics/tags: ios, dicom, medical-imaging, ohif, swift"
    echo "3. Configure repository settings (Issues, Discussions, etc.)"
    echo "4. Consider adding a license (MIT, Apache 2.0, etc.)"
    echo "5. Set up GitHub Pages for documentation"
else
    echo ""
    echo "❌ Error pushing to GitHub. Please check:"
    echo "1. Repository exists on GitHub"
    echo "2. You have push access"
    echo "3. GitHub credentials are configured"
    echo ""
    echo "Manual commands to retry:"
    echo "git remote -v"
    echo "git push -u origin main"
fi
