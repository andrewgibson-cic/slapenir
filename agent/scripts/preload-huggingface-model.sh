#!/bin/bash
# Pre-download Hugging Face model for mcp-local-rag
# This script runs during Docker build to cache the embedding model

set -e

echo "Pre-downloading Hugging Face embedding model for mcp-local-rag..."
echo "Model: Xenova/all-MiniLM-L6-v2"
echo ""

# Create cache directory
mkdir -p /home/agent/.cache/huggingface
export HF_HOME=/home/agent/.cache/huggingface
export TRANSFORMERS_CACHE=/home/agent/.cache/huggingface

# Create a temporary Node.js script to download the model
cat > /tmp/download-model.js << 'EOF'
import { pipeline } from '@huggingface/transformers';

async function downloadModel() {
    console.log('Downloading embedding model (this may take a few minutes)...');
    
    try {
        // This will download and cache the model
        const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2', {
            cache_dir: process.env.TRANSFORMERS_CACHE || '/home/agent/.cache/huggingface',
        });
        
        console.log('✅ Model downloaded and cached successfully!');
        
        // Test the model
        const testOutput = await embedder('test', { pooling: 'mean', normalize: true });
        console.log(`✅ Model test successful. Embedding dimension: ${testOutput.dims[0]}`);
        
    } catch (error) {
        console.error('❌ Failed to download model:', error.message);
        process.exit(1);
    }
}

downloadModel();
EOF

# Run the download script
cd /tmp
node --experimental-vm-modules /tmp/download-model.js

# Verify the model was cached
echo ""
echo "Verifying model cache..."
if [ -d "/home/agent/.cache/huggingface/models--Xenova--all-MiniLM-L6-v2" ]; then
    echo "✅ Model cached at: /home/agent/.cache/huggingface/models--Xenova--all-MiniLM-L6-v2"
    ls -lh /home/agent/.cache/huggingface/models--Xenova--all-MiniLM-L6-v2/
else
    echo "❌ Model cache not found!"
    exit 1
fi

# Set ownership
chown -R agent:agent /home/agent/.cache/huggingface

echo ""
echo "✅ Embedding model pre-download complete!"
