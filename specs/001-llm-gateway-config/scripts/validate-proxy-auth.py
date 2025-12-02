#!/usr/bin/env python3
"""
validate-proxy-auth.py
Purpose: Validate corporate proxy authentication configuration
Usage: python3 validate-proxy-auth.py [--proxy URL] [--test-auth]
"""

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple
from urllib.parse import urlparse, unquote

# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_header(text: str) -> None:
    """Print colored header."""
    print(f"\n{Colors.BLUE}{'='*50}{Colors.NC}")
    print(f"{Colors.BLUE}{text:^50}{Colors.NC}")
    print(f"{Colors.BLUE}{'='*50}{Colors.NC}\n")

def print_success(text: str) -> None:
    """Print success message."""
    print(f"{Colors.GREEN}✓ {text}{Colors.NC}")

def print_error(text: str) -> None:
    """Print error message."""
    print(f"{Colors.RED}✗ {text}{Colors.NC}")

def print_warning(text: str) -> None:
    """Print warning message."""
    print(f"{Colors.YELLOW}⚠ {text}{Colors.NC}")

def print_info(text: str) -> None:
    """Print info message."""
    print(f"{Colors.BLUE}→ {text}{Colors.NC}")

def parse_proxy_url(proxy_url: str) -> Dict[str, str]:
    """
    Parse proxy URL and extract components.
    
    Args:
        proxy_url: Proxy URL (e.g., http://user:pass@proxy:8080)
    
    Returns:
        Dict with scheme, username, password, hostname, port
    """
    parsed = urlparse(proxy_url)
    return {
        'scheme': parsed.scheme,
        'username': unquote(parsed.username) if parsed.username else None,
        'password': unquote(parsed.password) if parsed.password else None,
        'hostname': parsed.hostname,
        'port': parsed.port or 8080,
        'has_credentials': bool(parsed.username and parsed.password)
    }

def validate_proxy_url_format(proxy_url: str) -> Tuple[bool, List[str]]:
    """
    Validate proxy URL format.
    
    Returns:
        (is_valid, list_of_issues)
    """
    issues = []
    
    # Check basic URL format
    if not re.match(r'^https?://', proxy_url):
        issues.append("Proxy URL must start with http:// or https://")
        return False, issues
    
    parsed = parse_proxy_url(proxy_url)
    
    # Check hostname
    if not parsed['hostname']:
        issues.append("Missing proxy hostname")
    
    # Check port
    if parsed['port'] < 1 or parsed['port'] > 65535:
        issues.append(f"Invalid port number: {parsed['port']} (must be 1-65535)")
    
    # Warn about credentials in URL
    if parsed['has_credentials']:
        issues.append("WARNING: Credentials in proxy URL (visible in process list)")
    
    return len(issues) == 0 or parsed['has_credentials'], issues

def check_special_characters(username: str, password: str) -> List[str]:
    """Check if credentials contain special characters that need URL encoding."""
    issues = []
    special_chars = ['@', ':', '/', '?', '#', '&', '=', '+', '%', ' ']
    
    if username:
        found = [char for char in special_chars if char in username]
        if found:
            issues.append(f"Username contains special characters: {', '.join(found)}")
            issues.append("  → Must be URL-encoded (e.g., @ becomes %40)")
    
    if password:
        found = [char for char in special_chars if char in password]
        if found:
            issues.append(f"Password contains special characters: {', '.join(found)}")
            issues.append("  → Must be URL-encoded (e.g., @ becomes %40)")
    
    return issues

def check_netrc_file() -> Tuple[bool, List[str]]:
    """Check .netrc file for proxy authentication."""
    issues = []
    netrc_path = Path.home() / '.netrc'
    
    if not netrc_path.exists():
        return False, ["~/.netrc file not found"]
    
    # Check permissions (should be 600)
    stat_info = netrc_path.stat()
    permissions = oct(stat_info.st_mode)[-3:]
    
    if permissions != '600':
        issues.append(f".netrc has incorrect permissions: {permissions} (should be 600)")
        issues.append("  → Fix with: chmod 600 ~/.netrc")
    
    # Try to parse .netrc
    try:
        with open(netrc_path, 'r') as f:
            content = f.read()
            
        # Check for proxy entry
        if 'machine' not in content:
            issues.append(".netrc file has no 'machine' entries")
        
        # Look for common proxy hostnames
        proxy_keywords = ['proxy', 'corp', 'internal']
        has_proxy_entry = any(keyword in content.lower() for keyword in proxy_keywords)
        
        if not has_proxy_entry:
            issues.append("No proxy-related entries found in .netrc")
            issues.append("  → Expected format:")
            issues.append("    machine proxy.company.com")
            issues.append("    login username")
            issues.append("    password yourpassword")
    
    except PermissionError:
        issues.append("Cannot read .netrc file (permission denied)")
    
    return len(issues) == 0, issues

