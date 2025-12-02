#!/usr/bin/env python3
"""
Configuration Migration Helper
Helps migrate LiteLLM configurations between versions
"""

import argparse
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Tuple

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml")
    sys.exit(1)


class ConfigMigrator:
    """Handles configuration migration between versions."""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.migrations: List[Tuple[str, str, callable]] = [
            ("0.1.0", "0.2.0", self.migrate_0_1_to_0_2),
            ("0.2.0", "1.0.0", self.migrate_0_2_to_1_0),
        ]
    
    def log(self, message: str, level: str = "INFO"):
        """Log a message if verbose is enabled."""
        if self.verbose or level == "ERROR":
            prefix = {"INFO": "[INFO]", "WARN": "[WARN]", "ERROR": "[ERROR]"}
            print(f"{prefix.get(level, '[INFO]')} {message}")
    
    def backup_config(self, config_path: Path) -> Path:
        """Create a backup of the configuration file."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = config_path.with_suffix(f".yaml.backup.{timestamp}")
        
        shutil.copy2(config_path, backup_path)
        self.log(f"Backup created: {backup_path}")
        
        return backup_path
    
    def detect_version(self, config: Dict[str, Any]) -> str:
        """Detect the version of the configuration."""
        # Check for version field
        if "version" in config:
            return config["version"]
        
        # Heuristic detection based on structure
        if "model_list" in config:
            if isinstance(config.get("litellm_settings"), dict):
                # Has modern structure
                return "1.0.0"
            else:
                # Has basic structure
                return "0.2.0"
        else:
            # Very old structure
            return "0.1.0"
    
    def migrate_0_1_to_0_2(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Migrate from version 0.1.0 to 0.2.0."""
        self.log("Migrating from 0.1.0 to 0.2.0")
        
        new_config = {}
        
        # Convert old models structure to model_list
        if "models" in config:
            new_config["model_list"] = []
            for model in config["models"]:
                new_config["model_list"].append({
                    "model_name": model.get("name"),
                    "litellm_params": {
                        "model": model.get("model_id"),
                        "api_key": model.get("api_key", "os.environ/ANTHROPIC_API_KEY"),
                    }
                })
        
        # Copy other settings
        if "settings" in config:
            new_config["litellm_settings"] = config["settings"]
        
        new_config["version"] = "0.2.0"
        
        return new_config
    
    def migrate_0_2_to_1_0(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Migrate from version 0.2.0 to 1.0.0."""
        self.log("Migrating from 0.2.0 to 1.0.0")
        
        new_config = config.copy()
        
        # Update model identifiers to new format
        if "model_list" in new_config:
            for model in new_config["model_list"]:
                if "litellm_params" in model:
                    params = model["litellm_params"]
                    
                    # Update Vertex AI model format
                    if "model" in params:
                        model_id = params["model"]
                        
                        # vertex_ai/gemini-2.5-flash-exp → vertex_ai/gemini-2.0-flash-exp
                        if "gemini-2.5-flash" in model_id:
                            params["model"] = model_id.replace("gemini-2.5-flash", "gemini-2.0-flash")
                            self.log(f"Updated model: {model_id} → {params['model']}", "WARN")
                        
                        # Add vertex_project if missing for Vertex AI models
                        if model_id.startswith("vertex_ai") and "vertex_project" not in params:
                            params["vertex_project"] = "os.environ/VERTEX_PROJECT_ID"
                            params["vertex_location"] = "os.environ/VERTEX_LOCATION"
                            self.log(f"Added vertex_project for model: {model.get('model_name')}")
        
        # Add recommended settings if missing
        if "litellm_settings" not in new_config:
            new_config["litellm_settings"] = {}
        
        settings = new_config["litellm_settings"]
        
        # Add defaults
        if "request_timeout" not in settings:
            settings["request_timeout"] = 600
        
        if "num_retries" not in settings:
            settings["num_retries"] = 3
        
        if "set_verbose" not in settings:
            settings["set_verbose"] = False
        
        new_config["version"] = "1.0.0"
        
        return new_config
    
    def migrate(self, from_version: str, to_version: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """Migrate configuration from one version to another."""
        current_version = from_version
        migrated_config = config.copy()
        
        for from_v, to_v, migration_func in self.migrations:
            if self.version_gte(current_version, from_v) and self.version_lt(current_version, to_version):
                self.log(f"Applying migration: {from_v} → {to_v}")
                migrated_config = migration_func(migrated_config)
                current_version = to_v
                
                if current_version == to_version:
                    break
        
        return migrated_config
    
    @staticmethod
    def version_gte(v1: str, v2: str) -> bool:
        """Check if v1 >= v2."""
        v1_parts = [int(x) for x in v1.split(".")]
        v2_parts = [int(x) for x in v2.split(".")]
        return v1_parts >= v2_parts
    
    @staticmethod
    def version_lt(v1: str, v2: str) -> bool:
        """Check if v1 < v2."""
        v1_parts = [int(x) for x in v1.split(".")]
        v2_parts = [int(x) for x in v2.split(".")]
        return v1_parts < v2_parts
    
    def validate_config(self, config: Dict[str, Any]) -> bool:
        """Validate the migrated configuration."""
        required_fields = ["model_list"]
        
        for field in required_fields:
            if field not in config:
                self.log(f"Missing required field: {field}", "ERROR")
                return False
        
        if not isinstance(config["model_list"], list):
            self.log("model_list must be a list", "ERROR")
            return False
        
        if len(config["model_list"]) == 0:
            self.log("model_list is empty", "WARN")
        
        for i, model in enumerate(config["model_list"]):
            if "model_name" not in model:
                self.log(f"Model {i} missing model_name", "ERROR")
                return False
            
            if "litellm_params" not in model:
                self.log(f"Model {i} missing litellm_params", "ERROR")
                return False
        
        return True
    
    def migrate_file(self, config_path: Path, to_version: str = "1.0.0", 
                    backup: bool = True, dry_run: bool = False) -> bool:
        """Migrate a configuration file."""
        try:
            # Load config
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            
            # Detect current version
            current_version = self.detect_version(config)
            self.log(f"Detected version: {current_version}")
            
            # Check if migration needed
            if current_version == to_version:
                self.log(f"Configuration is already at version {to_version}")
                return True
            
            # Create backup
            if backup and not dry_run:
                self.backup_config(config_path)
            
            # Migrate
            migrated_config = self.migrate(current_version, to_version, config)
            
            # Validate
            if not self.validate_config(migrated_config):
                self.log("Migrated configuration validation failed", "ERROR")
                return False
            
            # Write migrated config
            if dry_run:
                self.log("DRY RUN - Changes not written")
                print("\nMigrated configuration:")
                print(yaml.dump(migrated_config, default_flow_style=False, sort_keys=False))
            else:
                with open(config_path, 'w') as f:
                    yaml.dump(migrated_config, f, default_flow_style=False, sort_keys=False)
                self.log(f"Configuration migrated to version {to_version}")
            
            return True
            
        except FileNotFoundError:
            self.log(f"Configuration file not found: {config_path}", "ERROR")
            return False
        except yaml.YAMLError as e:
            self.log(f"YAML parsing error: {e}", "ERROR")
            return False
        except Exception as e:
            self.log(f"Migration error: {e}", "ERROR")
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Migrate LiteLLM configuration files between versions",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Migrate to latest version with backup
  python migrate-config.py config/litellm.yaml
  
  # Migrate to specific version
  python migrate-config.py config/litellm.yaml --to-version 1.0.0
  
  # Dry run (preview changes)
  python migrate-config.py config/litellm.yaml --dry-run
  
  # Migrate without backup
  python migrate-config.py config/litellm.yaml --no-backup
        """
    )
    
    parser.add_argument("config_path", type=str, help="Path to configuration file")
    parser.add_argument("--to-version", type=str, default="1.0.0", 
                       help="Target version (default: 1.0.0)")
    parser.add_argument("--no-backup", action="store_true", 
                       help="Do not create backup")
    parser.add_argument("--dry-run", action="store_true", 
                       help="Preview changes without writing")
    parser.add_argument("--verbose", "-v", action="store_true", 
                       help="Enable verbose output")
    
    args = parser.parse_args()
    
    # Initialize migrator
    migrator = ConfigMigrator(verbose=args.verbose)
    
    # Migrate
    config_path = Path(args.config_path)
    success = migrator.migrate_file(
        config_path,
        to_version=args.to_version,
        backup=not args.no_backup,
        dry_run=args.dry_run
    )
    
    if success:
        print("\n✓ Migration completed successfully")
        sys.exit(0)
    else:
        print("\n✗ Migration failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
