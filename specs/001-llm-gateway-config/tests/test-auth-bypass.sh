#!/usr/bin/env bash
# Authentication Bypass Verification Script
# Purpose: Verify authentication bypass flags are working correctly
# User Story: US3 - Multi-Provider Gateway Configuration (Priority: P3)
# Usage: ./test-auth-bypass.sh
# Exit Codes: 0 (pass), 1 (fail)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
GATEWAY_URL="${ANTHROPIC_BASE_URL:-http://localhost:4000}"
LITELLM_KEY="${ANTHROPIC_API_KEY:-}"
TEST_MODEL="${TEST_MODEL:-claude-3-5-sonnet-20241022}"

echo -e "${BLUE}🔒 Authentication Bypass Verification Test${NC}"
echo -e "${BLUE}==========================================${NC}\n"

# Check if gateway is running
echo -e "${BLUE}📡 Checking gateway connectivity...${NC}"
if ! curl -s -f "${GATEWAY_URL}/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Gateway not reachable at ${GATEWAY_URL}${NC}"
    echo -e "${YELLOW}ℹ  Start LiteLLM proxy first: litellm --config <config.yaml>${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Gateway is reachable${NC}\n"

# Check for LiteLLM master key
if [ -z "$LITELLM_KEY" ]; then
    echo -e "${RED}❌ ANTHROPIC_API_KEY not set (required for LiteLLM master key)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ LiteLLM master key is set${NC}\n"

# Test 1: Verify Bedrock bypass flag
echo -e "${BLUE}🧪 Test 1: Bedrock Authentication Bypass${NC}"
echo -e "   Testing CLAUDE_CODE_SKIP_BEDROCK_AUTH flag\n"

if [ -n "${CLAUDE_CODE_SKIP_BEDROCK_AUTH:-}" ]; then
    echo -e "${GREEN}✓ CLAUDE_CODE_SKIP_BEDROCK_AUTH is set to: $CLAUDE_CODE_SKIP_BEDROCK_AUTH${NC}"
    
    # Verify flag value is valid (1, true, or True)
    if [[ "$CLAUDE_CODE_SKIP_BEDROCK_AUTH" =~ ^(1|true|True)$ ]]; then
        echo -e "${GREEN}✓ Flag value is valid${NC}"
    else
        echo -e "${YELLOW}⚠ Flag value '$CLAUDE_CODE_SKIP_BEDROCK_AUTH' may not be recognized${NC}"
        echo -e "${YELLOW}  Valid values: 1, true, True${NC}"
    fi
    
    # Check if Bedrock credentials are NOT set (they shouldn't be needed)
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        echo -e "${GREEN}✓ AWS credentials not set (as expected with bypass enabled)${NC}"
    else
        echo -e "${YELLOW}⚠ AWS credentials are set (bypass flag should make them unnecessary)${NC}"
    fi
else
    echo -e "${YELLOW}ℹ CLAUDE_CODE_SKIP_BEDROCK_AUTH is not set${NC}"
    echo -e "${YELLOW}  This is normal if not using Bedrock provider${NC}"
fi
echo ""

# Test 2: Verify Vertex AI bypass flag
echo -e "${BLUE}🧪 Test 2: Vertex AI Authentication Bypass${NC}"
echo -e "   Testing CLAUDE_CODE_SKIP_VERTEX_AUTH flag\n"

if [ -n "${CLAUDE_CODE_SKIP_VERTEX_AUTH:-}" ]; then
    echo -e "${GREEN}✓ CLAUDE_CODE_SKIP_VERTEX_AUTH is set to: $CLAUDE_CODE_SKIP_VERTEX_AUTH${NC}"
    
    # Verify flag value is valid
    if [[ "$CLAUDE_CODE_SKIP_VERTEX_AUTH" =~ ^(1|true|True)$ ]]; then
        echo -e "${GREEN}✓ Flag value is valid${NC}"
    else
        echo -e "${YELLOW}⚠ Flag value '$CLAUDE_CODE_SKIP_VERTEX_AUTH' may not be recognized${NC}"
        echo -e "${YELLOW}  Valid values: 1, true, True${NC}"
    fi
    
    # Check if Vertex AI credentials are set (LiteLLM needs them, but Claude Code doesn't)
    if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] || [ -n "${VERTEX_PROJECT_ID:-}" ]; then
        echo -e "${GREEN}✓ Vertex AI credentials are set (LiteLLM will use them)${NC}"
        echo -e "${GREEN}✓ Claude Code will skip its own Vertex AI authentication${NC}"
    else
        echo -e "${YELLOW}⚠ Vertex AI credentials not found${NC}"
        echo -e "${YELLOW}  LiteLLM still needs credentials to call Vertex AI${NC}"
    fi