def check_environment_variables() -> Dict[str, str]:
    """Check proxy-related environment variables."""
    vars_to_check = [
        'HTTPS_PROXY', 'HTTP_PROXY', 'https_proxy', 'http_proxy',
        'NO_PROXY', 'no_proxy', 'ALL_PROXY', 'all_proxy'
    ]
    
    found_vars = {}
    for var in vars_to_check:
        value = os.environ.get(var)
        if value:
            # Mask credentials in output
            if '@' in value:
                masked = re.sub(r'(https?://)[^:]+:[^@]+@', r'\1***:***@', value)
                found_vars[var] = masked
            else:
                found_vars[var] = value
    
    return found_vars

def validate_authentication_method() -> Tuple[str, List[str]]:
    """
    Detect and validate authentication method.
    
    Returns:
        (method, list_of_findings)
    """
    findings = []
    
    # Check environment variables
    proxy_url = os.environ.get('HTTPS_PROXY') or os.environ.get('HTTP_PROXY')
    
    if proxy_url:
        parsed = parse_proxy_url(proxy_url)
        
        if parsed['has_credentials']:
            findings.append("Authentication method: Inline credentials")
            findings.append("  Security level: LOW (credentials visible in process list)")
            findings.append("  Recommended for: Development/testing only")
            
            # Check for special characters
            special_char_issues = check_special_characters(
                parsed['username'], parsed['password']
            )
            if special_char_issues:
                findings.extend(special_char_issues)
            
            return "inline", findings
    
    # Check .netrc
    netrc_exists, netrc_issues = check_netrc_file()
    if netrc_exists:
        findings.append("Authentication method: .netrc file")
        findings.append("  Security level: MEDIUM (plaintext file)")
        findings.append("  Recommended for: Single-user workstations")
        
        if netrc_issues:
            findings.extend(netrc_issues)
        
        return "netrc", findings
    
    # Check for potential secret manager usage
    secret_vars = [v for v in os.environ.keys() if 'SECRET' in v or 'VAULT' in v]
    if secret_vars:
        findings.append("Authentication method: Potentially using secret manager")
        findings.append(f"  Found variables: {', '.join(secret_vars[:3])}")
        findings.append("  Security level: HIGH")
        findings.append("  Recommended for: Production environments")
        return "secret_manager", findings
    
    # No authentication detected
    findings.append("Authentication method: None detected or not required")
    findings.append("  → If proxy requires auth, configure credentials")
    return "none", findings

def test_proxy_authentication() -> bool:
    """Test if proxy authentication works."""
    try:
        import requests
        
        proxy_url = os.environ.get('HTTPS_PROXY') or os.environ.get('HTTP_PROXY')
        if not proxy_url:
            print_error("No proxy configured for testing")
            return False
        
        print_info("Testing proxy authentication with HTTP request...")
        
        proxies = {
            'http': proxy_url,
            'https': proxy_url
        }
        
        try:
            response = requests.get(
                'http://example.com',
                proxies=proxies,
                timeout=10
            )
            
            if response.status_code in (200, 301, 302):
                print_success(f"Proxy authentication successful (HTTP {response.status_code})")
                return True
            elif response.status_code == 407:
                print_error("Proxy authentication required (407)")
                print_warning("  → Add credentials to proxy URL or configure .netrc")
                return False
            else:
                print_warning(f"Unexpected status code: {response.status_code}")
                return False
                
        except requests.exceptions.ProxyError as e:
            print_error(f"Proxy error: {e}")
            return False
        except requests.exceptions.Timeout:
            print_error("Request timeout (proxy may be slow or unreachable)")
            return False
        except Exception as e:
            print_error(f"Request failed: {e}")
            return False
            
    except ImportError:
        print_warning("requests library not available (cannot test authentication)")
        print_info("  Install with: pip install requests")
        return None

