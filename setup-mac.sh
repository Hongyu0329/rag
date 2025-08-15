#!/bin/bash

# NVIDIA RAG Blueprint Setup Script - macOS Optimized
# This script configures and deploys the NVIDIA RAG pipeline using NVIDIA APIs
# CPU-only mode for macOS compatibility

set -e  # Exit on error

echo "================================================"
echo "NVIDIA RAG Blueprint Setup Script - macOS"
echo "CPU-only mode with NVIDIA API integration"
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
for cmd in docker git git-lfs; do
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

# Create macOS-optimized vector database configuration (CPU-only)
echo "Creating macOS-optimized vector database configuration..."
cat > vectordb-mac.yaml << 'VECTORDB_EOF'
services:

  # Milvus CPU-only for macOS compatibility
  milvus:
    container_name: milvus-standalone
    image: milvusdb/milvus:v2.5.3  # CPU-only image
    command: ["milvus", "run", "standalone"]
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9010
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/milvus:/var/lib/milvus
    ports:
      - "19530:19530"
      - "9091:9091"
    depends_on:
      - "etcd"
      - "minio"
    # No GPU configuration for macOS

  etcd:
    container_name: milvus-etcd
    image: quay.io/coreos/etcd:v3.5.19
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
      - ETCD_SNAPSHOT_COUNT=50000
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/etcd:/etcd
    command: etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd
    healthcheck:
      test: ["CMD", "etcdctl", "endpoint", "health"]
      interval: 30s
      timeout: 20s
      retries: 3

  minio:
    container_name: milvus-minio
    image: minio/minio:RELEASE.2025-02-28T09-55-16Z
    environment:
      MINIO_ACCESS_KEY: minioadmin
      MINIO_SECRET_KEY: minioadmin
    ports:
      - "9011:9011"
      - "9010:9010"
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/minio:/minio_data
    command: minio server /minio_data --console-address ":9011" --address ":9010"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9010/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

networks:
  default:
    name: nvidia-rag
VECTORDB_EOF

# Configure environment for macOS with NVIDIA APIs
echo "Configuring environment for macOS with NVIDIA API integration..."
echo ""

# Create macOS-optimized environment configuration
cat > .env.mac << 'EOF'
# ==== Set User for local deployment ====
export USERID=$(id -u)

# ==== NVIDIA APIs for all AI processing ===
# Use NVIDIA's cloud services for all model inference
export APP_EMBEDDINGS_SERVERURL=""
export APP_LLM_SERVERURL=""
export APP_RANKING_SERVERURL=""
export SUMMARY_LLM_SERVERURL=""

# Use NVIDIA's latest and most powerful models via API
export APP_LLM_MODELNAME="nvidia/llama-3.3-nemotron-super-49b-v1"
export APP_EMBEDDINGS_MODELNAME="nvidia/llama-3.2-nv-embedqa-1b-v2"
export APP_RANKING_MODELNAME="nvidia/llama-3.2-nv-rerankqa-1b-v2"

# NVIDIA API endpoints
export EMBEDDING_NIM_ENDPOINT=https://integrate.api.nvidia.com/v1
export LLM_NIM_ENDPOINT=https://integrate.api.nvidia.com/v1

# Document processing via NVIDIA APIs
export PADDLE_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/baidu/paddleocr
export PADDLE_INFER_PROTOCOL=http
export YOLOX_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/nvidia/nemoretriever-page-elements-v2
export YOLOX_INFER_PROTOCOL=http
export YOLOX_GRAPHIC_ELEMENTS_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/nvidia/nemoretriever-graphic-elements-v1
export YOLOX_GRAPHIC_ELEMENTS_INFER_PROTOCOL=http
export YOLOX_TABLE_STRUCTURE_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/nvidia/nemoretriever-table-structure-v1
export YOLOX_TABLE_STRUCTURE_INFER_PROTOCOL=http

# Caption model for image understanding
export APP_NVINGEST_CAPTIONMODELNAME="nvidia/llama-3.1-nemotron-nano-vl-8b-v1"
export APP_NVINGEST_CAPTIONENDPOINTURL="https://integrate.api.nvidia.com/v1/chat/completions"

# Vector DB - CPU-only configuration for macOS
export VECTORSTORE_GPU_DEVICE_ID=0
export APP_VECTORSTORE_ENABLEGPUSEARCH=False
export APP_VECTORSTORE_ENABLEGPUINDEX=False

