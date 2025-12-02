# CLI Interface Contract: deploy-gateway-config.sh

**Feature**: 002-gateway-config-deploy  
**Date**: 2025-12-02  
**Purpose**: Define command-line interface contract for deployment tool

---

## Command Signature

```bash
deploy-gateway-config.sh [OPTIONS] [COMMAND] [COMMAND_ARGS]
```

---

## Commands

### 1. install (default)

**Purpose**: Deploy gateway configuration to ~/.claude/gateway

**Usage**:
```bash
deploy-gateway-config.sh [OPTIONS]
deploy-gateway-config.sh install [OPTIONS]
```

**Options**:
- `--preset PRESET` - Deployment preset (required)
- `--models MODELS` - Comma-separated model list (optional)
- `--gateway-type TYPE` - Gateway type for enterprise preset (optional)
- `--gateway-url URL` - Enterprise gateway URL (optional)
- `--auth-token TOKEN` - Authentication token (optional)
- `--proxy URL` - HTTP/HTTPS proxy URL (optional)
- `--proxy-auth CREDS` - Proxy authentication (optional)
- `--dry-run` - Preview changes without applying (optional)
- `--force` - Skip confirmations (optional)
- `--verbose` - Detailed output (optional)

**Exit Codes**:
- `0` - Success
- `1` - Permission denied
- `2` - Insufficient disk space
- `3` - Invalid preset
- `4` - Validation failed
- `5` - Source directory missing
- `6` - Backup failed

**Examples**:
```bash
# Basic deployment with all models
deploy-gateway-config.sh --preset basic

# Custom model selection
deploy-gateway-config.sh --preset basic --models gemini-2.5-flash,gemini-2.5-pro

# Enterprise gateway
deploy-gateway-config.sh --preset enterprise \
  --gateway-url https://gateway.company.com \
  --auth-token sk-xxx

# Dry run preview
deploy-gateway-config.sh --preset basic --dry-run

# Force non-interactive mode (CI/CD)
deploy-gateway-config.sh --preset basic --force
```

**Output Contract**:

```
🚀 Deploying LLM Gateway Configuration
  Preset: basic
  Models: gemini-2.5-flash, gemini-2.5-pro (2 of 8)
  Target: /home/user/.claude/gateway

✓ Pre-flight checks passed
✓ Created backup: gateway-backup-20251202-143022.tar.gz
⏳ Copying files... (49 files, 728 KB)
✓ Files deployed successfully
✓ Generated .env file (8 environment variables)
✓ Generated start-gateway.sh script
✓ Post-deployment validation passed

✅ Deployment completed in 7 seconds

Next steps:
  1. Review configuration: vi ~/.claude/gateway/config/litellm.yaml
  2. Start gateway: bash ~/.claude/gateway/start-gateway.sh
  3. Test connection: claude "What is 2+2?"

Documentation: ~/.claude/gateway/docs/
```

---

### 2. update

**Purpose**: Update existing deployment with new configuration

**Usage**:
```bash
deploy-gateway-config.sh update [OPTIONS]
```

**Options**:
- `--add-models MODELS` - Add models to existing deployment (optional)
- `--remove-models MODELS` - Remove models from existing deployment (optional)
- `--gateway-url URL` - Update gateway URL (optional)
- `--auth-token TOKEN` - Update authentication token (optional)
- `--force` - Skip confirmations (optional)
- `--verbose` - Detailed output (optional)

**Exit Codes**: Same as `install` command

**Examples**:
```bash
# Add new models
deploy-gateway-config.sh update --add-models llama3-405b,codestral

# Update gateway URL
deploy-gateway-config.sh update --gateway-url https://new-gateway.company.com

# Remove models
deploy-gateway-config.sh update --remove-models qwen3-235b,gpt-oss-20b
```

**Output Contract**:

```
🔄 Updating LLM Gateway Configuration
  Current deployment: basic preset (2 models)
  Changes:
    + Add models: llama3-405b, codestral
    = Preserve: .env, deployment.log

✓ Created backup: gateway-backup-20251202-163045.tar.gz
⏳ Updating configuration...
✓ Added 2 models to config/litellm.yaml
✓ Updated scripts/ and docs/ to latest version
✓ Validation passed

✅ Update completed in 4 seconds

New model count: 4 models
Restart gateway: bash ~/.claude/gateway/start-gateway.sh
```

---

### 3. rollback

**Purpose**: Restore from backup

**Usage**:
```bash
deploy-gateway-config.sh rollback [BACKUP_NAME]
```

**Arguments**:
- `BACKUP_NAME` - Backup filename or "latest" (required)

**Options**:
- `--force` - Skip confirmations (optional)
- `--verbose` - Detailed output (optional)

