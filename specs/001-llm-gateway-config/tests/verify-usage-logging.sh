#!/bin/bash
# Usage Logging Verification Script
# Purpose: Verify that LiteLLM is logging requests correctly
# Usage: ./verify-usage-logging.sh [gateway-url]

set -euo pipefail

# Source troubleshooting utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../scripts/troubleshooting-utils.sh" ]; then
    # shellcheck source=../scripts/troubleshooting-utils.sh
    source "$SCRIPT_DIR/../scripts/troubleshooting-utils.sh"
else
    print_success() { echo "✓ $1"; }
    print_error() { echo "✗ $1"; }
    print_warning() { echo "⚠ $1"; }
    print_info() { echo "ℹ $1"; }
fi

GATEWAY_URL="${1:-http://localhost:4000}"

echo "========================================"
echo "Usage Logging Verification"
echo "========================================"
echo ""
echo "Gateway URL: $GATEWAY_URL"
echo ""

# Check if gateway is reachable
if ! curl -s --connect-timeout 5 "$GATEWAY_URL/health" > /dev/null 2>&1; then
    print_error "Gateway is not reachable at $GATEWAY_URL"
    exit 1
fi

print_success "Gateway is reachable"
echo ""

# Make a test request
print_info "Making test request..."

TEST_RESPONSE=$(curl -s -w "\n%{http_code}" "$GATEWAY_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY:-}" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Test"}],
    "max_tokens": 10
  }' 2>/dev/null || echo "000")

HTTP_CODE=$(echo "$TEST_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Test request successful"
else
    print_error "Test request failed (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""

# Check for usage logging endpoint
print_info "Checking usage logging endpoints..."

# Try to access spend logs (may require authentication)
SPEND_URL="$GATEWAY_URL/spend/logs"
SPEND_RESPONSE=$(curl -s -w "\n%{http_code}" "$SPEND_URL" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY:-}" 2>/dev/null || echo "000")
SPEND_CODE=$(echo "$SPEND_RESPONSE" | tail -n1)

if [ "$SPEND_CODE" = "200" ]; then
    print_success "Usage logging endpoint accessible"
    
    if command -v jq &> /dev/null; then
        SPEND_BODY=$(echo "$SPEND_RESPONSE" | sed '$d')
        LOG_COUNT=$(echo "$SPEND_BODY" | jq 'length' 2>/dev/null || echo "unknown")
        
        if [ "$LOG_COUNT" != "unknown" ] && [ "$LOG_COUNT" -gt 0 ]; then
            print_success "Found $LOG_COUNT logged request(s)"
        else
            print_warning "No usage logs found (may be normal for new setup)"
        fi
    fi
elif [ "$SPEND_CODE" = "401" ]; then
    print_warning "Usage logging requires authentication (this is normal)"
elif [ "$SPEND_CODE" = "404" ]; then
    print_warning "Usage logging endpoint not found"
    echo "  This may indicate:"
    echo "    - LiteLLM version doesn't support this endpoint"
    echo "    - Database logging not configured"
else
    print_warning "Usage logging endpoint returned HTTP $SPEND_CODE"
fi

echo ""

# Check for database configuration
print_info "Checking database configuration..."

if [ -n "${DATABASE_URL:-}" ]; then
    print_success "DATABASE_URL is configured"
    echo "  Database logging is enabled"
else
    print_info "DATABASE_URL not set"
    echo "  In-memory logging only (not persistent)"
    echo ""
    echo "  To enable persistent logging:"
    echo "    export DATABASE_URL=\"postgresql://user:pass@host:5432/litellm\""
fi

echo ""
print_success "Usage logging verification complete"
echo ""
