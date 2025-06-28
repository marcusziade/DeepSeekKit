#!/bin/bash

echo "🐳 Verifying DeepSeekKit Docker image..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

echo "✅ Docker is running"

# Build the image
echo "📦 Building Docker image..."
if docker build -t deepseek-kit . ; then
    echo "✅ Docker image built successfully"
else
    echo "❌ Docker build failed"
    exit 1
fi

# Test the CLI help command
echo "🧪 Testing CLI help command..."
if docker run --rm deepseek-kit --help > /dev/null ; then
    echo "✅ CLI help command works"
else
    echo "❌ CLI help command failed"
    exit 1
fi

# Test with version command
echo "🧪 Testing version display..."
if docker run --rm deepseek-kit --version ; then
    echo "✅ Version command works"
else
    echo "❌ Version command failed"
    exit 1
fi

# Show image size
echo "📊 Docker image info:"
docker images deepseek-kit:latest

echo ""
echo "✨ Docker verification complete!"
echo ""
echo "To use the CLI in Docker:"
echo "  docker run --rm -e DEEPSEEK_API_KEY=\"your-key\" deepseek-kit chat \"Hello!\""
echo ""
echo "To run tests in Docker:"
echo "  docker-compose run test"