**Exit Codes**:
- `0` - Success
- `1` - Backup not found
- `2` - Backup validation failed
- `3` - Rollback failed
- `4` - Post-rollback validation failed

**Examples**:
```bash
# Rollback to latest backup
deploy-gateway-config.sh rollback latest

# Rollback to specific backup
deploy-gateway-config.sh rollback gateway-backup-20251201-162030.tar.gz

# Force rollback without confirmation
deploy-gateway-config.sh rollback latest --force
```

**Output Contract**:

```
🔙 Rolling back LLM Gateway Configuration
  Backup: gateway-backup-20251201-162030.tar.gz (2.1 MB)
  Created: 2025-12-01 16:20:30 (1 day ago)
  Config: basic preset, 8 models

⚠️  This will overwrite current configuration
    Current backup will be created: gateway-backup-20251202-164530.tar.gz

Continue? [y/N]: y

✓ Created safety backup
✓ Validated backup integrity
⏳ Restoring from backup...
✓ Files restored successfully
✓ Validation passed

✅ Rollback completed in 3 seconds

Restored deployment:
  Preset: basic
  Models: 8 models
  Config date: 2025-12-01

Restart gateway: bash ~/.claude/gateway/start-gateway.sh
```

---

### 4. list-backups

**Purpose**: List available backups for rollback

**Usage**:
```bash
deploy-gateway-config.sh list-backups [OPTIONS]
```

**Options**:
- `--verbose` - Show detailed backup information (optional)

**Exit Codes**:
- `0` - Success
- `1` - No backups found

**Output Contract**:

```
📦 Available backups in ~/.claude/gateway/backups/

  1. gateway-backup-20251202-143022.tar.gz
     Size: 2.3 MB | Created: 2 hours ago
     Preset: basic | Models: 2 | Status: ✓ Valid

  2. gateway-backup-20251202-105045.tar.gz
     Size: 2.1 MB | Created: 5 hours ago
     Preset: basic | Models: 8 | Status: ✓ Valid

  3. gateway-backup-20251201-162030.tar.gz
     Size: 2.0 MB | Created: 1 day ago
     Preset: basic | Models: 8 | Status: ✓ Valid

  4. gateway-backup-20251130-094512.tar.gz
     Size: 1.9 MB | Created: 2 days ago
     Preset: multi-provider | Models: 4 | Status: ✓ Valid

  5. gateway-backup-20251129-171845.tar.gz
     Size: 2.2 MB | Created: 3 days ago
     Preset: basic | Models: 8 | Status: ✓ Valid

Total: 5 backups (10.5 MB)

Rollback to latest: deploy-gateway-config.sh rollback latest
Rollback to specific: deploy-gateway-config.sh rollback gateway-backup-20251201-162030.tar.gz
```

---

## Global Options

Available for all commands:

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--help` | `-h` | Show help message | - |
| `--version` | `-v` | Show version | - |
| `--verbose` | - | Detailed output | `false` |
| `--quiet` | `-q` | Minimal output | `false` |
| `--force` | `-f` | Skip confirmations | `false` |
| `--dry-run` | - | Preview without applying | `false` |

---

## Environment Variables

The tool respects these environment variables:

| Variable | Purpose | Example |
|----------|---------|---------|
| `GATEWAY_SOURCE_DIR` | Override source directory | `/custom/path/to/001` |
| `GATEWAY_TARGET_DIR` | Override target directory | `/opt/gateway` |
| `GATEWAY_NO_BACKUP` | Skip backup creation | `1` or `true` |
| `GATEWAY_LOG_LEVEL` | Logging level | `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `NO_COLOR` | Disable colored output | `1` or `true` |

---

## Validation Guarantees

### Pre-deployment Checks

The tool guarantees these checks before any deployment:

1. ✅ Source directory exists and is readable
2. ✅ Target directory is writable (or parent is)
3. ✅ Disk space sufficient (50MB minimum)
4. ✅ Preset is valid
5. ✅ Model names are valid (if specified)
6. ✅ Gateway URL is valid HTTP/HTTPS (if specified)
7. ✅ No LiteLLM processes running (warning only)

### Post-deployment Checks

The tool guarantees these checks after deployment:

1. ✅ Expected file count matches preset
2. ✅ YAML configuration is valid
3. ✅ Environment variables populated (not placeholders)
4. ✅ Scripts have executable permissions
5. ✅ .env file has secure permissions (0600)
6. ✅ Backup created successfully (if not --no-backup)

### Rollback Guarantees

1. ✅ Backup file integrity verified
2. ✅ Safety backup created before rollback
3. ✅ Atomic replacement (no partial rollback)
4. ✅ Post-rollback validation passed

---

## Error Handling Contract

### Error Message Format

