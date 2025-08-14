# NIM API Configuration Guide

## Overview
This guide shows you exactly where and how to configure NIM APIs when running this RAG project.

## Step 1: Set Your NGC API Key

First, you need an NGC API key from NVIDIA:

1. **Get your API key:**
   - Go to https://org.ngc.nvidia.com/setup/api-keys
   - Click **+ Generate Personal Key**
   - Select **NGC Catalog** and **Public API Endpoints**
   - Generate and copy your key

2. **Export the key in your terminal:**
   ```bash
   export NGC_API_KEY="nvapi-xxxxx-your-key-here"
   ```

## Step 2: Choose Your Deployment Mode

### Option A: Use Local GPUs (On-Premises NIMs)

**File to configure:** `/deploy/compose/.env`

This is the DEFAULT configuration - models run on YOUR local GPUs:

```bash
# This section is ACTIVE by default
export APP_LLM_SERVERURL=nim-llm:8000
export APP_EMBEDDINGS_SERVERURL=nemoretriever-embedding-ms:8000
export APP_RANKING_SERVERURL=nemoretriever-ranking-ms:8000

# GPU assignments for your local GPUs
export LLM_MS_GPU_ID=1              # Which GPU runs the LLM
export EMBEDDING_MS_GPU_ID=0        # Which GPU runs embeddings
export RANKING_MS_GPU_ID=0          # Which GPU runs reranking
```

**To run with local GPUs:**
```bash
# 1. Source the environment
source deploy/compose/.env

# 2. Start the NIM containers on your GPUs
docker compose -f deploy/compose/nims.yaml up -d

# 3. Start other services
docker compose -f deploy/compose/vectordb.yaml up -d
docker compose -f deploy/compose/docker-compose-rag-server.yaml up -d
docker compose -f deploy/compose/docker-compose-ingestor-server.yaml up -d
```

### Option B: Use NVIDIA Cloud APIs (No Local GPU Needed)

**File to configure:** `/deploy/compose/.env`

To use cloud APIs instead of local GPUs:

1. **Edit `/deploy/compose/.env`:**
   ```bash
   # COMMENT OUT the local endpoints (add # at the beginning)
   # export APP_LLM_SERVERURL=nim-llm:8000
   # export APP_EMBEDDINGS_SERVERURL=nemoretriever-embedding-ms:8000
   # export APP_RANKING_SERVERURL=nemoretriever-ranking-ms:8000
   
   # UNCOMMENT the cloud endpoints (remove # from the beginning)
   export APP_EMBEDDINGS_SERVERURL=""
   export APP_LLM_SERVERURL=""
   export APP_RANKING_SERVERURL=""
   export EMBEDDING_NIM_ENDPOINT=https://integrate.api.nvidia.com/v1
   export PADDLE_HTTP_ENDPOINT=https://ai.api.nvidia.com/v1/cv/baidu/paddleocr
   export PADDLE_INFER_PROTOCOL=http
   # ... (uncomment all cloud endpoints)
   ```

2. **Run with cloud APIs:**
   ```bash
   # 1. Source the modified environment
   source deploy/compose/.env
   
   # 2. DO NOT start nims.yaml (no local models needed)
   # 3. Only start the orchestration services
   docker compose -f deploy/compose/vectordb.yaml up -d
   docker compose -f deploy/compose/docker-compose-rag-server.yaml up -d
   docker compose -f deploy/compose/docker-compose-ingestor-server.yaml up -d
   ```

## Step 3: Runtime Model Selection (Optional)

You can also specify different models at runtime:

### Change the LLM model:
```bash
APP_LLM_MODELNAME='mistralai/mixtral-8x7b-instruct-v0.1' \
docker compose -f deploy/compose/docker-compose-rag-server.yaml up -d
```

### Change the embedding model:
```bash
APP_EMBEDDINGS_MODELNAME='NV-Embed-QA' \
docker compose -f deploy/compose/docker-compose-ingestor-server.yaml up -d
```

## Quick Reference: Key Configuration Files

| File | Purpose | When to Edit |
|------|---------|--------------|
| `/deploy/compose/.env` | Main configuration - endpoints and GPU assignments | Always - to switch between local/cloud |
| `/deploy/compose/nims.yaml` | Docker images for local models | To change which models to deploy locally |
| `NGC_API_KEY` environment variable | Authentication | Always required |

## Decision Tree

```
Do you have high-end GPUs (A100/H100)?
├─ YES → Use Option A (Local NIMs)
│        Edit: Keep default .env settings
│        Run: nims.yaml + all services
│        Cost: Only hardware/electricity
│
└─ NO → Use Option B (Cloud APIs)
         Edit: Comment local, uncomment cloud in .env
         Run: Only orchestration services (no nims.yaml)
         Cost: Pay per API call
```

## Common Issues

1. **"Unauthorized" errors**: Check your NGC_API_KEY is set correctly
2. **"Connection refused"**: 
   - Local mode: Check if NIM containers are running (`docker ps`)
   - Cloud mode: Check if you uncommented cloud endpoints in .env
3. **Out of memory**: Your GPU doesn't have enough VRAM for local models - switch to cloud mode

## Verify Your Configuration

After configuration, check which mode you're in:

```bash
# Check current settings
cat deploy/compose/.env | grep -E "APP_LLM_SERVERURL|EMBEDDING_NIM_ENDPOINT"

# If you see:
# export APP_LLM_SERVERURL=nim-llm:8000  → Local mode
# export APP_LLM_SERVERURL=""            → Cloud mode
```