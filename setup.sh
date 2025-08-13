#!/bin/bash

# NVIDIA RAG Blueprint Setup Script for RTX 5070 Ti
# This script configures and deploys the NVIDIA RAG pipeline using Docker Compose

set -e  # Exit on error

echo "================================================"
echo "NVIDIA RAG Blueprint Setup Script"
echo "For RTX 5070 Ti GPU on Ubuntu"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
   echo "Please do not run this script as root. Exiting."
   exit 1
fi

# Check for NGC API key
if [ -z "$NGC_API_KEY" ]; then
    echo "ERROR: NGC_API_KEY environment variable is not set."
    echo ""
    echo "Please obtain an API key from: https://org.ngc.nvidia.com/setup/api-keys"
    echo "Then export it with: export NGC_API_KEY='your-api-key'"
    echo ""
    exit 1
fi

# Check for required commands
for cmd in docker docker-compose git git-lfs; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: $cmd is not installed. Please install it first."
        exit 1
    fi
done

echo "✓ Found NGC API key"
echo "✓ All required commands are available"
echo ""

# Create model cache directory
echo "Creating model cache directory..."
mkdir -p ~/.cache/model-cache
export MODEL_DIRECTORY=~/.cache/model-cache
echo "✓ Model cache directory created at: $MODEL_DIRECTORY"
echo ""

# Authenticate Docker with NGC
echo "Authenticating Docker with NGC..."
echo "${NGC_API_KEY}" | docker login nvcr.io -u '$oauthtoken' --password-stdin
echo "✓ Docker authenticated with NGC"
echo ""

# Initialize Git LFS
echo "Initializing Git LFS..."
git lfs install
git lfs pull
echo "✓ Git LFS initialized and data pulled"
echo ""

# Navigate to deployment directory
cd deploy/compose

# Configure environment for RTX 5070 Ti
echo "Configuring environment for RTX 5070 Ti..."

# Since RTX 5070 Ti is not yet widely supported, we'll use cloud NIMs
# Comment out on-prem NIMs and enable cloud NIMs
cat > .env.local << 'EOF'
# ==== Set User for local NIM deployment ====
export USERID=$(id -u)

# ==== Endpoints for using cloud NIMs ===
export APP_EMBEDDINGS_SERVERURL=""
export APP_LLM_SERVERURL=""
export APP_RANKING_SERVERURL=""
export SUMMARY_LLM_SERVERURL=""
export EMBEDDING_NIM_ENDPOINT=https://integrate.api.nvidia.com/v1
export PADDLE_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/baidu/paddleocr
export PADDLE_INFER_PROTOCOL=http
export YOLOX_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/nvidia/nemoretriever-page-elements-v2
export YOLOX_INFER_PROTOCOL=http
export YOLOX_GRAPHIC_ELEMENTS_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/nvidia/nemoretriever-graphic-elements-v1
export YOLOX_GRAPHIC_ELEMENTS_INFER_PROTOCOL=http
export YOLOX_TABLE_STRUCTURE_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/nvidia/nemoretriever-table-structure-v1
export YOLOX_TABLE_STRUCTURE_INFER_PROTOCOL=http

# ==== Vector DB GPU ID ====
export VECTORSTORE_GPU_DEVICE_ID=0

# Set absolute path for prompts file
export PROMPT_CONFIG_FILE=${PWD}/src/nvidia_rag/rag_server/prompt.yaml

# Disable GPU acceleration for Milvus (better accuracy)
export APP_VECTORSTORE_ENABLEGPUSEARCH=False
export APP_VECTORSTORE_ENABLEGPUINDEX=False
EOF

# Source the environment
source .env.local

echo "✓ Environment configured for cloud NIMs (suitable for RTX 5070 Ti)"
echo ""

# Start services
echo "Starting services..."
echo ""

# Start vector database
echo "Starting Milvus vector database..."
docker compose -f vectordb.yaml up -d
echo "✓ Vector database started"
echo ""

# Wait for vector database to be ready
echo "Waiting for vector database to be ready..."
sleep 10

# Start ingestion server
echo "Starting ingestion server..."
docker compose -f docker-compose-ingestor-server.yaml up -d
echo "✓ Ingestion server started"
echo ""

# Start RAG server
echo "Starting RAG server..."
docker compose -f docker-compose-rag-server.yaml up -d
echo "✓ RAG server started"
echo ""

# Wait for all services to be ready
echo "Waiting for all services to be ready (this may take a few minutes)..."
sleep 30

# Check service status
echo ""
echo "Checking service status..."
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check RAG server health
echo ""
echo "Checking RAG server health..."
if curl -s -X 'GET' 'http://localhost:8081/v1/health?check_dependencies=true' -H 'accept: application/json' > /dev/null 2>&1; then
    echo "✓ RAG server is healthy"
else
    echo "⚠ RAG server health check failed. Services may still be starting."
fi

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Access the RAG Playground at: http://localhost:8090"
echo ""
echo "To ingest documents:"
echo "1. Use the web interface at http://localhost:8090 (Upload tab)"
echo "2. Or run the ingestion notebook: jupyter lab --allow-root --ip=0.0.0.0 --NotebookApp.token='' --port=8889"
echo "   Then open notebooks/ingestion_api_usage.ipynb"
echo ""
echo "To stop all services:"
echo "cd deploy/compose"
echo "docker compose -f docker-compose-ingestor-server.yaml down"
echo "docker compose -f docker-compose-rag-server.yaml down"
echo "docker compose -f vectordb.yaml down"
echo ""
echo "================================================"