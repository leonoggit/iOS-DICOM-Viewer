#!/bin/bash

# TotalSegmentator to CoreML Conversion Runner
# This script builds and runs the Docker container for dependency-free conversion

set -e

echo "🚀 TotalSegmentator to CoreML Conversion"
echo "========================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker."
    exit 1
fi

echo "✅ Docker is ready"

# Create models directory if it doesn't exist
mkdir -p models

# Build the Docker image
echo ""
echo "📦 Building Docker image..."
docker-compose build

# Run the conversion
echo ""
echo "🔄 Running conversion..."
docker-compose up

# Check if conversion was successful
if [ -f "models/TotalSegmentator.mlpackage" ]; then
    echo ""
    echo "✅ Conversion successful!"
    echo "📁 Output files:"
    ls -la models/
    echo ""
    echo "Next steps:"
    echo "1. Copy models/TotalSegmentator.mlpackage to your iOS project"
    echo "2. Add it to your Xcode project"
    echo "3. Use the model in your iOS app"
else
    echo ""
    echo "❌ Conversion failed. Check the logs above for errors."
    exit 1
fi