# NVIDIA RAG Blueprint - Project Guide

## Overview

This NVIDIA RAG Blueprint is a production-ready Retrieval-Augmented Generation (RAG) solution that leverages NVIDIA NIM microservices and GPU-accelerated components to enable intelligent question-answering based on your enterprise data.

## Table of Contents

- [How the RAG Pipeline Works](#how-the-rag-pipeline-works)
- [Repository Structure](#repository-structure)
- [Model Architecture and Usage](#model-architecture-and-usage)
- [Model Configuration](#model-configuration)
- [Getting Started](#getting-started)

---

## How the RAG Pipeline Works

### Data Flow Overview

```
User Query → RAG Server → Embedding → Vector Search → Reranking → LLM Generation → Response
                              ↓
                         Milvus Vector DB
```

### Detailed Workflow

1. **Document Ingestion Phase**

   - Documents (PDFs, DOCX, PPTX) are uploaded via the Ingestor Server
   - NV-Ingest microservice processes documents using specialized AI models:
     - **PaddleOCR**: Extracts text from images
     - **Page Elements**: Detects document layout and structure
     - **Table Structure**: Identifies and extracts tables
     - **Graphic Elements**: Processes charts and infographics
   - Text is chunked and embedded using the embedding model
   - Embeddings are stored in Milvus vector database
2. **Query Processing Phase**

   - User submits a question through the UI or API
   - Query is embedded using the same embedding model
   - Vector similarity search retrieves relevant document chunks from Milvus
   - Reranking model sorts results by relevance
   - Top chunks become context for the LLM
3. **Response Generation Phase**

   - LLM receives the query + retrieved context
   - Generates an answer grounded in the retrieved documents
   - Optional features:
     - **Reflection**: Verifies answer accuracy
     - **Guardrails**: Filters inappropriate content
     - **Citations**: Shows source documents

---

## Repository Structure

### Core Directories

#### so `/src/nvidia_rag/`

The main application code containing the RAG implementation:

- **`rag_server/`**: Core RAG orchestration server (LangChain-based)
  - Handles query processing, retrieval, and response generation
  - Contains prompt templates and validation logic
- **`ingestor_server/`**: Document ingestion service
  - Manages file uploads and processing pipeline
  - Integrates with NV-Ingest for document extraction
- **`utils/`**: Shared utilities
  - Vector store operations, embedding functions, LLM interfaces

#### `/deploy/`

Deployment configurations for different environments:

- **`compose/`**: Docker Compose configurations
  - `nims.yaml`: NVIDIA NIM microservice definitions
  - `vectordb.yaml`: Milvus database configuration
  - `docker-compose-*.yaml`: Service orchestration files
  - `.env`: Environment variables and model endpoints
- **`helm/`**: Kubernetes Helm charts for production deployment
- **`workbench/`**: NVIDIA AI Workbench deployment files

#### `/frontend/`

React-based web UI for interacting with the RAG system:

- Modern chat interface with session management
- Document upload and collection management
- Real-time streaming responses
- Citation viewing and settings configuration

#### `/notebooks/`

Jupyter notebooks for development and testing:

- `launchable.ipynb`: Main interactive notebook
- `rag_library_usage.ipynb`: Python client examples
- `ingestion_api_usage.ipynb`: Document upload examples
- `retriever_api_usage.ipynb`: Search and retrieval examples

#### `/docs/`

Comprehensive documentation:

- Setup guides and quickstart instructions
- API reference and OpenAPI specifications
- Feature configuration guides (guardrails, VLM, audio, etc.)
- Troubleshooting and best practices

#### `/data/`

Sample datasets for testing:

- NVIDIA Developer Blog articles
- Multimodal test documents (PDFs with tables, charts, images)

---

## Model Architecture and Usage

### Primary Models

#### 1. **Main LLM - Llama 3.3 Nemotron Super 49B**

- **Container**: `nim-llm-ms`
- **Port**: 8999
- **Purpose**: Primary response generation
- **Capabilities**:
  - Advanced reasoning and comprehension
  - Context-aware answer generation
  - Multi-turn conversation support
- **GPU Requirements**: High VRAM (recommended 2+ GPUs)

#### 2. **Embedding Model - Llama 3.2 NV EmbedQA 1B**

- **Container**: `nemoretriever-embedding-ms`
- **Port**: 9080
- **Purpose**: Convert text to vector embeddings
- **Used for**:
  - Document chunking and indexing during ingestion
  - Query embedding for similarity search
  - Must be the same model for both ingestion and retrieval

#### 3. **Reranking Model - Llama 3.2 NV RerankQA 1B**

- **Container**: `nemoretriever-ranking-ms`
- **Port**: 1976
- **Purpose**: Improve search result relevance
- **Function**: Takes initial search results and reorders them based on relevance to the query

### Document Processing Models

#### 4. **PaddleOCR**

- **Port**: 8009-8011
- **Purpose**: Optical Character Recognition
- **Extracts**: Text from images and scanned documents

#### 5. **Page Elements Detection**

- **Port**: 8000-8002
- **Purpose**: Document layout analysis
- **Identifies**: Headers, paragraphs, lists, sections

#### 6. **Table Structure Recognition**

- **Port**: 8006-8008
- **Purpose**: Table extraction
- **Processes**: Complex tables with preservation of structure

#### 7. **Graphic Elements Detection**

- **Port**: 8003-8005
- **Purpose**: Visual element analysis
- **Handles**: Charts, diagrams, infographics

### Optional Models

#### 8. **Vision Language Model (VLM)**

- **Container**: `vlm-ms`
- **Model**: Llama 3.1 Nemotron Nano VL 8B
- **Purpose**: Image understanding and captioning
- **Enable with**: `--profile vlm`

#### 9. **Audio Transcription**

- **Container**: `audio`
- **Model**: Riva ASR
- **Purpose**: Convert audio files to text
- **Enable with**: `--profile audio`

#### 10. **Alternative LLMs**

- **Llama 3.1 8B**: Lighter weight option (`--profile llama-8b`)
- **Mixtral 8x22B**: High-performance option (`--profile mixtral-8x22b`)

---

## Model Configuration

### Configuration Files

#### 1. **Primary Configuration: `/deploy/compose/nims.yaml`**

This file defines all NVIDIA NIM microservices and their models:

```yaml
services:
  nim-llm:
    image: nvcr.io/nim/nvidia/llama-3.3-nemotron-super-49b-v1:1.8.5
    # Change this image to use a different LLM
```

#### 2. **Environment Variables: `/deploy/compose/.env`**

Controls model endpoints and GPU assignments:

```bash
# Model endpoints (for on-prem deployment)
export APP_LLM_SERVERURL=nim-llm:8000
export APP_EMBEDDINGS_SERVERURL=nemoretriever-embedding-ms:8000

# GPU assignments
export LLM_MS_GPU_ID=1          # GPU for main LLM
export EMBEDDING_MS_GPU_ID=0    # GPU for embeddings
export RANKING_MS_GPU_ID=0      # GPU for reranking
```

#### 3. **Runtime Model Selection**

Models can also be specified at runtime via environment variables:

```bash
# Change LLM model
APP_LLM_MODELNAME='mistralai/mixtral-8x7b-instruct-v0.1' \
docker compose -f deploy/compose/docker-compose-rag-server.yaml up -d

# Change embedding model
APP_EMBEDDINGS_MODELNAME='NV-Embed-QA' \
docker compose -f deploy/compose/docker-compose-ingestor-server.yaml up -d
```

### How to Change Models

#### Option 1: Use NVIDIA API Catalog (Cloud Models)

1. Comment out local endpoints in `.env`
2. Uncomment cloud endpoints:

```bash
# export APP_LLM_SERVERURL=""
# export EMBEDDING_NIM_ENDPOINT=https://integrate.api.nvidia.com/v1
```

3. Set your NGC API key:

```bash
export NGC_API_KEY="your-api-key"
```

4. Specify model names when starting services

#### Option 2: Deploy Different Local NIMs

1. Edit `/deploy/compose/nims.yaml`
2. Change the Docker image for the desired service:

```yaml
nim-llm:
  image: nvcr.io/nim/meta/llama-3.1-8b-instruct:latest
  # Changed from llama-3.3-nemotron-super-49b
```

3. Restart the services:

```bash
docker compose -f deploy/compose/nims.yaml down
docker compose -f deploy/compose/nims.yaml up -d
```

#### Option 3: Use Custom Models

1. Place your model in a directory
2. Mount it as a volume in the container
3. Set the model path via environment variables

### GPU Assignment

Each model can be assigned to specific GPUs via the `.env` file:

```bash
export LLM_MS_GPU_ID=1              # Main LLM on GPU 1
export EMBEDDING_MS_GPU_ID=0        # Embedding on GPU 0
export RANKING_MS_GPU_ID=0          # Reranking on GPU 0
export YOLOX_MS_GPU_ID=0           # Document processing on GPU 0
```

---

## Getting Started

### Quick Setup

1. **Prerequisites**

   - NVIDIA GPU with CUDA support
   - Docker and Docker Compose
   - NGC API Key (get from [build.nvidia.com](https://build.nvidia.com))
2. **Clone and Configure**

   ```bash
   git clone <repository>
   cd rag

   # Set your API key
   export NGC_API_KEY="your-key-here"
   ```
3. **Start Services**

   ```bash
   # Start vector database
   docker compose -f deploy/compose/vectordb.yaml up -d

   # Start NIM microservices
   docker compose -f deploy/compose/nims.yaml up -d

   # Start RAG server
   docker compose -f deploy/compose/docker-compose-rag-server.yaml up -d

   # Start ingestor
   docker compose -f deploy/compose/docker-compose-ingestor-server.yaml up -d
   ```
4. **Access the Application**

   - Web UI: http://localhost:3000
   - RAG API: http://localhost:8888
   - Jupyter Lab: http://localhost:8090

### Testing the System

1. **Upload Documents**

   - Use the web UI to create a collection
   - Upload PDF/DOCX files
   - Wait for processing to complete
2. **Ask Questions**

   - Type questions in the chat interface
   - View citations to see source documents
   - Enable/disable features in settings
3. **Use the API**

   ```python
   import requests

   response = requests.post(
       "http://localhost:8888/generate",
       json={
           "query": "What is RAG?",
           "collection": "default"
       }
   )
   ```

---

## Additional Resources

- **Official Documentation**: See `/docs/` folder
- **API Reference**: `/docs/api_reference/`
- **Troubleshooting**: `/docs/troubleshooting.md`
- **Best Practices**: `/docs/accuracy_perf.md`
- **Migration Guide**: `/docs/migration_guide.md`

For more detailed configuration options and advanced features, refer to the documentation in the `/docs` directory.
