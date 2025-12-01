#!/bin/bash
# Common Troubleshooting Functions
# Purpose: Reusable functions for troubleshooting gateway configurations
# Usage: Source this file in other scripts: source troubleshooting-utils.sh

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# ============================================================================
# Output Functions
# ============================================================================

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# ============================================================================
# Diagnostic Functions
# ============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if a port is listening
port_is_listening() {
    local port=$1
    
    if command_exists nc; then
        nc -z localhost "$port" 2>/dev/null
    elif command_exists telnet; then
        timeout 1 telnet localhost "$port" 2>/dev/null | grep -q "Connected"
    else
        # Fallback: check with /proc (Linux only)
        [ -n "$(ss -tlnp 2>/dev/null | grep ":$port ")" ]
    fi
}

# Get process listening on a port
get_process_on_port() {
    local port=$1
    
    if command_exists lsof; then
        lsof -ti:"$port" 2>/dev/null
    elif command_exists netstat; then
        netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1
    elif command_exists ss; then
        ss -tlnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+'
    else
        echo "unknown"
    fi
}

# Test HTTP endpoint
test_endpoint() {
    local url=$1
    local expected_code=${2:-200}
    
    if ! command_exists curl; then
        echo "ERROR: curl is required for endpoint testing"
        return 1
    fi
    
    local response
    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "$expected_code" ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Environment Variable Checks
# ============================================================================

# Check if required environment variables are set
check_required_env_vars() {
    local missing=()
    
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            missing+=("$var")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing[@]}"; do
            echo "  - $var"
        done
        return 1
    fi
    
    return 0
}

