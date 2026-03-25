# MCP Knowledge Server - Air-Gapped Embedding Model

**Status**: ✅ Pre-configured for offline operation  
**Model**: `Xenova/all-MiniLM-L6-v2`  
**Cache Location**: `/home/agent/.cache/huggingface/`

---

## Overview

The MCP Knowledge Server uses **mcp-local-rag** with a pre-downloaded embedding model for completely air-gapped operation. No internet access is required at runtime.

---

## Model Details

### all-MiniLM-L6-v2

**Why This Model?**
- ✅ **No authentication required** - works completely offline
- ✅ **Fast and lightweight** - 80MB download, minimal memory
- ✅ **Good general purpose** - works well for documentation
- ✅ **Reliable** - no HuggingFace auth token needed

**Specifications:**
- **Parameters**: 22M
- **Context Length**: 256 tokens
- **Dimensions**: 384
- **Languages**: English
- **Model Size**: ~80MB download

---

## How It Works

### During Docker Build (Internet Required)

```dockerfile
# Pre-download Hugging Face embedding model
RUN node -e "import('@huggingface/transformers').then(...)"
```

This step:
1. Downloads the embedding model from Hugging Face
2. Caches it in `/home/agent/.cache/huggingface/`
3. Tests the model to ensure it works
4. Sets proper ownership for the agent user

**Build Time**: ~2-3 minutes (one-time download)

### At Runtime (No Internet Required)

```json
{
  "environment": {
    "MODEL_NAME": "Xenova/jina-embeddings-v2-base-code",
    "HF_HOME": "/home/agent/.cache/huggingface"
  }
}
```

The server:
1. Loads the pre-cached model from disk
2. No network requests made
3. All embeddings generated locally
4. Fully air-gapped operation

---

## Configuration

### OpenCode Configuration

**File**: `agent/config/opencode.json`

```json
{
  "mcp": {
    "knowledge": {
      "type": "local",
      "command": ["mcp-local-rag"],
      "enabled": true,
      "timeout": 3600000,
      "environment": {
        "BASE_DIR": "/home/agent/workspace/docs",
        "EMBEDDING_PROVIDER": "local",
        "MODEL_NAME": "Xenova/all-MiniLM-L6-v2",
        "HF_HOME": "/home/agent/.cache/huggingface",
        "TRANSFORMERS_CACHE": "/home/agent/.cache/huggingface"
      }
    }
  }
}
```

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `BASE_DIR` | `/home/agent/workspace/docs` | Directory to index |
| `EMBEDDING_PROVIDER` | `local` | Use local embeddings |
| `MODEL_NAME` | `Xenova/all-MiniLM-L6-v2` | Specific model to use |
| `HF_HOME` | `/home/agent/.cache/huggingface` | Cache directory |
| `TRANSFORMERS_CACHE` | `/home/agent/.cache/huggingface` | Cache directory |

---

## Usage

### 1. Add Documents

```bash
# Inside agent container
cd ~/workspace/docs
mkdir -p architecture api guides

# Add your documentation
echo "# Architecture\n\nMicroservices with FastAPI..." > architecture/overview.md
echo "# API Reference\n\n## Authentication\n..." > api/auth.md
```

### 2. Index Documents

```bash
# Start OpenCode
opencode

# Index the docs directory
User: "Index the docs directory"
Agent: [uses knowledge_index_directory tool]
```

### 3. Search Documents

```
User: "What does the documentation say about authentication?"
Agent: [searches indexed docs with embeddings]
Returns: "Based on docs/api/auth.md, authentication uses JWT tokens..."
```

---

## Performance

### Resource Usage

| Metric | Value |
|--------|-------|
| Model Size | 80MB |
| Memory (runtime) | ~100MB |
| Indexing Speed | ~150 docs/min |
| Query Latency | <20ms |

---

## Supported File Types

