# RAG Test Notebook - Quick Start

## Fixed Issues
- ✅ Updated API key to working version
- ✅ Installed pymilvus 2.5.4 in conda environment
- ✅ Registered Jupyter kernel for proper package access
- ✅ Cleaned up unnecessary setup scripts

## How to Use

1. **Activate conda environment and launch Jupyter**:
   ```bash
   conda activate ./.conda
   ./.conda/bin/jupyter lab
   ```

2. **Open the notebook**:
   - Open `notebooks/rag_test.ipynb`
   - **IMPORTANT**: Select Kernel → Change Kernel → "RAG Environment (Python 3.11)"

3. **Run the notebook**:
   - Run all cells - the API key is now working
   - The notebook will test the complete RAG pipeline

## What's Fixed
- **API Key**: Updated to valid key that passes authentication
- **Package Issues**: pymilvus and dependencies now properly installed
- **Kernel**: Jupyter kernel uses conda environment with all packages

The notebook should now work without "No module named 'pymilvus'" or 403 API errors.