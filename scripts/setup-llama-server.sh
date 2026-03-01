#!/bin/bash
# Llama Server Setup Script for macOS/Linux
# Ensures llama-server is running on localhost:8080

set -e

LLAMA_PORT=${LLAMA_PORT:-8080}
LLAMA_MODEL=${LLAMA_MODEL:-qwen3.5-35b-a3b}

echo "=== Llama Server Setup Script ==="
echo "Port: $LLAMA_PORT"
echo "Model: $LLAMA_MODEL"
echo ""

# Check if llama-server is installed
if ! command -v llama-server &> /dev/null; then
    echo "❌ llama-server not found"
    echo ""
    echo "Installation options:"
    echo "  1. Build from source: https://github.com/ggerganov/llama.cpp"
    echo "  2. Use package manager:"
    echo "     macOS: brew install llama.cpp"
    echo "     Linux: See https://github.com/ggerganov/llama.cpp"
    echo ""
    echo "  3. Use alternative local LLM servers:"
    echo "     - Ollama: https://ollama.ai"
    echo "     - LocalAI: https://localai.io"
    echo "     - text-generation-webui: https://github.com/oobabooga/text-generation-webui"
    exit 1
fi

echo "✓ llama-server found: $(which llama-server)"

# Check if server is already running
if curl -s "http://localhost:$LLAMA_PORT/health" > /dev/null 2>&1; then
    echo "✓ Llama server already running on port $LLAMA_PORT"
    echo ""
    echo "Test with: curl http://localhost:$LLAMA_PORT/v1/models"
    exit 0
fi

# Check if port is available
if lsof -Pi :$LLAMA_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "❌ Port $LLAMA_PORT is already in use by another process"
    echo ""
    echo "To find what's using the port:"
    echo "  lsof -i :$LLAMA_PORT"
    echo ""
    echo "To kill the process:"
    echo "  kill \$(lsof -t -i :$LLAMA_PORT)"
    exit 1
fi

echo ""
echo "Starting llama server on port $LLAMA_PORT..."
echo "Model: $LLAMA_MODEL"
echo ""

# Note: Actual llama-server command varies by implementation
# This is a generic template - adjust based on your llama server

# Option 1: Using llama.cpp server
if command -v llama-server &> /dev/null; then
    echo "Starting with llama.cpp server..."
    llama-server --model "$LLAMA_MODEL" --port "$LLAMA_PORT" --host 127.0.0.1 &
    SERVER_PID=$!
# Option 2: Using Ollama (if available)
elif command -v ollama &> /dev/null; then
    echo "Ollama detected. Please ensure Ollama is running with:"
    echo "  ollama serve"
    echo ""
    echo "Then pull the model:"
    echo "  ollama pull $LLAMA_MODEL"
    echo ""
    echo "Note: Ollama runs on port 11434 by default."
    echo "To use port 8080, set OLLAMA_HOST=127.0.0.1:8080"
    exit 1
else
    echo "❌ No supported llama server implementation found"
    exit 1
fi

# Wait for server to start
echo "Waiting for server to start..."
for i in {1..30}; do
    if curl -s "http://localhost:$LLAMA_PORT/health" > /dev/null 2>&1; then
        echo "✓ Llama server started successfully"
        echo ""
        echo "Server PID: $SERVER_PID"
        echo "Port: $LLAMA_PORT"
        echo "Model: $LLAMA_MODEL"
        echo ""
        echo "Test with: curl http://localhost:$LLAMA_PORT/v1/models"
        echo ""
        echo "To stop the server: kill $SERVER_PID"
        exit 0
    fi
    sleep 1
done

echo "❌ Server failed to start within 30 seconds"
echo ""
echo "Troubleshooting:"
echo "  1. Check if the model file exists: $LLAMA_MODEL"
echo "  2. Check server logs for errors"
echo "  3. Verify sufficient memory available"
echo "  4. Try starting server manually to see error messages"
exit 1