# Set absolute path for prompts file
export PROMPT_CONFIG_FILE=${PWD}/../../src/nvidia_rag/rag_server/prompt.yaml

# Optimize document processing settings
export APP_NVINGEST_EXTRACTTEXT=True
export APP_NVINGEST_EXTRACTTABLES=True
export APP_NVINGEST_EXTRACTCHARTS=True
export APP_NVINGEST_EXTRACTIMAGES=True
export APP_NVINGEST_EXTRACTINFOGRAPHICS=True
export APP_NVINGEST_PDFEXTRACTMETHOD=pdfium
EOF

# Source the environment
source .env.mac

echo "✓ Environment configured for macOS with NVIDIA APIs"
echo "  - Using CPU-only Milvus (macOS compatible)"
echo "  - All AI processing via NVIDIA APIs"
echo "  - Minimal local resource usage"
echo ""

# Create macOS-optimized ingestor configuration
echo "Creating macOS-optimized ingestor configuration..."
cat > docker-compose-ingestor-mac.yaml << 'INGESTOR_EOF'
services:
  # Ingestor server optimized for macOS
  ingestor-server:
    container_name: ingestor-server
    image: nvcr.io/nvidia/blueprint/ingestor-server:${TAG:-2.2.0}
    command: --port 8082 --host 0.0.0.0 --workers 1
    
    volumes:
      - ${PROMPT_CONFIG_FILE}:${PROMPT_CONFIG_FILE}
    
    environment:
      EXAMPLE_PATH: 'src/nvidia_rag/ingestor_server'
      PROMPT_CONFIG_FILE: ${PROMPT_CONFIG_FILE:-/prompt.yaml}
      
      # Vector DB configurations - CPU only
      APP_VECTORSTORE_URL: "http://milvus:19530"
      APP_VECTORSTORE_NAME: "milvus"
      APP_VECTORSTORE_SEARCHTYPE: ${APP_VECTORSTORE_SEARCHTYPE:-"dense"}
      APP_VECTORSTORE_ENABLEGPUINDEX: False
      APP_VECTORSTORE_ENABLEGPUSEARCH: False
      COLLECTION_NAME: ${COLLECTION_NAME:-multimodal_data}
      
      # Minio configurations
      MINIO_ENDPOINT: "minio:9010"
      MINIO_ACCESSKEY: "minioadmin"
      MINIO_SECRETKEY: "minioadmin"
      
      NGC_API_KEY: ${NGC_API_KEY:?"NGC_API_KEY is required"}
      NVIDIA_API_KEY: ${NGC_API_KEY:?"NGC_API_KEY is required"}
      
      # Use NVIDIA APIs for embeddings
      APP_EMBEDDINGS_SERVERURL: ${APP_EMBEDDINGS_SERVERURL}
      APP_EMBEDDINGS_MODELNAME: ${APP_EMBEDDINGS_MODELNAME}
      APP_EMBEDDINGS_DIMENSIONS: 2048
      EMBEDDING_NIM_ENDPOINT: ${EMBEDDING_NIM_ENDPOINT}
      
      # Document processing settings
      APP_NVINGEST_EXTRACTTEXT: ${APP_NVINGEST_EXTRACTTEXT}
      APP_NVINGEST_EXTRACTTABLES: ${APP_NVINGEST_EXTRACTTABLES}
      APP_NVINGEST_EXTRACTCHARTS: ${APP_NVINGEST_EXTRACTCHARTS}
      APP_NVINGEST_EXTRACTIMAGES: ${APP_NVINGEST_EXTRACTIMAGES}
      APP_NVINGEST_EXTRACTINFOGRAPHICS: ${APP_NVINGEST_EXTRACTINFOGRAPHICS}
      APP_NVINGEST_PDFEXTRACTMETHOD: ${APP_NVINGEST_PDFEXTRACTMETHOD}
      
      # NVIDIA API processing endpoints
      PADDLE_HTTP_ENDPOINT: ${PADDLE_HTTP_ENDPOINT}
      PADDLE_INFER_PROTOCOL: ${PADDLE_INFER_PROTOCOL}
      YOLOX_HTTP_ENDPOINT: ${YOLOX_HTTP_ENDPOINT}
      YOLOX_INFER_PROTOCOL: ${YOLOX_INFER_PROTOCOL}
      YOLOX_GRAPHIC_ELEMENTS_HTTP_ENDPOINT: ${YOLOX_GRAPHIC_ELEMENTS_HTTP_ENDPOINT}
      YOLOX_GRAPHIC_ELEMENTS_INFER_PROTOCOL: ${YOLOX_GRAPHIC_ELEMENTS_INFER_PROTOCOL}
      YOLOX_TABLE_STRUCTURE_HTTP_ENDPOINT: ${YOLOX_TABLE_STRUCTURE_HTTP_ENDPOINT}
      YOLOX_TABLE_STRUCTURE_INFER_PROTOCOL: ${YOLOX_TABLE_STRUCTURE_INFER_PROTOCOL}
      
      # Caption model settings
      APP_NVINGEST_CAPTIONMODELNAME: ${APP_NVINGEST_CAPTIONMODELNAME}
      APP_NVINGEST_CAPTIONENDPOINTURL: ${APP_NVINGEST_CAPTIONENDPOINTURL}
      
      # Chunking settings
      APP_NVINGEST_CHUNKSIZE: 512
      APP_NVINGEST_CHUNKOVERLAP: 150
      APP_NVINGEST_ENABLEPDFSPLITTER: True
      APP_NVINGEST_TEXTDEPTH: page
      
      ENABLE_CITATIONS: True
    
    ports:
      - "8082:8082"
    
    networks:
      - nvidia-rag
    
    depends_on:
      - redis-light

  # Lightweight Redis
  redis-light:
    container_name: redis-light
    image: redis:7.0.15-alpine
    ports:
      - "6379:6379"
    networks:
      - nvidia-rag
    mem_limit: 256m