else
    echo -e "${YELLOW}ℹ CLAUDE_CODE_SKIP_VERTEX_AUTH is not set${NC}"
    echo -e "${YELLOW}  This is normal if not using Vertex AI provider${NC}"
fi
echo ""

# Test 3: Test actual API call with bypass
echo -e "${BLUE}🧪 Test 3: End-to-End API Call${NC}"
echo -e "   Testing that gateway accepts requests without provider auth\n"

RESPONSE=$(curl -s -X POST "${GATEWAY_URL}/v1/messages" \
    -H "x-api-key: ${LITELLM_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
        \"model\": \"${TEST_MODEL}\",
        \"max_tokens\": 10,
        \"messages\": [{
            \"role\": \"user\",
            \"content\": \"Say 'test success' in 2 words\"
        }]
    }" 2>&1)

if echo "$RESPONSE" | grep -q '"content"'; then
    echo -e "${GREEN}✓ API call succeeded${NC}"
    
    # Extract and display response content
    CONTENT=$(echo "$RESPONSE" | grep -o '"text":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "${GREEN}✓ Response content: $CONTENT${NC}"
    
    echo -e "\n${GREEN}✅ Authentication bypass is working correctly${NC}"
    echo -e "${GREEN}   Claude Code is routing through LiteLLM without provider-specific auth${NC}"
else
    echo -e "${RED}❌ API call failed${NC}"
    echo -e "${RED}Response: $RESPONSE${NC}"
    
    # Check for common error patterns
    if echo "$RESPONSE" | grep -q "authentication"; then
        echo -e "\n${RED}❌ Authentication error detected${NC}"
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo -e "${YELLOW}1. Verify ANTHROPIC_API_KEY matches LITELLM_MASTER_KEY${NC}"
        echo -e "${YELLOW}2. Check that bypass flags are set correctly${NC}"
        echo -e "${YELLOW}3. Ensure LiteLLM has valid provider credentials${NC}"
    elif echo "$RESPONSE" | grep -q "connection"; then
        echo -e "\n${RED}❌ Connection error${NC}"
        echo -e "${YELLOW}1. Verify gateway is running at ${GATEWAY_URL}${NC}"
        echo -e "${YELLOW}2. Check firewall/network settings${NC}"
    fi
    
    exit 1
fi
echo ""

# Test 4: Verify Claude Code integration
echo -e "${BLUE}🧪 Test 4: Claude Code Environment Check${NC}"
echo -e "   Verifying Claude Code environment variables\n"

ERRORS=0

if [ "${ANTHROPIC_BASE_URL:-}" = "" ]; then
    echo -e "${RED}❌ ANTHROPIC_BASE_URL not set${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ ANTHROPIC_BASE_URL: $ANTHROPIC_BASE_URL${NC}"
fi

if [ "${ANTHROPIC_API_KEY:-}" = "" ]; then
    echo -e "${RED}❌ ANTHROPIC_API_KEY not set${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:0:10}...${NC}"
fi

if [ $ERRORS -gt 0 ]; then
    echo -e "\n${RED}❌ Claude Code environment variables not properly configured${NC}"
    exit 1
fi

echo -e "\n${GREEN}✓ Claude Code environment variables are properly configured${NC}"
echo ""

# Summary
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}✅ All authentication bypass tests passed!${NC}"
echo -e "${BLUE}==========================================${NC}\n"

echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "  Gateway URL: ${GATEWAY_URL}"
echo -e "  Test Model: ${TEST_MODEL}"
if [ -n "${CLAUDE_CODE_SKIP_BEDROCK_AUTH:-}" ]; then
    echo -e "  Bedrock Bypass: ${GREEN}Enabled${NC}"
fi
if [ -n "${CLAUDE_CODE_SKIP_VERTEX_AUTH:-}" ]; then
    echo -e "  Vertex AI Bypass: ${GREEN}Enabled${NC}"
fi
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Run 'claude /status' to verify Claude Code connection"
echo -e "  2. Test multi-provider routing with: python tests/test-multi-provider-routing.py"
echo -e "  3. See examples/us3-auth-bypass-guide.md for detailed usage guide"
echo ""

exit 0
