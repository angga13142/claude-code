#!/bin/bash
# Prerequisite Checker Script
# Purpose: Verify all prerequisites are met before setting up LLM gateway
# Usage: ./check-prerequisites.sh

set -euo pipefail

# Source troubleshooting utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/troubleshooting-utils.sh" ]; then
    # shellcheck source=troubleshooting-utils.sh
    source "$SCRIPT_DIR/troubleshooting-utils.sh"
else
    # Fallback functions if utils not available
    print_success() { echo "✓ $1"; }
    print_error() { echo "✗ $1"; }
    print_warning() { echo "⚠ $1"; }
    print_info() { echo "ℹ $1"; }
    print_header() { echo ""; echo "=========================================="; echo "$1"; echo "=========================================="; echo ""; }
fi

# Track overall status
ERRORS=0
WARNINGS=0

print_header "LLM Gateway Configuration Prerequisites Check"

# ============================================================================
# 1. System Requirements
# ============================================================================

print_header "1. System Requirements"

# Check Python version
echo "Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
    
    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 9 ]; then
        print_success "Python $PYTHON_VERSION (>= 3.9 required)"
    else
        print_error "Python $PYTHON_VERSION is too old (3.9+ required)"
        ((ERRORS++))
    fi
else
    print_error "Python 3 is not installed"
    ((ERRORS++))
fi

# Check pip
echo "Checking pip..."
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version 2>&1 | awk '{print $2}')
    print_success "pip $PIP_VERSION"
else
    print_warning "pip3 is not installed (needed for installing packages)"
    ((WARNINGS++))
fi

# Check curl
echo "Checking curl..."
if command -v curl &> /dev/null; then
    CURL_VERSION=$(curl --version 2>&1 | head -n1 | awk '{print $2}')
    print_success "curl $CURL_VERSION"
else
    print_error "curl is not installed (required for API testing)"
    ((ERRORS++))
fi

echo ""

# ============================================================================
# 2. Claude Code Installation
# ============================================================================

print_header "2. Claude Code Installation"

if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>&1 || echo "unknown")
    print_success "Claude Code installed (version: $CLAUDE_VERSION)"
else
    print_error "Claude Code is not installed"
    echo "  Install from: https://claude.ai/download"
    ((ERRORS++))
fi

echo ""

# ============================================================================
# 3. Google Cloud Setup (for Vertex AI)
# ============================================================================

print_header "3. Google Cloud Setup (Optional - for Vertex AI)"

# Check gcloud CLI
echo "Checking gcloud CLI..."
if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud --version 2>&1 | head -n1 | awk '{print $NF}')
    print_success "gcloud CLI $GCLOUD_VERSION"
    
    # Check active project
    ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "not-set")
    if [ "$ACTIVE_PROJECT" != "not-set" ]; then
        print_info "Active project: $ACTIVE_PROJECT"
    else
        print_warning "No active GCP project set"
        echo "  Run: gcloud config set project YOUR_PROJECT_ID"
        ((WARNINGS++))
    fi
    
    # Check authentication
    if gcloud auth application-default print-access-token &>/dev/null; then
        print_success "Application Default Credentials configured"
    else
        print_warning "Application Default Credentials not configured"
        echo "  Run: gcloud auth application-default login"
        ((WARNINGS++))
    fi
else
    print_info "gcloud CLI not installed (optional for development)"
    echo "  Install from: https://cloud.google.com/sdk/docs/install"
fi

# Check for service account credentials
echo ""
echo "Checking service account credentials..."
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        print_success "Service account credentials file found"
        print_info "  Path: $GOOGLE_APPLICATION_CREDENTIALS"
        
        # Check file permissions
        PERMS=$(stat -c "%a" "$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null || echo "unknown")
        if [ "$PERMS" = "600" ]; then
            print_success "File permissions are secure (600)"
        elif [ "$PERMS" != "unknown" ]; then
            print_warning "File permissions: $PERMS (recommend 600)"
            echo "  Run: chmod 600 $GOOGLE_APPLICATION_CREDENTIALS"
            ((WARNINGS++))
        fi
    else
        print_error "GOOGLE_APPLICATION_CREDENTIALS points to non-existent file"
        echo "  Path: $GOOGLE_APPLICATION_CREDENTIALS"
        ((ERRORS++))
    fi
else
    print_info "GOOGLE_APPLICATION_CREDENTIALS not set (using gcloud auth or not needed)"
fi

echo ""

# ============================================================================
# 4. Python Dependencies
# ============================================================================

print_header "4. Python Dependencies"

# Check LiteLLM
echo "Checking LiteLLM..."
if python3 -c "import litellm" 2>/dev/null; then
    LITELLM_VERSION=$(python3 -c "import litellm; print(litellm.__version__)" 2>/dev/null || echo "unknown")
    print_success "LiteLLM $LITELLM_VERSION installed"
    
    # Check if litellm command is available
    if command -v litellm &> /dev/null; then
        print_success "litellm CLI command available"
    else
        print_warning "litellm CLI command not found in PATH"
        ((WARNINGS++))
    fi
else
    print_error "LiteLLM is not installed"
    echo "  Install: pip install litellm"
    ((ERRORS++))
fi

# Check google-cloud-aiplatform
echo "Checking google-cloud-aiplatform..."
if python3 -c "import google.cloud.aiplatform" 2>/dev/null; then
    GCP_SDK_VERSION=$(python3 -c "import google.cloud.aiplatform; print(google.cloud.aiplatform.__version__)" 2>/dev/null || echo "unknown")
    print_success "google-cloud-aiplatform $GCP_SDK_VERSION installed"
else
    print_warning "google-cloud-aiplatform not installed (needed for Vertex AI)"
    echo "  Install: pip install google-cloud-aiplatform"
    ((WARNINGS++))
fi

# Check PyYAML
echo "Checking PyYAML..."
if python3 -c "import yaml" 2>/dev/null; then
    YAML_VERSION=$(python3 -c "import yaml; print(yaml.__version__)" 2>/dev/null || echo "unknown")
    print_success "PyYAML $YAML_VERSION installed"
else
    print_warning "PyYAML not installed (needed for config validation)"
    echo "  Install: pip install pyyaml"
    ((WARNINGS++))
fi

echo ""

# ============================================================================
# 5. Optional Tools
# ============================================================================

print_header "5. Optional Tools (Recommended)"

# Check jq
echo "Checking jq..."
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version 2>&1)
    print_success "$JQ_VERSION"