networks:
  nvidia-rag:
    name: nvidia-rag
    external: true
INGESTOR_EOF

echo "✓ macOS-optimized ingestor configuration created"
echo ""

# Start services
echo "Starting services for macOS..."
echo ""

# Start vector database with CPU-only configuration
echo "Starting Milvus vector database (CPU-only)..."
docker compose -f vectordb-mac.yaml up -d
echo "✓ Vector database started (CPU-only mode)"
echo ""

# Wait for vector database to be ready
echo "Waiting for vector database to be ready..."
sleep 15

# Start ingestion server
echo "Starting ingestion server with NVIDIA API integration..."
docker compose -f docker-compose-ingestor-mac.yaml up -d
echo "✓ Ingestion server started"
echo ""

# Start RAG server
echo "Starting RAG server with NVIDIA APIs..."
docker compose -f docker-compose-rag-server.yaml up -d
echo "✓ RAG server started"
echo ""

# Wait for all services to be ready
echo "Waiting for all services to be ready..."
sleep 30

# Check service status
echo ""
echo "Checking service status..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show memory usage
echo ""
echo "Memory usage:"
echo "-------------"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | grep -E "NAME|ingestor|redis|rag-server|milvus"

# Check RAG server health
echo ""
echo "Checking RAG server health..."
if curl -s -X 'GET' 'http://localhost:8081/v1/health?check_dependencies=false' -H 'accept: application/json' > /dev/null 2>&1; then
    echo "✓ RAG server is healthy"
else
    echo "⚠ RAG server health check failed. Services may still be starting."
fi

echo ""
echo "================================================"
echo "Setup Complete - macOS Optimized Configuration"
echo "================================================"
echo ""
echo "🚀 FEATURES:"
echo "  ✓ CPU-only mode (macOS compatible)"
echo "  ✓ NVIDIA API integration for all AI processing"
echo "  ✓ Powerful cloud models (Llama 3.3 Nemotron 49B)"
echo "  ✓ Full document processing capabilities"
echo ""
echo "📍 ACCESS POINTS:"
echo "  • RAG Playground UI: http://localhost:8090"
echo "  • RAG API: http://localhost:8081"
echo "  • Ingestion API: http://localhost:8082"
echo ""
echo "📄 TO INGEST DOCUMENTS:"
echo "  1. Web interface: http://localhost:8090"
echo "  2. API: POST to http://localhost:8082/documents"
echo "  3. Notebook: notebooks/ingestion_api_usage.ipynb"
echo ""
echo "🛑 TO STOP ALL SERVICES:"
echo "  cd deploy/compose"
echo "  docker compose -f docker-compose-ingestor-mac.yaml down"
echo "  docker compose -f docker-compose-rag-server.yaml down"
echo "  docker compose -f vectordb-mac.yaml down"
echo ""
echo "💡 TIPS:"
echo "  • All AI processing happens via NVIDIA APIs"
echo "  • No local GPU required"
echo "  • Optimized for macOS compatibility"
echo ""
echo "================================================"