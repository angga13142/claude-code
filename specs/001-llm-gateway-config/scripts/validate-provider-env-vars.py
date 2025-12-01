#!/usr/bin/env python3
"""
Provider-Specific Environment Variables Validator

Purpose: Validate that required environment variables are set for each configured provider
User Story: US3 - Multi-Provider Gateway Configuration (Priority: P3)
Usage: python validate-provider-env-vars.py <config-file.yaml>
Exit Codes: 0 (all valid), 1 (validation errors), 2 (file not found/parse error)
"""

import os
import sys
import yaml
from typing import Dict, List, Set, Tuple

# Provider environment variable requirements
PROVIDER_REQUIREMENTS = {
    "anthropic": {
        "required": ["ANTHROPIC_API_KEY"],
        "optional": ["ANTHROPIC_BASE_URL", "ANTHROPIC_LOG"],
        "bypass_flags": [],
        "description": "Anthropic Direct API"
    },
    "bedrock": {
        "required": ["AWS_REGION"],
        "optional": [
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            "AWS_SESSION_TOKEN",
            "ANTHROPIC_BEDROCK_BASE_URL"
        ],
        "bypass_flags": ["CLAUDE_CODE_SKIP_BEDROCK_AUTH"],
        "description": "AWS Bedrock"
    },
    "vertex_ai": {
        "required": ["VERTEX_PROJECT_ID", "VERTEX_LOCATION"],
        "optional": [
            "GOOGLE_APPLICATION_CREDENTIALS",
            "ANTHROPIC_VERTEX_BASE_URL"
        ],
        "bypass_flags": ["CLAUDE_CODE_SKIP_VERTEX_AUTH"],
        "description": "Google Vertex AI"
    }
}

# LiteLLM-specific variables
LITELLM_REQUIREMENTS = {
    "required": ["LITELLM_MASTER_KEY"],
    "optional": [
        "REDIS_HOST",
        "REDIS_PORT",
        "REDIS_PASSWORD",
        "DATABASE_URL"
    ]
}


def load_config(config_path: str) -> Dict:
    """Load and parse YAML configuration file."""
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        return config
    except FileNotFoundError:
        print(f"❌ ERROR: Configuration file not found: {config_path}", file=sys.stderr)
        sys.exit(2)
    except yaml.YAMLError as e:
        print(f"❌ ERROR: Failed to parse YAML: {e}", file=sys.stderr)
        sys.exit(2)


def detect_providers(config: Dict) -> Set[str]:
    """Detect which providers are used in the configuration."""
    providers = set()
    
    model_list = config.get("model_list", [])
    for model in model_list:
        litellm_params = model.get("litellm_params", {})
        model_name = litellm_params.get("model", "")
        
        # Detect provider from model string
        if model_name.startswith("anthropic/"):
            providers.add("anthropic")
        elif model_name.startswith("bedrock/"):
            providers.add("bedrock")
        elif model_name.startswith("vertex_ai/"):
            providers.add("vertex_ai")
    
    return providers


def check_environment_variable(var_name: str) -> Tuple[bool, str]:
    """Check if an environment variable is set."""
    value = os.getenv(var_name)
    if value:
        # Mask sensitive values
        if "KEY" in var_name or "TOKEN" in var_name or "PASSWORD" in var_name:
            display_value = f"{value[:8]}..." if len(value) > 8 else "***"
        else:
            display_value = value
        return True, display_value
    return False, ""


def validate_provider(provider: str, requirements: Dict) -> Tuple[bool, List[str], List[str]]:
    """Validate environment variables for a specific provider."""
    errors = []
    warnings = []
    
    # Check required variables
    for var in requirements["required"]:
        is_set, value = check_environment_variable(var)
        if not is_set:
            errors.append(f"  ❌ Missing required variable: {var}")
        else:
            print(f"  ✓ {var}: {value}")
    
    # Check optional variables
    optional_set = []
    optional_missing = []
    for var in requirements.get("optional", []):
        is_set, value = check_environment_variable(var)
        if is_set:
            optional_set.append(f"  ✓ {var}: {value}")
        else:
            optional_missing.append(f"  ℹ {var}: Not set (optional)")
    
    # Display optional variables
    if optional_set:
        for msg in optional_set:
            print(msg)
    
    # Check bypass flags
    bypass_flags = requirements.get("bypass_flags", [])
    if bypass_flags:
        print(f"\n  Authentication Bypass Flags:")
        for flag in bypass_flags:
            is_set, value = check_environment_variable(flag)
            if is_set:
                print(f"  ⚠ {flag}: {value} (authentication bypass enabled)")
                warnings.append(f"  ⚠ {flag} is set - Claude Code will skip provider authentication")
            else:
                print(f"  ℹ {flag}: Not set (normal authentication)")
    
    # Show optional missing variables
    if optional_missing:
        print(f"\n  Optional Variables (Not Set):")
        for msg in optional_missing:
            print(msg)
    
    return len(errors) == 0, errors, warnings


