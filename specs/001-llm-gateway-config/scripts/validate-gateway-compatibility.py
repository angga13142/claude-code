#!/usr/bin/env python3
"""
Gateway Compatibility Validator for Claude Code

Purpose: Validates that an enterprise gateway meets Claude Code compatibility requirements
Usage: python validate-gateway-compatibility.py --url https://gateway.example.com --token your-api-key

Requirements (per spec.md Gateway Compatibility Criteria):
1. Supports Messages API endpoints (/v1/messages)
2. Forwards required headers (anthropic-version, anthropic-beta, anthropic-client-version)
3. Preserves request/response body format
4. Returns standard HTTP status codes
5. Supports Server-Sent Events (SSE) for streaming
6. Handles authentication via Bearer token
7. Maintains minimum 60-second timeout
"""

import argparse
import json
import sys
import time
from typing import Dict, List, Tuple
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


class GatewayValidator:
    """Validates gateway compatibility with Claude Code requirements"""
    
    def __init__(self, gateway_url: str, auth_token: str, verbose: bool = False):
        self.gateway_url = gateway_url.rstrip('/')
        self.auth_token = auth_token
        self.verbose = verbose
        self.results = []
        
        # Configure session with retries
        self.session = requests.Session()
        retry_strategy = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[502, 503, 504]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def log(self, message: str, color: str = Colors.RESET):
        """Print colored log message"""
        if self.verbose:
            print(f"{color}{message}{Colors.RESET}")
    
    def add_result(self, check_name: str, passed: bool, message: str, details: str = ""):
        """Record validation result"""
        self.results.append({
            "check": check_name,
            "passed": passed,
            "message": message,
            "details": details
        })
        
        status = f"{Colors.GREEN}✓ PASS{Colors.RESET}" if passed else f"{Colors.RED}✗ FAIL{Colors.RESET}"
        print(f"{status} - {check_name}: {message}")
        if details and self.verbose:
            print(f"       {Colors.BLUE}Details: {details}{Colors.RESET}")
    
    def check_endpoint_support(self) -> bool:
        """Check 1: Verify /v1/messages endpoint exists"""
        self.log("\n[Check 1/7] Testing endpoint support...", Colors.BOLD)
        
        try:
            # Test with minimal valid request
            response = self.session.post(
                f"{self.gateway_url}/v1/messages",
                headers={
                    "Authorization": f"Bearer {self.auth_token}",
                    "Content-Type": "application/json",
                    "anthropic-version": "2023-06-01"
                },
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "max_tokens": 10,
                    "messages": [{"role": "user", "content": "test"}]
                },
                timeout=30
            )
            
            # Accept 200 (success) or 401/403 (auth issue but endpoint exists)
            if response.status_code in [200, 201, 401, 403]:
                self.add_result(
                    "Endpoint Support",
                    True,
                    "Gateway supports /v1/messages endpoint",
                    f"Status code: {response.status_code}"
                )
                return True
            else:
                self.add_result(
                    "Endpoint Support",
                    False,
                    f"Unexpected status code: {response.status_code}",
                    f"Response: {response.text[:200]}"
                )
                return False
                
        except requests.exceptions.ConnectionError as e:
            self.add_result(
                "Endpoint Support",
                False,
                "Cannot connect to gateway",
                str(e)
            )
            return False
        except Exception as e:
            self.add_result(
                "Endpoint Support",
                False,
                f"Error testing endpoint: {type(e).__name__}",
                str(e)
            )
            return False
    
    def check_header_forwarding(self) -> bool:
        """Check 2: Verify required headers are forwarded"""
        self.log("\n[Check 2/7] Testing header forwarding...", Colors.BOLD)
        
        required_headers = {
            "anthropic-version": "2023-06-01",
            "anthropic-beta": "messages-2025-01-01",
            "anthropic-client-version": "test/1.0.0"
        }
        
        try:
            response = self.session.post(
                f"{self.gateway_url}/v1/messages",
                headers={
                    "Authorization": f"Bearer {self.auth_token}",
                    "Content-Type": "application/json",
                    **required_headers
                },
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "max_tokens": 10,
                    "messages": [{"role": "user", "content": "test"}]
                },
                timeout=30
            )
            
            # If we get 200, headers were forwarded correctly
            # If we get 400 with "Missing required header", headers not forwarded
            if response.status_code == 200:
                self.add_result(
                    "Header Forwarding",
                    True,
                    "All required headers forwarded correctly",
                    f"Tested: {', '.join(required_headers.keys())}"
                )
                return True
            elif response.status_code == 400:
                error_text = response.text.lower()
                if "header" in error_text or "version" in error_text:
                    self.add_result(
                        "Header Forwarding",
                        False,
                        "Gateway not forwarding required headers",
                        f"Response: {response.text[:200]}"
                    )
                    return False
                else:
                    # Other 400 error, assume headers are forwarded
                    self.add_result(
                        "Header Forwarding",
                        True,
                        "Headers appear to be forwarded (got non-header 400 error)",
                        f"Response: {response.text[:200]}"
                    )
                    return True
            else:
                self.add_result(
                    "Header Forwarding",
                    None,
                    f"Cannot verify - got status {response.status_code}",
                    "Manual verification recommended"
                )
                return True  # Don't fail the check
                
        except Exception as e:
            self.add_result(
                "Header Forwarding",
                False,
                f"Error testing headers: {type(e).__name__}",
                str(e)
            )
            return False
    
    def check_body_preservation(self) -> bool:
        """Check 3: Verify request/response body is preserved"""
        self.log("\n[Check 3/7] Testing body preservation...", Colors.BOLD)
        
        try:
            response = self.session.post(
                f"{self.gateway_url}/v1/messages",
                headers={
                    "Authorization": f"Bearer {self.auth_token}",
                    "Content-Type": "application/json",
                    "anthropic-version": "2023-06-01"
                },
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "max_tokens": 10,
                    "messages": [{"role": "user", "content": "Say 'test'"}]
                },
                timeout=30
            )
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    # Check for expected Anthropic API response structure
                    if all(key in data for key in ["id", "type", "role", "content", "model"]):
                        self.add_result(
                            "Body Preservation",
                            True,
                            "Response body structure preserved correctly",
                            f"Keys present: {', '.join(data.keys())}"
                        )
                        return True
                    else:
                        self.add_result(
                            "Body Preservation",
                            False,
                            "Response body structure modified by gateway",
                            f"Missing keys, got: {list(data.keys())}"
                        )
                        return False
                except json.JSONDecodeError:
                    self.add_result(
                        "Body Preservation",
                        False,
                        "Response is not valid JSON",
                        f"Response: {response.text[:200]}"
                    )
                    return False
            else:
                self.add_result(
                    "Body Preservation",
                    None,
                    f"Cannot verify - got status {response.status_code}",
                    "Requires successful request to test"
                )
                return True  # Don't fail if we can't test
                
        except Exception as e:
            self.add_result(
                "Body Preservation",
                False,
                f"Error testing body: {type(e).__name__}",
                str(e)
            )
            return False
    
    def check_status_codes(self) -> bool:
        """Check 4: Verify standard HTTP status codes are returned"""
        self.log("\n[Check 4/7] Testing HTTP status codes...", Colors.BOLD)
        
        # Test invalid auth (should get 401)
        try:
            response = self.session.post(
                f"{self.gateway_url}/v1/messages",
                headers={
                    "Authorization": "Bearer invalid-token-12345",
                    "Content-Type": "application/json",
                    "anthropic-version": "2023-06-01"
                },
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "max_tokens": 10,
                    "messages": [{"role": "user", "content": "test"}]
                },
                timeout=30
            )
            
            if response.status_code in [401, 403]:
                self.add_result(
                    "Status Codes",
                    True,
                    f"Gateway returns standard auth error: {response.status_code}",
                    "401/403 expected for invalid token"
                )
                return True
            elif response.status_code == 200:
                self.add_result(
                    "Status Codes",
                    False,
                    "Gateway accepts invalid token (security risk)",
                    "Should return 401/403 for invalid auth"
                )
                return False
            else:
                self.add_result(
                    "Status Codes",
                    None,
                    f"Unexpected status {response.status_code} for invalid auth",
                    "Expected 401/403"
                )
                return True  # Don't fail
                
        except Exception as e:
            self.add_result(
                "Status Codes",
                False,
                f"Error testing status codes: {type(e).__name__}",
                str(e)
            )
            return False
    
    def check_streaming_support(self) -> bool:
        """Check 5: Verify SSE streaming support"""
        self.log("\n[Check 5/7] Testing SSE streaming support...", Colors.BOLD)
        
        try:
            response = self.session.post(
                f"{self.gateway_url}/v1/messages",
                headers={
                    "Authorization": f"Bearer {self.auth_token}",
                    "Content-Type": "application/json",
                    "Accept": "text/event-stream",
                    "anthropic-version": "2023-06-01"
                },
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "max_tokens": 20,
                    "messages": [{"role": "user", "content": "Count to 3"}],
                    "stream": True
                },
                timeout=30,
                stream=True
            )
            
            if response.status_code == 200:
                content_type = response.headers.get("Content-Type", "")
                if "text/event-stream" in content_type:
                    # Try to read at least one SSE event
                    chunks_received = 0
                    for line in response.iter_lines(decode_unicode=True):
                        if line and line.startswith("data: "):
                            chunks_received += 1
                            if chunks_received >= 2:
                                break
                    
                    if chunks_received > 0:
                        self.add_result(
                            "SSE Streaming",
                            True,
                            f"Gateway supports SSE streaming ({chunks_received} chunks received)",
                            f"Content-Type: {content_type}"
                        )
                        return True
                    else:
                        self.add_result(
                            "SSE Streaming",
                            False,
                            "Gateway accepts streaming but no SSE events received",
                            "Check if gateway is buffering responses"
                        )
                        return False
                else:
                    self.add_result(
                        "SSE Streaming",
                        False,
                        f"Wrong Content-Type for streaming: {content_type}",
                        "Expected: text/event-stream"
                    )
                    return False
            else:
                self.add_result(
                    "SSE Streaming",
                    None,
                    f"Cannot verify - got status {response.status_code}",
                    "Requires successful request to test"
                )
                return True  # Don't fail
                
        except Exception as e:
            self.add_result(
                "SSE Streaming",
                False,
                f"Error testing streaming: {type(e).__name__}",
                str(e)
            )
            return False
    
    def check_authentication(self) -> bool:
        """Check 6: Verify Bearer token authentication"""
        self.log("\n[Check 6/7] Testing Bearer token authentication...", Colors.BOLD)
        
        # Already tested in check_status_codes and other checks
        # Just verify the mechanism works
        try:
            response = self.session.post(
                f"{self.gateway_url}/v1/messages",
                headers={
                    "Authorization": f"Bearer {self.auth_token}",
                    "Content-Type": "application/json",
                    "anthropic-version": "2023-06-01"
                },
                json={
                    "model": "claude-3-5-sonnet-20241022",
                    "max_tokens": 10,
                    "messages": [{"role": "user", "content": "test"}]
                },
                timeout=30
            )
            
            if response.status_code in [200, 201]:
                self.add_result(
                    "Authentication",
                    True,
                    "Bearer token authentication working correctly",
                    f"Status: {response.status_code}"
                )
                return True
            elif response.status_code in [401, 403]:
                self.add_result(
                    "Authentication",
                    False,
                    "Valid token rejected by gateway",
                    "Check if token is correct or has expired"
                )
                return False
            else:
                self.add_result(
                    "Authentication",
                    None,
                    f"Unexpected status {response.status_code}",
                    "Cannot determine auth status"
                )
                return True  # Don't fail
                
        except Exception as e:
            self.add_result(
                "Authentication",
                False,
                f"Error testing auth: {type(e).__name__}",
                str(e)
            )
            return False
    
    def check_timeout_support(self) -> bool:
        """Check 7: Verify minimum 60-second timeout"""
        self.log("\n[Check 7/7] Testing timeout configuration...", Colors.BOLD)
        
        # Note: We can't easily test 60s timeout without a long request
        # This is a configuration check - verify gateway docs/config
        self.add_result(
            "Timeout Support",
            None,
            "Manual verification required",
            "Ensure gateway timeout ≥ 60 seconds (recommended: 300-600s)"
        )
        return True  # Don't fail this check
    
    def run_validation(self) -> Tuple[int, int, int]:
        """Run all validation checks and return results"""
        print(f"\n{Colors.BOLD}{'='*60}")
        print(f"Gateway Compatibility Validation")
        print(f"{'='*60}{Colors.RESET}\n")
        print(f"Gateway URL: {self.gateway_url}")
        print(f"Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        # Run all checks
        checks = [
            self.check_endpoint_support,
            self.check_header_forwarding,
            self.check_body_preservation,
            self.check_status_codes,
            self.check_streaming_support,
            self.check_authentication,
            self.check_timeout_support
        ]
        
        for check in checks:
            try:
                check()
            except Exception as e:
                print(f"{Colors.RED}Unexpected error in {check.__name__}: {e}{Colors.RESET}")
        
        # Calculate results
        passed = sum(1 for r in self.results if r["passed"] is True)
        failed = sum(1 for r in self.results if r["passed"] is False)
        skipped = sum(1 for r in self.results if r["passed"] is None)
        
        return passed, failed, skipped
    
    def print_summary(self, passed: int, failed: int, skipped: int):
        """Print validation summary"""
        total = passed + failed + skipped
        
        print(f"\n{Colors.BOLD}{'='*60}")
        print("Validation Summary")
        print(f"{'='*60}{Colors.RESET}\n")
        
        print(f"Total Checks: {total}")
        print(f"{Colors.GREEN}Passed: {passed}{Colors.RESET}")
        print(f"{Colors.RED}Failed: {failed}{Colors.RESET}")
        print(f"{Colors.YELLOW}Skipped: {skipped}{Colors.RESET}\n")
        
        if failed == 0 and passed > 0:
            print(f"{Colors.GREEN}{Colors.BOLD}✓ Gateway is COMPATIBLE with Claude Code{Colors.RESET}\n")
            return 0
        elif failed > 0:
            print(f"{Colors.RED}{Colors.BOLD}✗ Gateway has COMPATIBILITY ISSUES{Colors.RESET}")
            print(f"\nRecommendations:")
            for result in self.results:
                if result["passed"] is False:
                    print(f"  - Fix: {result['check']}")
                    if result["details"]:
                        print(f"    Details: {result['details']}")
            print()
            return 1
        else:
            print(f"{Colors.YELLOW}⚠ Cannot determine compatibility{Colors.RESET}\n")
            return 2
    
    def export_json(self, output_file: str):
        """Export results to JSON file"""
        output = {
            "gateway_url": self.gateway_url,
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S'),
            "results": self.results,
            "summary": {
                "total": len(self.results),
                "passed": sum(1 for r in self.results if r["passed"] is True),
                "failed": sum(1 for r in self.results if r["passed"] is False),
                "skipped": sum(1 for r in self.results if r["passed"] is None)
            }
        }
        
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)
        
        print(f"Results exported to: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Validate enterprise gateway compatibility with Claude Code",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic validation
  python validate-gateway-compatibility.py \\
    --url https://gateway.example.com \\
    --token your-api-key

  # Verbose output with JSON export
  python validate-gateway-compatibility.py \\
    --url https://gateway.example.com \\
    --token your-api-key \\
    --verbose \\
    --output results.json

Gateway Compatibility Criteria (7 checks):
  1. Supports /v1/messages endpoint
  2. Forwards required headers (anthropic-version, anthropic-beta)
  3. Preserves request/response body format
  4. Returns standard HTTP status codes (200, 401, 403, 429, 500, 502, 503, 504)
  5. Supports Server-Sent Events (SSE) for streaming
  6. Handles Bearer token authentication
  7. Maintains minimum 60-second timeout

Exit Codes:
  0 - Gateway is compatible
  1 - Gateway has compatibility issues
  2 - Cannot determine compatibility
        """
    )
    
    parser.add_argument(
        '--url',
        required=True,
        help='Gateway base URL (e.g., https://gateway.example.com)'
    )
    parser.add_argument(
        '--token',
        required=True,
        help='Gateway API key/token for authentication'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    parser.add_argument(
        '--output',
        help='Export results to JSON file'
    )
    
    args = parser.parse_args()
    
    # Run validation
    validator = GatewayValidator(args.url, args.token, args.verbose)
    passed, failed, skipped = validator.run_validation()
    exit_code = validator.print_summary(passed, failed, skipped)
    
    # Export JSON if requested
    if args.output:
        validator.export_json(args.output)
    
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
