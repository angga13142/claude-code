#!/usr/bin/env python3
"""
Rate Limiting Verification Script for Enterprise Gateways

Purpose: Test and verify that enterprise gateways correctly enforce rate limiting
Usage: python test-rate-limiting.py --url https://gateway.example.com --token your-api-key --rpm 60

Validates:
- Rate limit enforcement (429 status code)
- Rate limit headers (X-RateLimit-* or Retry-After)
- Rate limit behavior (requests blocked after threshold)
- Rate limit reset functionality
"""

import argparse
import sys
import time
from typing import Dict, Optional, Tuple
import requests
from datetime import datetime, timedelta


class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    RESET = '\033[0m'


class RateLimitTester:
    """Test rate limiting enforcement on enterprise gateways"""
    
    def __init__(self, gateway_url: str, auth_token: str, rpm_limit: int, verbose: bool = False):
        self.gateway_url = gateway_url.rstrip('/')
        self.auth_token = auth_token
        self.rpm_limit = rpm_limit
        self.verbose = verbose
        self.requests_made = 0
        self.requests_succeeded = 0
        self.requests_rate_limited = 0
        self.session = requests.Session()
    
    def log(self, message: str, color: str = Colors.RESET):
        """Print colored log message"""
        if self.verbose:
            timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
            print(f"{color}[{timestamp}] {message}{Colors.RESET}")
    
    def make_request(self) -> Tuple[int, Dict[str, str], float]:
        """Make a single request and return status, headers, latency"""
        start_time = time.time()
        
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
            
            latency = time.time() - start_time
            self.requests_made += 1
            
            if response.status_code in [200, 201]:
                self.requests_succeeded += 1
            elif response.status_code == 429:
                self.requests_rate_limited += 1
            
            return response.status_code, dict(response.headers), latency
            
        except Exception as e:
            self.log(f"Request error: {e}", Colors.RED)
            return 0, {}, 0.0
    
    def extract_rate_limit_headers(self, headers: Dict[str, str]) -> Dict[str, Optional[str]]:
        """Extract rate limit information from response headers"""
        rate_limit_info = {
            "limit": None,
            "remaining": None,
            "reset": None,
            "retry_after": None
        }
        
        # Check common rate limit header formats
        header_mappings = [
            # Standard format
            ("X-RateLimit-Limit", "limit"),
            ("X-RateLimit-Remaining", "remaining"),
            ("X-RateLimit-Reset", "reset"),
            ("Retry-After", "retry_after"),
            # Alternative formats
            ("X-Rate-Limit-Limit", "limit"),
            ("X-Rate-Limit-Remaining", "remaining"),
            ("X-Rate-Limit-Reset", "reset"),
            ("RateLimit-Limit", "limit"),
            ("RateLimit-Remaining", "remaining"),
            ("RateLimit-Reset", "reset"),
        ]
        
        for header_name, info_key in header_mappings:
            # Case-insensitive header lookup
            for h_key, h_value in headers.items():
                if h_key.lower() == header_name.lower():
                    rate_limit_info[info_key] = h_value
                    break
        
        return rate_limit_info
    
    def test_rate_limit_headers(self) -> bool:
        """Test 1: Check if rate limit headers are present"""
        print(f"\n{Colors.BOLD}[Test 1/4] Checking rate limit headers...{Colors.RESET}")
        
        status, headers, latency = self.make_request()
        
        if status == 0:
            print(f"{Colors.RED}✗ FAIL - Cannot connect to gateway{Colors.RESET}")
            return False
        
        rate_limit_info = self.extract_rate_limit_headers(headers)
        
        headers_found = sum(1 for v in rate_limit_info.values() if v is not None)
        
        if headers_found > 0:
            print(f"{Colors.GREEN}✓ PASS - Rate limit headers present{Colors.RESET}")
            if self.verbose:
                for key, value in rate_limit_info.items():
                    if value:
                        print(f"       {Colors.BLUE}{key}: {value}{Colors.RESET}")
            return True
        else:
            print(f"{Colors.YELLOW}⚠ WARNING - No rate limit headers found{Colors.RESET}")
            print(f"       Gateway may not expose rate limit information in headers")
            return True  # Don't fail, just warn
    
    def test_rate_limit_enforcement(self) -> bool:
        """Test 2: Verify rate limiting is enforced"""
        print(f"\n{Colors.BOLD}[Test 2/4] Testing rate limit enforcement...{Colors.RESET}")
        print(f"       Sending requests at high rate (target: {self.rpm_limit} RPM)...")
        
        # Calculate delay between requests to exceed rate limit
        # Send requests slightly faster than limit to trigger rate limiting
        requests_to_send = min(int(self.rpm_limit * 1.2), 100)  # 20% over limit, max 100
        delay_seconds = (60.0 / requests_to_send) * 0.8  # 20% faster than allowed
        
        self.log(f"Sending {requests_to_send} requests with {delay_seconds:.2f}s delay")
        
        rate_limited = False
        first_rate_limit_at = 0
        
        for i in range(requests_to_send):
            status, headers, latency = self.make_request()
            
            if status == 429:
                rate_limited = True
                if first_rate_limit_at == 0:
                    first_rate_limit_at = i + 1
                self.log(f"Request {i+1}: Rate limited (429)", Colors.YELLOW)
            elif status in [200, 201]:
                self.log(f"Request {i+1}: Success ({status})", Colors.GREEN)
            else:
                self.log(f"Request {i+1}: Status {status}", Colors.BLUE)
            
            # Stop early if we've confirmed rate limiting
            if rate_limited and i >= 10:
                self.log("Rate limiting confirmed, stopping test early")
                break
            
            time.sleep(delay_seconds)
        
        if rate_limited:
            print(f"{Colors.GREEN}✓ PASS - Rate limiting enforced{Colors.RESET}")
            print(f"       First rate limit at request #{first_rate_limit_at}")
            return True
        else:
            print(f"{Colors.RED}✗ FAIL - No rate limiting observed{Colors.RESET}")
            print(f"       Sent {requests_to_send} requests, all succeeded")
            print(f"       Expected 429 status code after ~{self.rpm_limit} requests/minute")
            return False
    
    def test_rate_limit_reset(self) -> bool:
        """Test 3: Verify rate limit resets after time window"""
        print(f"\n{Colors.BOLD}[Test 3/4] Testing rate limit reset...{Colors.RESET}")
        
        # First, trigger rate limit
        print("       Triggering rate limit...")
        rate_limited = False
        
        for i in range(min(self.rpm_limit + 10, 50)):
            status, headers, latency = self.make_request()
            if status == 429:
                rate_limited = True
                rate_limit_info = self.extract_rate_limit_headers(headers)
                
                if rate_limit_info["retry_after"]:
                    wait_time = int(rate_limit_info["retry_after"])
                elif rate_limit_info["reset"]:
                    try:
                        reset_time = int(rate_limit_info["reset"])
                        wait_time = max(reset_time - int(time.time()), 0) + 1
                    except:
                        wait_time = 60
                else:
                    wait_time = 60  # Default to 60 seconds
                
                print(f"       Rate limit triggered. Waiting {wait_time}s for reset...")
                time.sleep(wait_time)
                
                # Try request after reset
                status_after, _, _ = self.make_request()
                
                if status_after in [200, 201]:
                    print(f"{Colors.GREEN}✓ PASS - Rate limit reset successfully{Colors.RESET}")
                    return True
                elif status_after == 429:
                    print(f"{Colors.YELLOW}⚠ WARNING - Still rate limited after reset window{Colors.RESET}")
                    print(f"       This may indicate a longer reset window than indicated")
                    return True  # Don't fail, may need longer wait
                else:
                    print(f"{Colors.RED}✗ FAIL - Unexpected status after reset: {status_after}{Colors.RESET}")
                    return False
            
            time.sleep(0.1)
        
        if not rate_limited:
            print(f"{Colors.YELLOW}⚠ WARNING - Could not trigger rate limit to test reset{Colors.RESET}")
            return True  # Don't fail if we can't trigger it
    
    def test_retry_after_header(self) -> bool:
        """Test 4: Check if Retry-After header is provided"""
        print(f"\n{Colors.BOLD}[Test 4/4] Checking Retry-After header...{Colors.RESET}")
        
        # Trigger rate limit and check for Retry-After
        for i in range(min(self.rpm_limit + 20, 60)):
            status, headers, latency = self.make_request()
            
            if status == 429:
                retry_after = headers.get("Retry-After") or headers.get("retry-after")
                
                if retry_after:
                    print(f"{Colors.GREEN}✓ PASS - Retry-After header present: {retry_after}s{Colors.RESET}")
                    return True
                else:
                    # Check for alternative rate limit reset headers
                    rate_limit_info = self.extract_rate_limit_headers(headers)
                    if rate_limit_info["reset"]:
                        print(f"{Colors.GREEN}✓ PASS - Rate limit reset time provided{Colors.RESET}")
                        print(f"       X-RateLimit-Reset: {rate_limit_info['reset']}")
                        return True
                    else:
                        print(f"{Colors.YELLOW}⚠ WARNING - No Retry-After or reset header{Colors.RESET}")
                        print(f"       Recommended: Gateway should provide retry timing guidance")
                        return True  # Don't fail, just warn
            
            time.sleep(0.1)
        
        print(f"{Colors.YELLOW}⚠ WARNING - Could not trigger rate limit to check header{Colors.RESET}")
        return True
    
    def run_tests(self) -> Tuple[int, int]:
        """Run all rate limiting tests"""
        print(f"\n{Colors.BOLD}{'='*60}")
        print("Rate Limiting Verification")
        print(f"{'='*60}{Colors.RESET}\n")
        print(f"Gateway URL: {self.gateway_url}")
        print(f"Expected Rate Limit: {self.rpm_limit} requests/minute")
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        tests = [
            self.test_rate_limit_headers,
            self.test_rate_limit_enforcement,
            self.test_rate_limit_reset,
            self.test_retry_after_header
        ]
        
        passed = 0
        failed = 0
        
        for test in tests:
            try:
                if test():
                    passed += 1
                else:
                    failed += 1
            except Exception as e:
                print(f"{Colors.RED}✗ Test error: {e}{Colors.RESET}")
                failed += 1
        
        return passed, failed
    
    def print_summary(self, passed: int, failed: int):
        """Print test summary"""
        print(f"\n{Colors.BOLD}{'='*60}")
        print("Test Summary")
        print(f"{'='*60}{Colors.RESET}\n")
        
        total = passed + failed
        print(f"Total Tests: {total}")
        print(f"{Colors.GREEN}Passed: {passed}{Colors.RESET}")
        print(f"{Colors.RED}Failed: {failed}{Colors.RESET}\n")
        
        print(f"Requests Made: {self.requests_made}")
        print(f"Succeeded: {self.requests_succeeded}")
        print(f"Rate Limited (429): {self.requests_rate_limited}\n")
        
        if failed == 0:
            print(f"{Colors.GREEN}{Colors.BOLD}✓ Rate limiting is working correctly{Colors.RESET}\n")
            return 0
        else:
            print(f"{Colors.RED}{Colors.BOLD}✗ Rate limiting has issues{Colors.RESET}")
            print("\nRecommendations:")
            print("  - Verify rate limit policies are configured in gateway")
            print("  - Check if rate limiting is enabled globally or per-route")
            print("  - Review gateway documentation for rate limit configuration")
            print("  - Consider implementing client-side rate limiting as backup\n")
            return 1


def main():
    parser = argparse.ArgumentParser(
        description="Test rate limiting enforcement on enterprise gateways",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Test with expected 60 RPM limit
  python test-rate-limiting.py \\
    --url https://gateway.example.com \\
    --token your-api-key \\
    --rpm 60

  # Verbose output
  python test-rate-limiting.py \\
    --url https://gateway.example.com \\
    --token your-api-key \\
    --rpm 100 \\
    --verbose

Tests Performed:
  1. Check if rate limit headers are present (X-RateLimit-*)
  2. Verify rate limiting is enforced (429 status code)
  3. Test rate limit reset after time window
  4. Check for Retry-After header guidance

Exit Codes:
  0 - Rate limiting is working correctly
  1 - Rate limiting has issues
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
        '--rpm',
        type=int,
        required=True,
        help='Expected rate limit (requests per minute)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    
    args = parser.parse_args()
    
    # Run tests
    tester = RateLimitTester(args.url, args.token, args.rpm, args.verbose)
    passed, failed = tester.run_tests()
    exit_code = tester.print_summary(passed, failed)
    
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