def validate_litellm(config: Dict) -> Tuple[bool, List[str], List[str]]:
    """Validate LiteLLM-specific environment variables."""
    errors = []
    warnings = []
    
    print("\n📦 LiteLLM Configuration:")
    
    # Check required variables
    for var in LITELLM_REQUIREMENTS["required"]:
        is_set, value = check_environment_variable(var)
        if not is_set:
            errors.append(f"  ❌ Missing required variable: {var}")
        else:
            print(f"  ✓ {var}: {value}")
    
    # Check optional variables
    optional_set = []
    optional_missing = []
    for var in LITELLM_REQUIREMENTS["optional"]:
        is_set, value = check_environment_variable(var)
        if is_set:
            optional_set.append(f"  ✓ {var}: {value}")
        else:
            optional_missing.append(f"  ℹ {var}: Not set (optional)")
    
    if optional_set:
        for msg in optional_set:
            print(msg)
    
    if optional_missing:
        print(f"\n  Optional Variables (Not Set):")
        for msg in optional_missing:
            print(msg)
    
    return len(errors) == 0, errors, warnings


def validate_claude_code() -> Tuple[bool, List[str]]:
    """Validate Claude Code integration environment variables."""
    errors = []
    warnings = []
    
    print("\n🤖 Claude Code Integration:")
    
    # Check ANTHROPIC_BASE_URL
    base_url_set, base_url_value = check_environment_variable("ANTHROPIC_BASE_URL")
    if base_url_set:
        print(f"  ✓ ANTHROPIC_BASE_URL: {base_url_value}")
    else:
        warnings.append("  ⚠ ANTHROPIC_BASE_URL not set - Claude Code will use default API endpoint")
    
    # Check ANTHROPIC_API_KEY (should be LiteLLM master key when using gateway)
    api_key_set, api_key_value = check_environment_variable("ANTHROPIC_API_KEY")
    if api_key_set:
        print(f"  ✓ ANTHROPIC_API_KEY: {api_key_value}")
    else:
        warnings.append("  ⚠ ANTHROPIC_API_KEY not set - required for Claude Code to connect to gateway")
    
    return len(errors) == 0, errors, warnings


def main():
    """Main validation routine."""
    if len(sys.argv) != 2:
        print("Usage: python validate-provider-env-vars.py <config-file.yaml>", file=sys.stderr)
        sys.exit(2)
    
    config_path = sys.argv[1]
    print(f"🔍 Validating provider environment variables for: {config_path}\n")
    
    # Load configuration
    config = load_config(config_path)
    
    # Detect providers
    providers = detect_providers(config)
    if not providers:
        print("⚠ WARNING: No providers detected in configuration", file=sys.stderr)
        print("\nConfiguration appears to be empty or invalid.", file=sys.stderr)
        sys.exit(1)
    
    print(f"🔌 Detected Providers: {', '.join(sorted(providers))}\n")
    
    all_errors = []
    all_warnings = []
    
    # Validate each provider
    for provider in sorted(providers):
        requirements = PROVIDER_REQUIREMENTS[provider]
        print(f"🔐 {requirements['description']} ({provider}):")
        
        is_valid, errors, warnings = validate_provider(provider, requirements)
        all_errors.extend(errors)
        all_warnings.extend(warnings)
        print()
    
    # Validate LiteLLM configuration
    is_litellm_valid, litellm_errors, litellm_warnings = validate_litellm(config)
    all_errors.extend(litellm_errors)
    all_warnings.extend(litellm_warnings)
    
    # Validate Claude Code integration
    is_claude_valid, claude_errors, claude_warnings = validate_claude_code()
    all_errors.extend(claude_errors)
    all_warnings.extend(claude_warnings)
    
    # Print summary
    print("\n" + "="*60)
    print("📊 Validation Summary")
    print("="*60)
    
    if all_errors:
        print(f"\n❌ Found {len(all_errors)} error(s):\n")
        for error in all_errors:
            print(error)
    
    if all_warnings:
        print(f"\n⚠ Found {len(all_warnings)} warning(s):\n")
        for warning in all_warnings:
            print(warning)
    
    if not all_errors and not all_warnings:
        print("\n✅ All environment variables are properly configured!")
    elif not all_errors:
        print("\n✅ All required environment variables are set (warnings are informational)")
    
    # Exit with appropriate code
    if all_errors:
        print("\n❌ Validation failed. Please set missing environment variables and try again.")
        sys.exit(1)
    else:
        print("\n✅ Validation passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