```
❌ Error: <ERROR_TYPE>
   Details: <DETAILED_MESSAGE>
   
   Suggestion: <ACTIONABLE_FIX>
   
   For help: deploy-gateway-config.sh --help
   Logs: ~/.claude/gateway/deployment.log
```

### Example Error Messages

**Permission Denied**:
```
❌ Error: Permission denied
   Details: Cannot write to /home/user/.claude directory
   
   Suggestion: Ensure directory exists and has write permissions:
     mkdir -p ~/.claude
     chmod 700 ~/.claude
   
   For help: deploy-gateway-config.sh --help
```

**Invalid Preset**:
```
❌ Error: Invalid preset 'production'
   Details: Preset must be one of: basic, enterprise, multi-provider, proxy
   
   Available presets:
     - basic: Quick start with all 8 Vertex AI models
     - enterprise: Connect to enterprise gateway
     - multi-provider: Route to multiple providers
     - proxy: Deploy with corporate proxy

   For help: deploy-gateway-config.sh --help
```

**Insufficient Disk Space**:
```
❌ Error: Insufficient disk space
   Details: Deployment requires 50 MB, but only 12 MB available
   
   Suggestion: Free up disk space:
     # Check current usage
     df -h ~
     
     # Remove old backups
     rm ~/.claude/gateway/backups/gateway-backup-*.tar.gz
   
   For help: deploy-gateway-config.sh --help
```

---

## Dry Run Output Contract

When `--dry-run` is specified, the tool MUST:

1. **Prefix output**: All lines prefixed with `🔍 DRY RUN:`
2. **Show actions**: Use "Would" language (Would deploy, Would create)
3. **No filesystem changes**: Guarantee no files written
4. **Exit with 0**: Always successful (unless validation fails)
5. **Show exact command**: Display command to run without --dry-run

**Example**:
```
🔍 DRY RUN MODE - No changes will be made

Configuration:
  Source: /home/user/claude-code/specs/001-llm-gateway-config
  Target: /home/user/.claude/gateway
  Preset: basic
  Models: gemini-2.5-flash (1 of 8 available)

Would deploy:
  ✓ templates/litellm-base.yaml → config/litellm.yaml
  ✓ templates/models/gemini-2.5-flash.yaml (merged)
  ✓ scripts/ (17 files, 324 KB)
  ✓ docs/ (12 files, 156 KB)
  ✓ examples/ (20 files, 248 KB)
  Total: 49 files, 728 KB

Would create:
  ✓ .env file (8 environment variables)
  ✓ start-gateway.sh script
  ✓ Backup: gateway-backup-20251202-153045.tar.gz (2.1 MB)

Validation checks:
  ✓ Write permissions OK
  ✓ Disk space available: 45 GB
  ✓ LiteLLM not running
  ✓ Source files valid

Next steps:
  Remove --dry-run flag to proceed:
    deploy-gateway-config.sh --preset basic --models gemini-2.5-flash
```

---

## Interactive Mode Contract

When running without `--force` flag, the tool MAY prompt for confirmation:

### Overwrite Confirmation

```
⚠️  Existing deployment found at ~/.claude/gateway
    Created: 2025-12-01 14:30:00 (1 day ago)
    Preset: basic | Models: 8

    This will:
      • Create backup: gateway-backup-20251202-153045.tar.gz
      • Overwrite configuration files
      • Preserve: .env, deployment.log

Continue? [y/N]: 
```

### LiteLLM Running Warning

```
⚠️  LiteLLM process detected (PID: 12345)
    Port: 4000 | Started: 2 hours ago

    Recommendation: Stop LiteLLM before deployment:
      kill 12345
      # or
      pkill -f litellm

Continue anyway? [y/N]:
```

---

## Non-Interactive Mode Contract

When `--force` is specified:

1. ✅ Skip all confirmation prompts
2. ✅ Assume "yes" to all questions
3. ✅ Fail fast on errors (no retry prompts)
4. ✅ Log all decisions to deployment.log
5. ✅ Exit with appropriate exit code

Use in CI/CD pipelines:

```bash
#!/bin/bash
set -e

deploy-gateway-config.sh \
  --preset basic \
  --models gemini-2.5-flash,gemini-2.5-pro \
  --force \
  --verbose

echo "Deployment completed successfully"
```

---

## Version Compatibility

The tool maintains backward compatibility:

- **Minor version changes**: Backwards compatible, new features only
- **Major version changes**: May break compatibility, require migration
- **Check version**: `deploy-gateway-config.sh --version`
- **Version format**: `MAJOR.MINOR.PATCH` (Semantic Versioning)

**Example**:
```bash
$ deploy-gateway-config.sh --version
deploy-gateway-config.sh version 1.0.0
Source: specs/001-llm-gateway-config (version 1.0.0)
```
