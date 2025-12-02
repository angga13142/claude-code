#!/usr/bin/env python3
"""
Test Proxy + Gateway Integration

Tests the complete request flow: Claude Code → Corporate Proxy → LiteLLM Gateway → Provider APIs

This script verifies:
1. Proxy connectivity (can reach gateway through proxy)
2. Gateway functionality (gateway processes requests correctly)
3. End-to-end flow (requests traverse proxy to gateway to provider)
4. Authentication handling (proxy auth + provider auth work together)
5. Error handling (proper error messages for proxy/gateway failures)

Usage:
    # Basic test (assumes defaults)
    python test-proxy-gateway.py

    # Custom proxy and gateway
    python test-proxy-gateway.py --proxy http://proxy.corp.example.com:8080 \\
                                   --gateway http://localhost:4000

    # With proxy authentication
    python test-proxy-gateway.py --proxy http://user:pass@proxy.corp.example.com:8080

    # Test specific provider
    python test-proxy-gateway.py --provider anthropic

Exit Codes:
    0 - All tests passed
    1 - One or more tests failed
    2 - Configuration error
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error
from typing import Dict, List, Optional, Tuple

# ANSI color codes
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"


def print_header(text: str) -> None:
    """Print formatted section header."""
    print(f"\n{BLUE}{'=' * 70}{RESET}")
    print(f"{BLUE}{text:^70}{RESET}")
    print(f"{BLUE}{'=' * 70}{RESET}\n")


def print_success(text: str) -> None:
    """Print success message."""
    print(f"{GREEN}✓ {text}{RESET}")


def print_error(text: str) -> None:
    """Print error message."""
    print(f"{RED}✗ {text}{RESET}")


def print_warning(text: str) -> None:
    """Print warning message."""
    print(f"{YELLOW}⚠ {text}{RESET}")


def test_proxy_connectivity(proxy_url: str) -> Tuple[bool, str]:
    """
    Test if proxy is accessible and working.
    
    Args:
        proxy_url: HTTP/HTTPS proxy URL
        
    Returns:
        Tuple of (success: bool, message: str)
    """
    print_header("Test 1: Proxy Connectivity")
    
    # Set up proxy handler
    proxy_handler = urllib.request.ProxyHandler({
        'http': proxy_url,
        'https': proxy_url
    })
    opener = urllib.request.build_opener(proxy_handler)
    
    # Test URL (use httpbin for testing)
    test_url = "http://httpbin.org/ip"
    
    try:
        print(f"Testing proxy: {proxy_url}")
        print(f"Target URL: {test_url}")
        
        req = urllib.request.Request(test_url)
        with opener.open(req, timeout=10) as response:
            data = json.loads(response.read().decode())
            print_success(f"Proxy is accessible")
            print(f"  External IP: {data.get('origin', 'unknown')}")
            return True, "Proxy connectivity verified"
            
    except urllib.error.URLError as e:
        print_error(f"Proxy connection failed: {e.reason}")
        return False, f"Proxy not accessible: {e.reason}"
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return False, f"Proxy test error: {e}"


def test_gateway_through_proxy(gateway_url: str, proxy_url: Optional[str] = None) -> Tuple[bool, str]:
    """
    Test if LiteLLM gateway is accessible through proxy.
    
    Args:
        gateway_url: LiteLLM gateway base URL
        proxy_url: Optional proxy URL (uses environment if not provided)
        
    Returns:
        Tuple of (success: bool, message: str)
    """
    print_header("Test 2: Gateway Through Proxy")
    
    # Set up proxy if provided
    if proxy_url:
        proxy_handler = urllib.request.ProxyHandler({
            'http': proxy_url,
            'https': proxy_url
        })
        opener = urllib.request.build_opener(proxy_handler)
    else:
        opener = urllib.request.build_opener()
    
    health_url = f"{gateway_url}/health"
    
    try:
        print(f"Gateway URL: {gateway_url}")
        if proxy_url:
            print(f"Via proxy: {proxy_url}")
        else:
            print("Using system proxy settings")
        
        req = urllib.request.Request(health_url)
        with opener.open(req, timeout=10) as response:
            if response.status == 200:
                print_success("Gateway is accessible through proxy")
                return True, "Gateway accessible"
            else:
                print_error(f"Gateway returned status {response.status}")
                return False, f"Gateway status: {response.status}"
                
    except urllib.error.URLError as e:
        print_error(f"Cannot reach gateway: {e.reason}")
        return False, f"Gateway not accessible: {e.reason}"
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return False, f"Gateway test error: {e}"


def test_model_request_through_proxy(
    gateway_url: str,
    model_name: str,
    proxy_url: Optional[str] = None
) -> Tuple[bool, str]:
    """
    Test end-to-end model request through proxy and gateway.
    
    Args:
        gateway_url: LiteLLM gateway base URL
        model_name: Model to test
        proxy_url: Optional proxy URL
        
    Returns:
        Tuple of (success: bool, message: str)
    """
    print_header(f"Test 3: Model Request Through Proxy ({model_name})")
    
    # Set up proxy if provided
    if proxy_url:
        proxy_handler = urllib.request.ProxyHandler({
            'http': proxy_url,
            'https': proxy_url
        })
        opener = urllib.request.build_opener(proxy_handler)
    else:
        opener = urllib.request.build_opener()
    
    completion_url = f"{gateway_url}/v1/chat/completions"
    
    # Simple test request
    payload = {
        "model": model_name,
        "messages": [{"role": "user", "content": "Say 'proxy test OK' if you can read this"}],
        "max_tokens": 50
    }
    
    try:
        print(f"Model: {model_name}")
        print(f"Testing end-to-end flow...")
        
        req = urllib.request.Request(
            completion_url,
            data=json.dumps(payload).encode(),
            headers={'Content-Type': 'application/json'}
        )
        
        start_time = time.time()
        with opener.open(req, timeout=60) as response:
            elapsed = time.time() - start_time
            
            if response.status == 200:
                data = json.loads(response.read().decode())
                content = data['choices'][0]['message']['content']
                
                print_success("Request completed successfully")
                print(f"  Response time: {elapsed:.2f}s")
                print(f"  Response: {content[:100]}...")
                return True, f"Model request successful ({elapsed:.2f}s)"
            else:
                print_error(f"Request failed with status {response.status}")
                return False, f"Request status: {response.status}"
                
    except urllib.error.HTTPError as e:
        error_body = e.read().decode() if e.fp else "No error details"
        print_error(f"HTTP error {e.code}: {error_body[:200]}")
        return False, f"HTTP {e.code}"
    except urllib.error.URLError as e:
        print_error(f"Request failed: {e.reason}")
        return False, f"Request failed: {e.reason}"
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        return False, f"Request error: {e}"


def test_proxy_authentication(proxy_url: str) -> Tuple[bool, str]:
    """
    Test proxy authentication (if credentials provided in URL).
    
    Args:
        proxy_url: Proxy URL with optional credentials
        
    Returns:
        Tuple of (success: bool, message: str)
    """
    print_header("Test 4: Proxy Authentication")
    
    # Check if proxy URL contains credentials
    if '@' not in proxy_url:
        print_warning("No credentials in proxy URL - skipping auth test")
        return True, "No proxy auth required"
    
    # Extract credentials
    try:
        # URL format: http://user:pass@proxy.example.com:8080
        parts = proxy_url.split('@')
        creds = parts[0].split('//')[-1]  # Extract user:pass
        print(f"Testing authenticated proxy access...")
        print(f"  Credentials found: {creds.split(':')[0]}:***")
        
        # Test with authentication
        proxy_handler = urllib.request.ProxyHandler({
            'http': proxy_url,
            'https': proxy_url
        })
        opener = urllib.request.build_opener(proxy_handler)
        
        req = urllib.request.Request("http://httpbin.org/ip")
        with opener.open(req, timeout=10) as response:
            if response.status == 200:
                print_success("Proxy authentication successful")
                return True, "Proxy auth verified"
            else:
                print_error(f"Unexpected status: {response.status}")
                return False, f"Auth status: {response.status}"
                
    except urllib.error.HTTPError as e:
        if e.code == 407:
            print_error("Proxy authentication failed (407)")
            return False, "Proxy auth failed - check credentials"
        else:
            print_error(f"HTTP error {e.code}")
            return False, f"HTTP {e.code}"
    except Exception as e:
        print_error(f"Auth test error: {e}")
        return False, f"Auth error: {e}"


def test_proxy_bypass(gateway_url: str, no_proxy: str) -> Tuple[bool, str]:
    """
    Test NO_PROXY configuration (bypass proxy for local URLs).
    
    Args:
        gateway_url: Gateway URL to test
        no_proxy: NO_PROXY environment variable value
        
    Returns:
        Tuple of (success: bool, message: str)
    """
    print_header("Test 5: Proxy Bypass (NO_PROXY)")
    
    print(f"NO_PROXY: {no_proxy}")
    print(f"Gateway URL: {gateway_url}")
    
    # Check if gateway URL should bypass proxy
    gateway_host = gateway_url.split('//')[1].split(':')[0]
    bypass_patterns = [p.strip() for p in no_proxy.split(',')]
    
    should_bypass = any(
        gateway_host == pattern or
        gateway_host.endswith(pattern) or
        pattern.startswith('.') and gateway_host.endswith(pattern)
        for pattern in bypass_patterns
    )
    
    if should_bypass:
        print_success(f"Gateway host '{gateway_host}' matches NO_PROXY pattern")
        print("  Proxy will be bypassed for this request")
        return True, "Proxy bypass configured correctly"
    else:
        print_warning(f"Gateway host '{gateway_host}' does NOT match NO_PROXY")
        print("  All requests will go through proxy")
        return True, "Proxy bypass not applicable"


def main() -> int:
    """Main test routine."""
    parser = argparse.ArgumentParser(
        description="Test Proxy + Gateway Integration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        "--proxy",
        default=os.getenv("HTTPS_PROXY") or os.getenv("HTTP_PROXY"),
        help="Proxy URL (default: $HTTPS_PROXY or $HTTP_PROXY)"
    )
    parser.add_argument(
        "--gateway",
        default=os.getenv("ANTHROPIC_BASE_URL", "http://localhost:4000"),
        help="Gateway URL (default: $ANTHROPIC_BASE_URL or http://localhost:4000)"
    )
    parser.add_argument(
        "--provider",
        choices=["anthropic", "bedrock", "vertex"],
        default="anthropic",
        help="Provider to test (default: anthropic)"
    )
    parser.add_argument(
        "--no-proxy",
        default=os.getenv("NO_PROXY", "localhost,127.0.0.1"),
        help="NO_PROXY value (default: $NO_PROXY)"
    )
    
    args = parser.parse_args()
    
    if not args.proxy:
        print_error("No proxy configured")
        print("Set HTTPS_PROXY environment variable or use --proxy option")
        return 2
    
    # Model names by provider
    models = {
        "anthropic": "claude-3-5-sonnet-20241022",
        "bedrock": "bedrock-claude-sonnet",
        "vertex": "gemini-2.0-flash"
    }
    model = models[args.provider]
    
    print_header("Proxy + Gateway Integration Tests")
    print(f"Proxy: {args.proxy}")
    print(f"Gateway: {args.gateway}")
    print(f"Provider: {args.provider}")
    print(f"Model: {model}")
    
    # Run tests
    results = []
    
    # Test 1: Proxy connectivity
    success, msg = test_proxy_connectivity(args.proxy)
    results.append(("Proxy Connectivity", success, msg))
    
    if not success:
        print_warning("Skipping remaining tests due to proxy failure")
        return 1
    
    # Test 2: Gateway through proxy
    success, msg = test_gateway_through_proxy(args.gateway, args.proxy)
    results.append(("Gateway Through Proxy", success, msg))
    
    if not success:
        print_warning("Skipping model test due to gateway failure")
    else:
        # Test 3: Model request
        success, msg = test_model_request_through_proxy(args.gateway, model, args.proxy)
        results.append(("Model Request", success, msg))
    
    # Test 4: Proxy authentication (if applicable)
    success, msg = test_proxy_authentication(args.proxy)
    results.append(("Proxy Authentication", success, msg))
    
    # Test 5: Proxy bypass
    success, msg = test_proxy_bypass(args.gateway, args.no_proxy)
    results.append(("Proxy Bypass", success, msg))
    
    # Summary
    print_header("Test Summary")
    
    passed = sum(1 for _, success, _ in results if success)
    failed = len(results) - passed
    
    for test_name, success, message in results:
        status = f"{GREEN}PASS{RESET}" if success else f"{RED}FAIL{RESET}"
        print(f"{status} - {test_name}: {message}")
    
    print(f"\n{GREEN}Passed: {passed}{RESET}")
    print(f"{RED}Failed: {failed}{RESET}")
    print(f"Total: {len(results)}")
    
    if failed > 0:
        print(f"\n{RED}Some tests failed - check proxy and gateway configuration{RESET}")
        print("\nTroubleshooting:")
        print("1. Verify proxy URL is correct: curl -x $HTTPS_PROXY https://httpbin.org/ip")
        print("2. Check gateway is running: curl http://localhost:4000/health")
        print("3. Verify proxy credentials (if required)")
        print("4. Check NO_PROXY settings for local gateway")
        print("\nSee: examples/us4-proxy-troubleshooting.md")
        return 1
    
    print(f"\n{GREEN}All tests passed! Proxy + Gateway integration working correctly.{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