- ✅ **Markdown** (.md) - Perfect for technical docs
- ✅ **Text** (.txt) - Simple text files
- ✅ **PDF** (.pdf) - Extracted and chunked
- ⚠️ **DOCX** (.docx) - Works but has bugs in mcp-local-rag v0.10.0
- ✅ **HTML** (via ingest_data tool)

---

## Troubleshooting

### Model Not Found

```bash
# Check if model is cached
docker exec slapenir-agent ls -la /home/agent/.cache/huggingface/models--Xenova--all-MiniLM-L6-v2/

# If missing, rebuild container
docker-compose build --no-cache agent
```

### Out of Memory

```bash
# Check memory usage
docker stats slapenir-agent

# If needed, increase container memory in docker-compose.yml
```

### Slow Indexing

```bash
# Check number of files
docker exec slapenir-agent find ~/workspace/docs -type f | wc -l

# Large documents (8K+ tokens) take longer to embed
```

---

## Alternative Models

If you need a different model, update `agent/config/opencode.json`:

### Option 1: Code-Optimized (Better for Code)
```json
"MODEL_NAME": "Xenova/jina-embeddings-v2-base-code"
```
- Trained on 150M+ code-question-answer pairs
- 8K token context length
- Requires HuggingFace auth token (not recommended for air-gapped)
- Larger download (640MB)

### Option 2: Mixedbread (SOTA, General Purpose)
```json
"MODEL_NAME": "mixedbread-ai/mxbai-embed-large-v1"
```
- Better general performance
- Shorter context (512 tokens)
- Larger download (1.3GB)

---

## Model Cache Persistence

The model cache is stored in a Docker volume:

```yaml
volumes:
  - slapenir-huggingface-cache:/home/agent/.cache/huggingface
```

This means:
- ✅ Model persists across container restarts
- ✅ No re-download needed
- ✅ Faster startup after first run

---

## Security

**Air-Gapped Guarantees:**
- ✅ No network requests at runtime
- ✅ All processing happens locally
- ✅ No data leaves the container
- ✅ No external API calls
- ✅ Complete privacy

**Verification:**
```bash
# Check for network attempts
docker exec slapenir-agent iptables -L TRAFFIC_ENFORCE -n -v | grep DROP

# Should show blocked attempts to external IPs
```

---

## Updates

To update the embedding model:

1. **Update Dockerfile** with new model name
2. **Rebuild container**: `docker-compose build agent`
3. **Clear old index**: `~/scripts/reset-memory.sh`
4. **Re-index documents**: In OpenCode, "Index the docs directory"

**Note**: Changing models requires re-indexing all documents.

---

## Comparison with Other Tools

| Feature | Knowledge Server | Memory Server | Code-Graph-RAG |
|---------|------------------|---------------|----------------|
| **Purpose** | Document search | Knowledge graph | Code analysis |
| **Storage** | LanceDB (vectors) | SQLite (graph) | Memgraph (graph) |
| **Best For** | Docs, manuals | Facts, decisions | Code structure |
| **Context** | 8192 tokens | Unlimited | AST-based |
| **Query Type** | Semantic search | Graph traversal | Code queries |

---

## Best Practices

### 1. Document Organization

```
~/workspace/docs/
├── architecture/
│   ├── overview.md
│   ├── microservices.md
│   └── database.md
├── api/
│   ├── authentication.md
│   ├── endpoints.md
│   └── errors.md
└── guides/
    ├── getting-started.md
    └── best-practices.md
```

### 2. Indexing Strategy

```bash
# Index specific directories
User: "Index the architecture docs"

# Or entire docs folder
User: "Index all documentation"
```

### 3. Query Examples

```
# Specific queries work best
"What authentication method does the API use?"
"How do I configure the database connection?"
"What are the microservices boundaries?"
```

---

## References

- [all-MiniLM-L6-v2 on Hugging Face](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2)
- [mcp-local-rag Documentation](https://github.com/shinpr/mcp-local-rag)
- [Transformers.js Documentation](https://huggingface.co/docs/transformers.js)
