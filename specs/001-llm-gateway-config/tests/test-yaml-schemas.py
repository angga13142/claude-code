#!/usr/bin/env python3
"""
YAML Schema Validation Tests
Validates all YAML configuration templates for syntax and schema correctness
"""

import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml")
    sys.exit(1)


class YAMLSchemaValidator:
    """Validates YAML files against expected schemas."""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.passed = 0
        self.failed = 0
        
    def log(self, message: str, level: str = "INFO"):
        """Log a message."""
        if self.verbose or level in ["ERROR", "WARN"]:
            prefix = {"INFO": "[INFO]", "WARN": "[WARN]", "ERROR": "[ERROR]", "PASS": "[PASS]"}
            print(f"{prefix.get(level, '[INFO]')} {message}")
    
    def validate_yaml_syntax(self, file_path: Path) -> Tuple[bool, str]:
        """Validate YAML syntax."""
        try:
            with open(file_path, 'r') as f:
                yaml.safe_load(f)
            return True, ""
        except yaml.YAMLError as e:
            return False, str(e)
        except Exception as e:
            return False, f"Unexpected error: {e}"
    
    def validate_litellm_config(self, config: Dict, file_path: Path) -> List[str]:
        """Validate LiteLLM configuration schema."""
        errors = []
        
        # Check required fields
        if "model_list" not in config:
            errors.append(f"{file_path.name}: Missing 'model_list'")
        
        # Validate model_list
        if "model_list" in config:
            if not isinstance(config["model_list"], list):
                errors.append(f"{file_path.name}: 'model_list' must be a list")
            else:
                for i, model in enumerate(config["model_list"]):
                    if not isinstance(model, dict):
                        errors.append(f"{file_path.name}: model_list[{i}] must be a dict")
                        continue
                    
                    # Check required model fields
                    if "model_name" not in model:
                        errors.append(f"{file_path.name}: model_list[{i}] missing 'model_name'")
                    
                    if "litellm_params" not in model:
                        errors.append(f"{file_path.name}: model_list[{i}] missing 'litellm_params'")
                    else:
                        params = model["litellm_params"]
                        if not isinstance(params, dict):
                            errors.append(f"{file_path.name}: model_list[{i}].litellm_params must be a dict")
                        else:
                            # Check required params
                            if "model" not in params:
                                errors.append(f"{file_path.name}: model_list[{i}].litellm_params missing 'model'")
        
        # Validate litellm_settings (optional)
        if "litellm_settings" in config:
            if not isinstance(config["litellm_settings"], dict):
                errors.append(f"{file_path.name}: 'litellm_settings' must be a dict")
        
        return errors
    
    def validate_model_config(self, config: Dict, file_path: Path) -> List[str]:
        """Validate individual model configuration."""
        errors = []
        
        # Model config should have at least model_name and litellm_params
        if "model_name" not in config and "litellm_params" not in config:
            # This might be a wrapper with model_list
            if "model_list" in config:
                return self.validate_litellm_config(config, file_path)
            errors.append(f"{file_path.name}: Missing 'model_name' or 'litellm_params'")
        
        return errors
    
    def validate_file(self, file_path: Path) -> bool:
        """Validate a single YAML file."""
        self.log(f"Validating: {file_path.name}")
        
        # Check syntax
        valid, error = self.validate_yaml_syntax(file_path)
        if not valid:
            self.log(f"{file_path.name}: YAML syntax error - {error}", "ERROR")
            self.errors.append(f"{file_path.name}: {error}")
            self.failed += 1
            return False
        
        # Load config
        try:
            with open(file_path, 'r') as f:
                config = yaml.safe_load(f)
        except Exception as e:
            self.log(f"{file_path.name}: Failed to load - {e}", "ERROR")
            self.errors.append(f"{file_path.name}: {e}")
            self.failed += 1
            return False
        
        # Skip empty files
        if config is None:
            self.log(f"{file_path.name}: Empty file", "WARN")
            self.warnings.append(f"{file_path.name}: Empty file")
            self.passed += 1
            return True
        
        # Validate schema based on file location
        schema_errors = []
        
        if "litellm" in file_path.name or file_path.parent.name == "templates":
            schema_errors = self.validate_litellm_config(config, file_path)
        elif file_path.parent.name == "models":
            schema_errors = self.validate_model_config(config, file_path)
        elif file_path.parent.name in ["enterprise", "multi-provider", "proxy"]:
            schema_errors = self.validate_litellm_config(config, file_path)
        
        # Report schema errors
        if schema_errors:
            for error in schema_errors:
                self.log(error, "ERROR")
                self.errors.append(error)
            self.failed += 1
            return False
        
        self.log(f"{file_path.name}: Valid", "PASS")
        self.passed += 1
        return True
    
    def validate_directory(self, directory: Path) -> None:
        """Validate all YAML files in directory recursively."""
        yaml_files = list(directory.glob("**/*.yaml")) + list(directory.glob("**/*.yml"))
        
        if not yaml_files:
            self.log(f"No YAML files found in {directory}", "WARN")
            return
        
        self.log(f"Found {len(yaml_files)} YAML files in {directory}")
        print()
        
        for yaml_file in sorted(yaml_files):
            self.validate_file(yaml_file)
    
    def print_summary(self) -> bool:
        """Print validation summary."""
        print()
        print("=" * 60)
        print("YAML Schema Validation Summary")
        print("=" * 60)
        print(f"Total files: {self.passed + self.failed}")
        print(f"Passed:      {self.passed}")
        print(f"Failed:      {self.failed}")
        print(f"Warnings:    {len(self.warnings)}")
        print()
        
        if self.warnings:
            print("Warnings:")
            for warning in self.warnings:
                print(f"  - {warning}")
            print()
        
        if self.errors:
            print("Errors:")
            for error in self.errors:
                print(f"  - {error}")
            print()
        
        if self.failed == 0:
            print("✓ All YAML files are valid")
            return True
        else:
            print("✗ Some YAML files have errors")
            return False


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Validate YAML configuration templates",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--directory", "-d", type=str, help="Directory to validate (default: ../templates)")
    
    args = parser.parse_args()
    
    # Determine directory
    script_dir = Path(__file__).parent
    if args.directory:
        templates_dir = Path(args.directory)
    else:
        templates_dir = script_dir.parent / "templates"
    
    if not templates_dir.exists():
        print(f"Error: Directory not found: {templates_dir}")
        sys.exit(1)
    
    # Validate
    validator = YAMLSchemaValidator(verbose=args.verbose)
    validator.validate_directory(templates_dir)
    
    # Print summary
    success = validator.print_summary()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
