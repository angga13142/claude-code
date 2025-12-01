#!/usr/bin/env python3
"""
Configuration Validation Script
Purpose: Validate LiteLLM configuration files and environment variables
Usage: python validate-config.py <path-to-litellm-config.yaml>
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


class ConfigValidator:
    """Validates LiteLLM configuration files and environment variables."""
    
    def __init__(self, config_path: str):
        self.config_path = Path(config_path)
        self.config: Optional[Dict[str, Any]] = None
        self.errors: List[str] = []
        self.warnings: List[str] = []
        
    def validate(self) -> bool:
        """Run all validation checks. Returns True if validation passes."""
        if not self._load_config():
            return False
            
        self._validate_structure()
        self._validate_model_list()
        self._validate_environment_variables()
        self._validate_router_settings()
        self._validate_security()
        
        return len(self.errors) == 0
    
    def _load_config(self) -> bool:
        """Load and parse YAML configuration file."""
        if not self.config_path.exists():
            self.errors.append(f"Configuration file not found: {self.config_path}")
            return False
            
        try:
            with open(self.config_path, 'r') as f:
                self.config = yaml.safe_load(f)
        except yaml.YAMLError as e:
            self.errors.append(f"Invalid YAML syntax: {e}")
            return False
        except Exception as e:
            self.errors.append(f"Error reading configuration: {e}")
            return False
            
        if not isinstance(self.config, dict):
            self.errors.append("Configuration must be a YAML object/dictionary")
            return False
            
        return True
    
    def _validate_structure(self):
        """Validate top-level configuration structure."""
        if self.config is None:
            return
            
        required_keys = ['model_list']
        optional_keys = ['litellm_settings', 'router_settings', 'general_settings']
        
        # Check required keys
        for key in required_keys:
            if key not in self.config:
                self.errors.append(f"Missing required key: {key}")
        
        # Warn about unknown keys
        all_valid_keys = set(required_keys + optional_keys)
        for key in self.config.keys():
            if key not in all_valid_keys:
                self.warnings.append(f"Unknown top-level key: {key} (may be ignored)")
    
    def _validate_model_list(self):
        """Validate model_list configuration."""
        if self.config is None:
            return
            
        model_list = self.config.get('model_list', [])
        
        if not isinstance(model_list, list):
            self.errors.append("model_list must be a list")
            return
            
        if len(model_list) == 0:  # type: ignore[arg-type]
            self.errors.append("model_list cannot be empty")
            return
        
        model_names: set[str] = set()
        
        for idx, model in enumerate(model_list):  # type: ignore[arg-type,var-annotated]
            if not isinstance(model, dict):
                self.errors.append(f"Model at index {idx} must be an object")
                continue
            
            # Validate required fields
            if 'model_name' not in model:
                self.errors.append(f"Model at index {idx} missing 'model_name'")
            else:
                model_name = str(model['model_name'])  # type: ignore[arg-type]
                if model_name in model_names:
                    self.errors.append(f"Duplicate model_name: {model_name}")
                model_names.add(model_name)
            
            if 'litellm_params' not in model:
                self.errors.append(f"Model '{model.get('model_name', f'index-{idx}')}' missing 'litellm_params'")  # type: ignore[union-attr]
                continue
            
            # Validate litellm_params
            params = model['litellm_params']  # type: ignore[index]
            if not isinstance(params, dict):
                self.errors.append(f"Model '{model.get('model_name')}': litellm_params must be an object")  # type: ignore[union-attr]
                continue
            
            model_name_str = str(model.get('model_name', f'index-{idx}'))  # type: ignore[arg-type]
            
            if 'model' not in params:
                self.errors.append(f"Model '{model_name_str}': litellm_params missing 'model' field")
            else:
                model_id = str(params['model'])  # type: ignore[arg-type]
                self._validate_model_identifier(model_name_str, model_id)
            
            # Validate Vertex AI specific params
            model_value = str(params.get('model', ''))  # type: ignore[arg-type]
            if model_value.startswith('vertex_ai/'):
                self._validate_vertex_ai_params(model_name_str, params)  # type: ignore[arg-type]
    
    def _validate_model_identifier(self, model_name: str, model_id: str):
        """Validate model identifier format."""
        valid_prefixes = [
            'vertex_ai/',
            'bedrock/',
            'anthropic/',
            'openai/',
            'azure/',
        ]
        
        if not any(model_id.startswith(prefix) for prefix in valid_prefixes):
            self.warnings.append(
                f"Model '{model_name}': Identifier '{model_id}' doesn't use standard provider prefix"
            )
    
    def _validate_vertex_ai_params(self, model_name: str, params: Dict[str, Any]):
        """Validate Vertex AI specific parameters."""
        required = ['vertex_project', 'vertex_location']
        
        for param in required:
            if param not in params:
                self.errors.append(f"Model '{model_name}': Missing required Vertex AI param '{param}'")
            elif not isinstance(params[param], str) or len(params[param].strip()) == 0:
                self.errors.append(f"Model '{model_name}': Invalid {param} value")
        
        # Validate region format
        if 'vertex_location' in params:
            location = params['vertex_location']
            valid_regions = ['us-central1', 'us-east1', 'us-west1', 'europe-west1', 'asia-east1']
            if location not in valid_regions:
                self.warnings.append(
                    f"Model '{model_name}': Unusual vertex_location '{location}'. "
                    f"Common regions: {', '.join(valid_regions)}"
                )
    
    def _validate_environment_variables(self):
        """Validate environment variable references and actual values."""
        if self.config is None:
            return
            
        # Check general_settings.master_key
        general_settings = self.config.get('general_settings', {})
        master_key = general_settings.get('master_key', '')
        
        if not master_key:
            self.errors.append("general_settings.master_key is required")
        elif master_key.startswith('os.environ/'):
            env_var = master_key.replace('os.environ/', '')
            if not os.environ.get(env_var):
                self.warnings.append(
                    f"Environment variable {env_var} is not set (required for LiteLLM to start)"
                )
        
        # Check for placeholder values
        for model in self.config.get('model_list', []):
            params = model.get('litellm_params', {})
            
            if params.get('vertex_project') == 'YOUR_PROJECT_ID':
                self.warnings.append(
                    f"Model '{model.get('model_name')}': vertex_project still contains placeholder 'YOUR_PROJECT_ID'"
                )
    
    def _validate_router_settings(self):
        """Validate router_settings configuration."""
        if self.config is None:
            return
            
        router_settings = self.config.get('router_settings', {})
        
        if not router_settings:
            return  # Router settings are optional
        
        # Validate routing_strategy
        valid_strategies = [
            'simple-shuffle',
            'least-busy',
            'usage-based-routing',
            'latency-based-routing'
        ]
        
        strategy = router_settings.get('routing_strategy')
        if strategy and strategy not in valid_strategies:
            self.errors.append(
                f"Invalid routing_strategy: {strategy}. "
                f"Valid options: {', '.join(valid_strategies)}"
            )
        
        # Validate retry_policy
        retry_policy = router_settings.get('retry_policy', {})
        if retry_policy:
            for key, value in retry_policy.items():
                if not isinstance(value, int) or value < 0:
                    self.errors.append(
                        f"retry_policy.{key} must be a non-negative integer, got: {value}"
                    )
    
    def _validate_security(self):
        """Check for security issues."""
        config_str = yaml.dump(self.config)
        
        # Check for hardcoded secrets (common patterns)
        sensitive_patterns = [
            ('sk-proj-', 'OpenAI API key'),
            ('sk-ant-', 'Anthropic API key'),
            ('AKIA', 'AWS access key'),
            ('-----BEGIN PRIVATE KEY-----', 'Private key'),
        ]
        
        for pattern, description in sensitive_patterns:
            if pattern in config_str:
                self.errors.append(
                    f"SECURITY: Found hardcoded {description}. Use os.environ/VARIABLE_NAME instead"
                )
    
    def print_results(self):
        """Print validation results."""
        print(f"\n{'='*60}")
        print(f"Configuration Validation: {self.config_path}")
        print(f"{'='*60}\n")
        
        if self.errors:
            print(f"❌ ERRORS ({len(self.errors)}):\n")
            for error in self.errors:
                print(f"  • {error}")
            print()
        
        if self.warnings:
            print(f"⚠️  WARNINGS ({len(self.warnings)}):\n")
            for warning in self.warnings:
                print(f"  • {warning}")
            print()
        
        if not self.errors and not self.warnings:
            print("✅ Configuration is valid!\n")
        elif not self.errors:
            print("✅ Configuration is valid (with warnings)\n")
        else:
            print("❌ Configuration has errors and cannot be used\n")


def main():
    parser = argparse.ArgumentParser(
        description='Validate LiteLLM configuration files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python validate-config.py litellm_config.yaml
  python validate-config.py ../templates/litellm-base.yaml
  python validate-config.py --json config.yaml  # Output as JSON
        """
    )
    parser.add_argument(
        'config_file',
        help='Path to LiteLLM configuration YAML file'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results as JSON'
    )
    
    args = parser.parse_args()
    
    validator = ConfigValidator(args.config_file)
    is_valid = validator.validate()
    
    if args.json:
        result = {  # type: ignore[var-annotated]
            'valid': is_valid,
            'errors': validator.errors,
            'warnings': validator.warnings,
            'config_file': str(validator.config_path)
        }
        print(json.dumps(result, indent=2))
    else:
        validator.print_results()
    
    sys.exit(0 if is_valid else 1)


if __name__ == '__main__':
    main()
