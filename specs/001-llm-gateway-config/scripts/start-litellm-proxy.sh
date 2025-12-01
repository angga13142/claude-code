#!/bin/bash
# LiteLLM Proxy Startup Script
# Purpose: Start LiteLLM proxy with proper configuration and error handling
# Usage: ./start-litellm-proxy.sh [config-file] [port]

set -euo pipefail

# Source troubleshooting utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/troubleshooting-utils.sh" ]; then
    # shellcheck source=troubleshooting-utils.sh
    source "$SCRIPT_DIR/troubleshooting-utils.sh"
else
    print_info() { echo "ℹ $1"; }
    print_success() { echo "✓ $1"; }
    print_error() { echo "✗ $1"; }
    print_warning() { echo "⚠ $1"; }
fi

# Default values
DEFAULT_CONFIG="../templates/litellm-complete.yaml"
DEFAULT_PORT=4000

# Parse arguments
CONFIG_FILE="${1:-$DEFAULT_CONFIG}"
PORT="${2:-$DEFAULT_PORT}"

echo "========================================"
echo "LiteLLM Proxy Startup"
echo "========================================"
echo ""

# Check if LiteLLM is installed
if ! command -v litellm &> /dev/null; then
    print_error "LiteLLM is not installed"
    echo ""
    echo "Install with:"
    echo "  pip install litellm google-cloud-aiplatform"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    echo ""
    echo "Usage: $0 [config-file] [port]"
    echo "  config-file: Path to litellm_config.yaml (default: $DEFAULT_CONFIG)"
    echo "  port: Port number (default: $DEFAULT_PORT)"
    exit 1
fi

print_success "Configuration file: $CONFIG_FILE"
print_success "Port: $PORT"
echo ""

# Check required environment variables
print_info "Checking environment variables..."

if [ -z "${LITELLM_MASTER_KEY:-}" ]; then
    print_error "LITELLM_MASTER_KEY is not set"
    echo ""
    echo "Set it with:"
    echo "  export LITELLM_MASTER_KEY=\"sk-your-secure-key\""
    echo ""
    echo "Generate a secure key:"
    echo "  export LITELLM_MASTER_KEY=\"sk-\$(openssl rand -hex 16)\""
    exit 1
fi

print_success "LITELLM_MASTER_KEY is set"

# Check Google Cloud authentication
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        print_success "Using service account: $GOOGLE_APPLICATION_CREDENTIALS"
    else
        print_error "GOOGLE_APPLICATION_CREDENTIALS file not found: $GOOGLE_APPLICATION_CREDENTIALS"
        exit 1
    fi
elif command -v gcloud &> /dev/null && gcloud auth application-default print-access-token &>/dev/null; then
    print_success "Using gcloud application-default credentials"
else
    print_warning "No Google Cloud credentials found"
    echo "  For Vertex AI models, you need to authenticate:"
    echo "    Option 1: gcloud auth application-default login"
    echo "    Option 2: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json"
fi

echo ""

# Check if port is already in use
if command -v lsof &> /dev/null; then
    if lsof -Pi :"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_error "Port $PORT is already in use"
        echo ""
        echo "Process using port $PORT:"
        lsof -Pi :"$PORT" -sTCP:LISTEN
        echo ""
        echo "To stop the process:"
        echo "  kill \$(lsof -t -i:$PORT)"
        exit 1
    fi
fi

# Validate configuration file
print_info "Validating configuration..."
if [ -f "$SCRIPT_DIR/validate-config.py" ]; then
    if python3 "$SCRIPT_DIR/validate-config.py" "$CONFIG_FILE" > /dev/null 2>&1; then
        print_success "Configuration is valid"
    else
        print_warning "Configuration has warnings (see details below)"
        echo ""
        python3 "$SCRIPT_DIR/validate-config.py" "$CONFIG_FILE"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

echo ""
print_info "Starting LiteLLM proxy..."
echo ""
echo "  Config: $CONFIG_FILE"
echo "  Port: $PORT"
echo "  Master Key: ${LITELLM_MASTER_KEY:0:8}****"
echo ""
echo "Press Ctrl+C to stop the proxy"
echo "========================================"
echo ""

# Start LiteLLM proxy
exec litellm --config "$CONFIG_FILE" --port "$PORT"