else
    print_info "jq not installed (useful for JSON parsing)"
    echo "  Install: sudo apt install jq (Linux) or brew install jq (macOS)"
fi

# Check netcat
echo "Checking netcat/nc..."
if command -v nc &> /dev/null; then
    print_success "nc (netcat) available"
else
    print_info "nc not installed (useful for port testing)"
fi

# Check lsof
echo "Checking lsof..."
if command -v lsof &> /dev/null; then
    print_success "lsof available"
else
    print_info "lsof not installed (useful for debugging port issues)"
fi

echo ""

# ============================================================================
# 6. Network Connectivity
# ============================================================================

print_header "6. Network Connectivity"

# Test internet connectivity
echo "Testing internet connectivity..."
if curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
    print_success "Internet connection available"
else
    print_warning "Cannot reach internet (may affect gateway setup)"
    ((WARNINGS++))
fi

# Test Anthropic API reachability
echo "Testing Anthropic API reachability..."
if curl -s --connect-timeout 5 https://api.anthropic.com > /dev/null 2>&1; then
    print_success "Anthropic API is reachable"
else
    print_warning "Cannot reach Anthropic API (check proxy/firewall)"
    ((WARNINGS++))
fi

# Test Google Cloud API reachability (if gcloud configured)
if command -v gcloud &> /dev/null; then
    echo "Testing Google Cloud API reachability..."
    if curl -s --connect-timeout 5 https://aiplatform.googleapis.com > /dev/null 2>&1; then
        print_success "Google Cloud AI Platform API is reachable"
    else
        print_warning "Cannot reach Google Cloud APIs (check proxy/firewall)"
        ((WARNINGS++))
    fi
fi

# Check for proxy configuration
echo ""
echo "Checking proxy configuration..."
if [ -n "${HTTPS_PROXY:-}" ]; then
    print_info "HTTPS_PROXY is set: $HTTPS_PROXY"
    
    if [ -n "${NO_PROXY:-}" ]; then
        print_info "NO_PROXY is set: $NO_PROXY"
    fi
else
    print_info "No proxy configured (direct internet connection)"
fi

echo ""

# ============================================================================
# 7. GCP Project Verification (if applicable)
# ============================================================================

if command -v gcloud &> /dev/null && [ "$(gcloud config get-value project 2>/dev/null)" != "" ]; then
    print_header "7. GCP Project Verification"
    
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    print_info "Checking project: $PROJECT_ID"
    
    # Check if Vertex AI API is enabled
    echo ""
    echo "Checking Vertex AI API..."
    if gcloud services list --enabled --filter="name:aiplatform.googleapis.com" 2>/dev/null | grep -q "aiplatform.googleapis.com"; then
        print_success "Vertex AI API is enabled"
    else
        print_warning "Vertex AI API may not be enabled"
        echo "  Enable it: gcloud services enable aiplatform.googleapis.com"
        ((WARNINGS++))
    fi
    
    # Check billing
    echo "Checking billing..."
    if gcloud beta billing projects describe "$PROJECT_ID" &>/dev/null; then
        print_success "Project has billing enabled"
    else
        print_warning "Cannot verify billing status (may require additional permissions)"
        ((WARNINGS++))
    fi
    
    echo ""
fi

# ============================================================================
# Summary
# ============================================================================

print_header "Summary"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    print_success "All prerequisites are met!"
    echo ""
    echo "You're ready to set up the LLM gateway."
    echo ""
    echo "Next steps:"
    echo "  1. Configure LiteLLM: Edit litellm_config.yaml"
    echo "  2. Validate config: python validate-config.py litellm_config.yaml"
    echo "  3. Start gateway: litellm --config litellm_config.yaml"
    echo "  4. Configure Claude Code: Set ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN"
    echo "  5. Verify setup: ./check-status.sh"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    print_warning "Prerequisites mostly met with $WARNINGS warning(s)"
    echo ""
    echo "You can proceed, but address warnings for optimal experience."
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    echo "Fix the errors above before proceeding with gateway setup."
    echo ""
    echo "Common fixes:"
    echo "  - Install Python 3.9+: https://www.python.org/downloads/"
    echo "  - Install LiteLLM: pip install litellm google-cloud-aiplatform"
    echo "  - Install Claude Code: https://claude.ai/download"
    echo "  - Install gcloud CLI: https://cloud.google.com/sdk/docs/install"
    echo ""
    exit 1
fi
