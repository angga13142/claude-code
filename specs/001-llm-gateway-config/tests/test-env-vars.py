#!/usr/bin/env python3
"""
Environment Variable Validation Tests
Tests environment variable parsing, validation, and usage
"""

import os
import sys
import re
from typing import Dict, List, Tuple, Optional


class EnvVarValidator:
    """Validates environment variables for LLM Gateway configuration."""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.passed = 0
        self.failed = 0
        self.warnings = 0
        
    def log(self, message: str, level: str = "INFO"):
        """Log a message."""
        if self.verbose or level in ["ERROR", "WARN"]:
            prefix = {"INFO": "[INFO]", "WARN": "[WARN]", "ERROR": "[ERROR]", "PASS": "[PASS]"}
            print(f"{prefix.get(level, '[INFO]')} {message}")
    
    def validate_api_key_format(self, key: str, provider: str) -> Tuple[bool, Optional[str]]:
        """Validate API key format for different providers."""
        if provider == "anthropic":
            if not key.startswith("sk-ant-"):
                return False, "Anthropic API keys should start with 'sk-ant-'"
            if len(key) < 20:
                return False, "Anthropic API key seems too short"
        elif provider == "aws":
            if not key.startswith("AKIA"):
                return False, "AWS access keys should start with 'AKIA'"
            if len(key) != 20:
                return False, "AWS access keys should be exactly 20 characters"
        
        return True, None
    
    def validate_url_format(self, url: str) -> Tuple[bool, Optional[str]]:
        """Validate URL format."""
        if not url.startswith(("http://", "https://")):
            return False, "URL must start with http:// or https://"
        
        # Check for common issues
        if url.endswith("/"):
            return True, "URL ends with trailing slash (may cause issues)"
        
        return True, None
    
    def validate_proxy_url(self, url: str) -> Tuple[bool, Optional[str]]:
        """Validate proxy URL format."""
        # Check basic URL format
        valid, msg = self.validate_url_format(url)
        if not valid:
            return False, msg
        
        # Check for credentials in URL
        if "@" in url:
            # Extract credentials part
            creds_part = url.split("@")[0].split("//")[1]
            if ":" not in creds_part:
                return False, "Proxy URL with @ must have username:password format"
            
            # Check for unencoded special characters
            username, password = creds_part.split(":", 1)
            special_chars = ["@", ":", "/", "?", "#", "[", "]", "!"]
            for char in special_chars:
                if char in password:
                    return True, f"Password contains '{char}' - ensure it's URL-encoded"
        
        return True, None
    
    def test_anthropic_api_key(self) -> bool:
        """Test ANTHROPIC_API_KEY variable."""
        key = os.getenv("ANTHROPIC_API_KEY")
        
        if not key:
            self.log("ANTHROPIC_API_KEY: Not set (optional if using gateway)", "WARN")
            self.warnings += 1
            return True
        
        valid, error = self.validate_api_key_format(key, "anthropic")
        if not valid:
            self.log(f"ANTHROPIC_API_KEY: {error}", "ERROR")
            self.failed += 1
            return False
        
        self.log(f"ANTHROPIC_API_KEY: Valid format ({key[:10]}...)", "PASS")
        self.passed += 1
        return True
    
    def test_anthropic_base_url(self) -> bool:
        """Test ANTHROPIC_BASE_URL variable."""
        url = os.getenv("ANTHROPIC_BASE_URL")
        
        if not url:
            self.log("ANTHROPIC_BASE_URL: Not set (uses default)", "INFO")
            return True
        
        valid, error = self.validate_url_format(url)
        if not valid:
            self.log(f"ANTHROPIC_BASE_URL: {error}", "ERROR")
            self.failed += 1
            return False
        
        if error:  # Warning
            self.log(f"ANTHROPIC_BASE_URL: {error}", "WARN")
            self.warnings += 1
        
        self.log(f"ANTHROPIC_BASE_URL: {url}", "PASS")
        self.passed += 1
        return True
    
    def test_aws_credentials(self) -> bool:
        """Test AWS credentials."""
        access_key = os.getenv("AWS_ACCESS_KEY_ID")
        secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
        
        if not access_key and not secret_key:
            self.log("AWS credentials: Not set (optional)", "INFO")
            return True
        
        if access_key and not secret_key:
            self.log("AWS_SECRET_ACCESS_KEY: Missing (AWS_ACCESS_KEY_ID is set)", "ERROR")
            self.failed += 1
            return False
        
        if secret_key and not access_key:
            self.log("AWS_ACCESS_KEY_ID: Missing (AWS_SECRET_ACCESS_KEY is set)", "ERROR")
            self.failed += 1
            return False
        
        # Validate access key format
        valid, error = self.validate_api_key_format(access_key, "aws")
        if not valid:
            self.log(f"AWS_ACCESS_KEY_ID: {error}", "ERROR")
            self.failed += 1
            return False
        
        self.log(f"AWS credentials: Valid ({access_key[:10]}...)", "PASS")
        self.passed += 1
        return True
    
    def test_vertex_ai_config(self) -> bool:
        """Test Vertex AI configuration."""
        project_id = os.getenv("VERTEX_PROJECT_ID")
        location = os.getenv("VERTEX_LOCATION")
        
        if not project_id:
            self.log("VERTEX_PROJECT_ID: Not set (optional)", "INFO")
            return True
        
        # Validate project ID format (lowercase, numbers, hyphens)
        if not re.match(r'^[a-z0-9-]+$', project_id):
            self.log("VERTEX_PROJECT_ID: Invalid format (should be lowercase, numbers, hyphens)", "ERROR")
            self.failed += 1
            return False
        
        if not location:
            self.log("VERTEX_LOCATION: Not set (will use default us-central1)", "WARN")
            self.warnings += 1
        
        self.log(f"VERTEX_PROJECT_ID: {project_id}", "PASS")
        self.passed += 1
        return True
    
    def test_proxy_config(self) -> bool:
        """Test proxy configuration."""
        https_proxy = os.getenv("HTTPS_PROXY") or os.getenv("https_proxy")
        no_proxy = os.getenv("NO_PROXY") or os.getenv("no_proxy")
        
        if not https_proxy:
            self.log("HTTPS_PROXY: Not set (no proxy configured)", "INFO")
            return True
        
        valid, error = self.validate_proxy_url(https_proxy)
        if not valid:
            self.log(f"HTTPS_PROXY: {error}", "ERROR")
            self.failed += 1
            return False
        
        if error:  # Warning
            self.log(f"HTTPS_PROXY: {error}", "WARN")
            self.warnings += 1
        
        # Check NO_PROXY
        if not no_proxy:
            self.log("NO_PROXY: Not set (may affect localhost connections)", "WARN")
            self.warnings += 1
        else:
            # Check for localhost
            if "localhost" not in no_proxy and "127.0.0.1" not in no_proxy:
                self.log("NO_PROXY: Missing localhost/127.0.0.1", "WARN")
                self.warnings += 1
        
        self.log("HTTPS_PROXY: Valid format", "PASS")
        self.passed += 1
        return True
    
    def test_ssl_cert_config(self) -> bool:
        """Test SSL certificate configuration."""
        cert_file = os.getenv("SSL_CERT_FILE")
        
        if not cert_file:
            self.log("SSL_CERT_FILE: Not set (using system defaults)", "INFO")
            return True
        
        # Check if file exists
        if not os.path.exists(cert_file):
            self.log(f"SSL_CERT_FILE: File not found: {cert_file}", "ERROR")
            self.failed += 1
            return False
        
        self.log(f"SSL_CERT_FILE: {cert_file}", "PASS")
        self.passed += 1
        return True
    
    def test_auth_bypass_flags(self) -> bool:
        """Test authentication bypass flags."""
        bedrock_skip = os.getenv("CLAUDE_CODE_SKIP_BEDROCK_AUTH")
        vertex_skip = os.getenv("CLAUDE_CODE_SKIP_VERTEX_AUTH")
        
        if bedrock_skip:
            if bedrock_skip.lower() not in ["true", "false", "1", "0"]:
                self.log("CLAUDE_CODE_SKIP_BEDROCK_AUTH: Invalid value (use 'true' or 'false')", "WARN")
                self.warnings += 1
            else:
                self.log(f"CLAUDE_CODE_SKIP_BEDROCK_AUTH: {bedrock_skip}", "INFO")
        
        if vertex_skip:
            if vertex_skip.lower() not in ["true", "false", "1", "0"]:
                self.log("CLAUDE_CODE_SKIP_VERTEX_AUTH: Invalid value (use 'true' or 'false')", "WARN")
                self.warnings += 1
            else:
                self.log(f"CLAUDE_CODE_SKIP_VERTEX_AUTH: {vertex_skip}", "INFO")
        
        return True
    
    def run_all_tests(self) -> bool:
        """Run all environment variable tests."""
        print("=" * 60)
        print("Environment Variable Validation Tests")
        print("=" * 60)
        print()
        
        # Run tests
        self.test_anthropic_api_key()
        self.test_anthropic_base_url()
        self.test_aws_credentials()
        self.test_vertex_ai_config()
        self.test_proxy_config()
        self.test_ssl_cert_config()
        self.test_auth_bypass_flags()
        
        # Summary
        print()
        print("=" * 60)
        print("Summary")
        print("=" * 60)
        print(f"Passed:   {self.passed}")
        print(f"Failed:   {self.failed}")
        print(f"Warnings: {self.warnings}")
        print()
        
        if self.failed == 0:
            print("✓ All environment variable tests passed")
            return True
        else:
            print("✗ Some environment variable tests failed")
            return False


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Validate environment variables for LLM Gateway",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    
    args = parser.parse_args()
    
    validator = EnvVarValidator(verbose=args.verbose)
    success = validator.run_all_tests()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