# Validate URL format
validate_url() {
    local url=$1
    
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Mask sensitive token for display
mask_token() {
    local token="$1"
    local length=${#token}
    
    if [ $length -le 8 ]; then
        echo "****"
    else
        echo "${token:0:4}****${token: -4}"
    fi
}

# ============================================================================
# Gateway-Specific Checks
# ============================================================================

# Check if LiteLLM is running
is_litellm_running() {
    if pgrep -f "litellm" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get LiteLLM process PID
get_litellm_pid() {
    pgrep -f "litellm" | head -n1
}

# Check LiteLLM health endpoint
check_litellm_health() {
    local base_url=${1:-"http://localhost:4000"}
    local health_url="${base_url%/}/health"
    
    test_endpoint "$health_url" 200
}

# ============================================================================
# Google Cloud Functions
# ============================================================================

# Check if gcloud is authenticated
is_gcloud_authenticated() {
    if ! command_exists gcloud; then
        return 1
    fi
    
    gcloud auth application-default print-access-token &>/dev/null
}

# Validate Google Cloud credentials file
validate_gcp_credentials() {
    local cred_file="${1:-${GOOGLE_APPLICATION_CREDENTIALS:-}}"
    
    if [ -z "$cred_file" ]; then
        print_error "No credentials file specified"
        return 1
    fi
    
    if [ ! -f "$cred_file" ]; then
        print_error "Credentials file not found: $cred_file"
        return 1
    fi
    
    # Check if it's valid JSON
    if command_exists jq; then
        if ! jq empty "$cred_file" 2>/dev/null; then
            print_error "Credentials file is not valid JSON"
            return 1
        fi
        
        # Check for required fields
        local required_fields=("type" "project_id" "client_email")
        for field in "${required_fields[@]}"; do
            if ! jq -e ".$field" "$cred_file" &>/dev/null; then
                print_error "Credentials file missing required field: $field"
                return 1
            fi
        done
    fi
    
    return 0
}

# ============================================================================
# Configuration File Checks
# ============================================================================

# Check if LiteLLM config file exists and is valid YAML
validate_litellm_config() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check if Python and PyYAML are available
    if command_exists python3; then
        if python3 -c "import yaml" 2>/dev/null; then
            python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null
            return $?
        fi
    fi
    
    # Fallback: basic YAML syntax check
    if grep -q "^[[:space:]]*-[[:space:]]*model_name:" "$config_file"; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Common Error Scenarios
# ============================================================================

# Diagnose connection refused error
diagnose_connection_refused() {
    local url=$1
    local port
    port=$(echo "$url" | sed -n 's/.*:\([0-9]\+\).*/\1/p')
    
    print_header "Diagnosing Connection Refused"
    
    if [ -z "$port" ]; then
        port=4000  # Default LiteLLM port
    fi
    
    echo "Checking port $port..."
    
    if port_is_listening "$port"; then
        print_success "Port $port is listening"
        
        local pid
        pid=$(get_process_on_port "$port")
        if [ "$pid" != "unknown" ]; then
            print_info "Process on port: PID $pid"
            ps -p "$pid" -o comm= 2>/dev/null || echo "  (process details unavailable)"
        fi
    else
        print_error "Nothing is listening on port $port"
        echo ""
        echo "Possible causes:"
        echo "  1. LiteLLM proxy is not running"
        echo "  2. Wrong port number in ANTHROPIC_BASE_URL"
        echo "  3. Proxy failed to start (check logs)"
        echo ""
        echo "Solutions:"
        echo "  1. Start LiteLLM: litellm --config litellm_config.yaml"
        echo "  2. Check port: echo \$ANTHROPIC_BASE_URL"
        echo "  3. Verify config: python validate-config.py litellm_config.yaml"
    fi
}

# Diagnose authentication errors
diagnose_auth_error() {
    print_header "Diagnosing Authentication Error"
    
    if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
        print_error "ANTHROPIC_AUTH_TOKEN is not set"
        echo ""
        echo "Solution:"
        echo "  export ANTHROPIC_AUTH_TOKEN=\"your-gateway-master-key\""
        return
    fi
    
    if [ -z "${LITELLM_MASTER_KEY:-}" ]; then
        print_warning "LITELLM_MASTER_KEY is not set"
        echo "  This should match ANTHROPIC_AUTH_TOKEN for LiteLLM"
    fi
    
    local claude_token
    claude_token=$(mask_token "$ANTHROPIC_AUTH_TOKEN")
    print_info "ANTHROPIC_AUTH_TOKEN: $claude_token"
    
    if [ -n "${LITELLM_MASTER_KEY:-}" ]; then
        local litellm_token
        litellm_token=$(mask_token "$LITELLM_MASTER_KEY")
        print_info "LITELLM_MASTER_KEY: $litellm_token"
        
        if [ "$ANTHROPIC_AUTH_TOKEN" != "$LITELLM_MASTER_KEY" ]; then
            print_error "Tokens do not match!"
            echo ""
            echo "For LiteLLM, these should be identical:"
            echo "  ANTHROPIC_AUTH_TOKEN = LITELLM_MASTER_KEY"
        else
            print_success "Tokens match"
        fi
    fi
}

# Diagnose Vertex AI permission errors
diagnose_vertex_permissions() {
    print_header "Diagnosing Vertex AI Permissions"
    
    # Check authentication method
    if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
        print_info "Using service account: $GOOGLE_APPLICATION_CREDENTIALS"
        
        if validate_gcp_credentials "$GOOGLE_APPLICATION_CREDENTIALS"; then
            print_success "Credentials file is valid"
            
            if command_exists jq; then
                local email
                email=$(jq -r '.client_email' "$GOOGLE_APPLICATION_CREDENTIALS")
                print_info "Service account: $email"
            fi
        fi
    elif is_gcloud_authenticated; then
        print_success "Using gcloud application-default credentials"
    else
        print_error "No Google Cloud authentication configured"
        echo ""
        echo "Choose one option:"
        echo "  1. gcloud auth: gcloud auth application-default login"
        echo "  2. Service account: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json"
        return
    fi
    
    # Check required IAM role
    echo ""
    echo "Required IAM role: roles/aiplatform.user"
    echo ""
    echo "To grant this role:"
    echo "  gcloud projects add-iam-policy-binding PROJECT_ID \\"
    echo "    --member=\"serviceAccount:EMAIL\" \\"
    echo "    --role=\"roles/aiplatform.user\""
}

# ============================================================================
# Utility Functions
# ============================================================================

# Pretty print JSON if jq is available
pretty_json() {
    if command_exists jq; then
        jq '.'
    else
        cat
    fi
}

# Get script directory (useful for relative paths)
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

# Export all functions so they can be used by scripts that source this file
export -f print_success print_error print_warning print_info print_header
export -f command_exists port_is_listening get_process_on_port test_endpoint
export -f check_required_env_vars validate_url mask_token
export -f is_litellm_running get_litellm_pid check_litellm_health
export -f is_gcloud_authenticated validate_gcp_credentials validate_litellm_config
export -f diagnose_connection_refused diagnose_auth_error diagnose_vertex_permissions
export -f pretty_json get_script_dir
