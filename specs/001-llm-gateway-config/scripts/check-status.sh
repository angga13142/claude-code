#!/bin/bash
# Claude Code Status Check Script
# Purpose: Verify Claude Code is properly configured for gateway usage
# Usage: ./check-status.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Claude Code Gateway Configuration Check"
echo "=========================================="
echo ""

# Function to print success message
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error message
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to mask sensitive values
mask_token() {
    local token="$1"
    local length=${#token}
    
    if [ $length -le 8 ]; then
        echo "****"
    else
        echo "${token:0:4}****${token: -4}"
    fi
}

# Check 1: Claude Code installation
echo "Check 1: Claude Code Installation"
echo "----------------------------------"

if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    print_success "Claude Code is installed (version: $CLAUDE_VERSION)"
else
    print_error "Claude Code is not installed"
    echo ""
    echo "Install Claude Code: https://claude.ai/download"
    exit 1
fi

echo ""

# Check 2: Environment variables
echo "Check 2: Environment Variables"
echo "-------------------------------"

# Check ANTHROPIC_BASE_URL
if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
    print_success "ANTHROPIC_BASE_URL is set"
    echo "  Value: $ANTHROPIC_BASE_URL"
    
    # Validate URL format
    if [[ "$ANTHROPIC_BASE_URL" =~ ^https?:// ]]; then
        print_success "URL format is valid"
    else
        print_warning "URL should start with http:// or https://"
    fi
    
    # Check if it's pointing to default Anthropic API
    if [[ "$ANTHROPIC_BASE_URL" == *"api.anthropic.com"* ]]; then
        print_warning "Base URL points to Anthropic API (not a gateway)"
        echo "  This means you're not using a gateway. Is this intentional?"
    fi
else
    print_warning "ANTHROPIC_BASE_URL is not set"
    echo "  Using default: https://api.anthropic.com (no gateway)"
fi

echo ""

# Check ANTHROPIC_AUTH_TOKEN
if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    MASKED_TOKEN=$(mask_token "$ANTHROPIC_AUTH_TOKEN")
    print_success "ANTHROPIC_AUTH_TOKEN is set"
    echo "  Value: $MASKED_TOKEN (masked)"
    
    # Check token format
    TOKEN_LENGTH=${#ANTHROPIC_AUTH_TOKEN}
    if [ $TOKEN_LENGTH -ge 20 ]; then
        print_success "Token length appears valid ($TOKEN_LENGTH characters)"
    else
        print_warning "Token seems short ($TOKEN_LENGTH characters)"
    fi
else
    print_error "ANTHROPIC_AUTH_TOKEN is not set"
    echo "  This is required for gateway authentication"
fi

echo ""

# Check 3: Optional authentication bypass flags
echo "Check 3: Provider Auth Bypass Flags"
echo "------------------------------------"

if [ -n "${CLAUDE_CODE_SKIP_BEDROCK_AUTH:-}" ]; then
    print_info "CLAUDE_CODE_SKIP_BEDROCK_AUTH = $CLAUDE_CODE_SKIP_BEDROCK_AUTH"
    echo "  Bedrock authentication will be skipped (gateway handles it)"
else
    print_info "CLAUDE_CODE_SKIP_BEDROCK_AUTH not set (default behavior)"
fi

if [ -n "${CLAUDE_CODE_SKIP_VERTEX_AUTH:-}" ]; then
    print_info "CLAUDE_CODE_SKIP_VERTEX_AUTH = $CLAUDE_CODE_SKIP_VERTEX_AUTH"
    echo "  Vertex AI authentication will be skipped (gateway handles it)"
else
    print_info "CLAUDE_CODE_SKIP_VERTEX_AUTH not set (default behavior)"
fi

echo ""

# Check 4: Proxy configuration
echo "Check 4: Proxy Configuration"
echo "----------------------------"

if [ -n "${HTTPS_PROXY:-}" ]; then
    print_info "HTTPS_PROXY is set"
    echo "  Value: $HTTPS_PROXY"
    echo "  Requests will route through corporate proxy"
    
    if [ -n "${NO_PROXY:-}" ]; then
        print_info "NO_PROXY is set"
        echo "  Bypass list: $NO_PROXY"
    fi
else
    print_info "HTTPS_PROXY not set (direct connection)"
fi

echo ""

# Check 5: Google Cloud credentials (for Vertex AI)
echo "Check 5: Google Cloud Credentials"
echo "----------------------------------"

if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    print_info "GOOGLE_APPLICATION_CREDENTIALS is set"
    
    if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        print_success "Credentials file exists: $GOOGLE_APPLICATION_CREDENTIALS"
        
        # Check file permissions
        PERMS=$(stat -c "%a" "$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null || echo "unknown")
        if [ "$PERMS" = "600" ]; then
            print_success "File permissions are secure (600)"
        elif [ "$PERMS" != "unknown" ]; then
            print_warning "File permissions: $PERMS (recommend 600 for security)"
            echo "  Run: chmod 600 $GOOGLE_APPLICATION_CREDENTIALS"
        fi
    else
        print_error "Credentials file not found: $GOOGLE_APPLICATION_CREDENTIALS"
    fi
elif command -v gcloud &> /dev/null; then
    # Check if gcloud auth is configured
    if gcloud auth application-default print-access-token &>/dev/null; then
        print_success "Using gcloud application-default credentials"
    else
        print_warning "gcloud is installed but ADC not configured"
        echo "  Run: gcloud auth application-default login"
    fi
else
    print_info "No Google Cloud credentials configured"
    echo "  Only needed for Vertex AI models"
fi

echo ""

# Check 6: Connectivity test (if gateway URL is set)
echo "Check 6: Gateway Connectivity"
echo "-----------------------------"

if [ -n "${ANTHROPIC_BASE_URL:-}" ] && [[ "$ANTHROPIC_BASE_URL" != *"api.anthropic.com"* ]]; then
    GATEWAY_URL="${ANTHROPIC_BASE_URL%/}"
    
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 5 "$GATEWAY_URL/health" > /dev/null 2>&1; then
            print_success "Gateway is reachable at $GATEWAY_URL"
        else
            print_error "Cannot reach gateway at $GATEWAY_URL"
            echo "  Check if gateway is running: ./health-check.sh"
        fi
    else
        print_warning "curl not installed - skipping connectivity test"
    fi
else
    print_info "No gateway configured (using direct Anthropic API)"
fi

echo ""

# Final summary
echo "=========================================="
echo "Summary & Next Steps"
echo "=========================================="
echo ""

# Determine configuration status
HAS_GATEWAY=false
HAS_AUTH=false

if [ -n "${ANTHROPIC_BASE_URL:-}" ] && [[ "$ANTHROPIC_BASE_URL" != *"api.anthropic.com"* ]]; then
    HAS_GATEWAY=true
fi

if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    HAS_AUTH=true
fi

if [ "$HAS_GATEWAY" = true ] && [ "$HAS_AUTH" = true ]; then
    print_success "Configuration looks complete!"
    echo ""
    echo "Your setup:"
    echo "  Gateway: $ANTHROPIC_BASE_URL"
    echo "  Authentication: ✓ Configured"
    echo ""
    echo "Next steps:"
    echo "  1. Test health: ./health-check.sh"
    echo "  2. Test completion: claude \"Hello, world!\""
    echo "  3. Check logs: claude /status (within Claude Code)"
elif [ "$HAS_GATEWAY" = true ]; then
    print_warning "Gateway is configured but authentication token is missing"
    echo ""
    echo "Set authentication token:"
    echo "  export ANTHROPIC_AUTH_TOKEN=\"your-gateway-token\""
elif [ "$HAS_AUTH" = true ]; then
    print_warning "Authentication is set but no gateway configured"
    echo ""
    echo "Using direct Anthropic API (this is fine if intentional)"
else
    print_warning "No gateway configuration detected"
    echo ""
    echo "To configure a gateway:"
    echo "  export ANTHROPIC_BASE_URL=\"http://localhost:4000\""
    echo "  export ANTHROPIC_AUTH_TOKEN=\"your-gateway-token\""
fi

echo ""