def generate_recommendations(auth_method: str, issues: List[str]) -> None:
    """Generate recommendations based on detected issues."""
    print_info("Recommendations:")
    
    if auth_method == "inline":
        print("  1. For production, use secret manager or .netrc instead")
        print("  2. Ensure password doesn't contain special characters or URL-encode them")
        print("  3. Never commit proxy credentials to version control")
    
    elif auth_method == "netrc":
        print("  1. Verify .netrc permissions are 600: chmod 600 ~/.netrc")
        print("  2. Ensure proxy hostname matches exactly in .netrc")
        print("  3. Test with: curl --netrc https://api.anthropic.com")
    
    elif auth_method == "secret_manager":
        print("  1. Ensure secret retrieval script runs before application")
        print("  2. Implement credential caching to reduce API calls")
        print("  3. Monitor secret access logs for anomalies")
    
    else:  # none
        print("  1. Check if proxy requires authentication")
        print("  2. Contact IT for proxy credentials")
        print("  3. Configure using one of the supported methods")
    
    if issues:
        print("\n  Issues to fix:")
        for issue in issues:
            if not issue.startswith(' '):
                print(f"    - {issue}")

def main():
    """Main execution."""
    parser = argparse.ArgumentParser(
        description="Validate corporate proxy authentication configuration"
    )
    parser.add_argument(
        '--proxy',
        help="Proxy URL to validate (overrides environment variables)"
    )
    parser.add_argument(
        '--test-auth',
        action='store_true',
        help="Test proxy authentication with actual HTTP request"
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help="Enable verbose output"
    )
    
    args = parser.parse_args()
    
    print_header("Proxy Authentication Validator")
    
    # Check environment variables
    print_info("Checking environment variables...")
    env_vars = check_environment_variables()
    
    if env_vars:
        print_success(f"Found {len(env_vars)} proxy-related environment variable(s):")
        for var, value in env_vars.items():
            print(f"    {var}={value}")
    else:
        print_warning("No proxy environment variables found")
        print("  Set HTTPS_PROXY: export HTTPS_PROXY=\"http://proxy:8080\"")
    
    print()
    
    # Validate proxy URL if provided
    if args.proxy:
        print_info(f"Validating proxy URL: {args.proxy}")
        is_valid, issues = validate_proxy_url_format(args.proxy)
        
        if is_valid:
            print_success("Proxy URL format is valid")
        else:
            print_error("Proxy URL format has issues:")
            for issue in issues:
                print(f"    - {issue}")
        print()
    
    # Detect authentication method
    print_info("Detecting authentication method...")
    auth_method, findings = validate_authentication_method()
    
    for finding in findings:
        if finding.startswith('  '):
            print(finding)
        else:
            print(f"  {finding}")
    
    print()
    
    # Test authentication if requested
    if args.test_auth:
        test_result = test_proxy_authentication()
        print()
        
        if test_result is False:
            sys.exit(3)
    
    # Generate recommendations
    issues = [f for f in findings if 'WARNING' in f or 'ERROR' in f or 'incorrect' in f.lower()]
    if issues or auth_method in ('none', 'inline'):
        print()
        generate_recommendations(auth_method, issues)
    
    # Summary
    print()
    print_header("Summary")
    
    if auth_method == "none":
        print_error("No proxy authentication configured")
        print("\nNext steps:")
        print("  1. Get proxy credentials from IT department")
        print("  2. Choose authentication method (see templates/proxy/proxy-auth.md)")
        print("  3. Configure and re-run this validator")
        sys.exit(1)
    
    elif auth_method == "inline":
        print_warning("Using inline credentials (low security)")
        print("\nProduction-ready: NO")
        print("Acceptable for: Development/testing only")
        sys.exit(0)
    
    elif auth_method == "netrc":
        print_success("Using .netrc file (medium security)")
        print("\nProduction-ready: Limited (single-user systems only)")
        print("Acceptable for: Workstations, development environments")
        sys.exit(0)
    
    else:  # secret_manager
        print_success("Using secret manager (high security)")
        print("\nProduction-ready: YES")
        print("Acceptable for: All environments")
        sys.exit(0)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        if '--verbose' in sys.argv:
            import traceback
            traceback.print_exc()
        sys.exit(1)
