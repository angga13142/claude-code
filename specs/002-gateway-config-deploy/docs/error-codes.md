# Error Codes Reference

**Feature**: LLM Gateway Configuration Deployment (002-gateway-config-deploy)  
**Purpose**: Complete reference for all error codes with examples and solutions

---

## Exit Code Summary

| Code | Meaning | When It Occurs | Recovery Action |
|------|---------|----------------|-----------------|
| 0 | Success | Deployment completed successfully | N/A |
| 1 | Permission Denied | No write access to target directory | Fix permissions with chmod/chown |
| 2 | Insufficient Disk Space | Less than required space available | Free up disk space |
| 3 | Invalid Arguments | Invalid preset, model, or command | Check command syntax |
| 4 | Validation Failed | Configuration validation error | Fix YAML syntax or configuration |
| 5 | Source Missing | Source directory corrupted or missing | Restore from git |
| 6 | Backup Failed | Cannot create or access backups | Check backup directory permissions |

---

## Exit Code 0: Success

### Description
Deployment completed successfully with no errors.

### Example Output

```
✅ Deployment completed in 7 seconds

Next steps:
  1. Review configuration: vi /home/user/.claude/gateway/config/litellm.yaml
  2. Start gateway: bash /home/user/.claude/gateway/start-gateway.sh
  3. Test connection: claude 'What is 2+2?'
```

### What To Do
Proceed with starting and testing the gateway.

---

## Exit Code 1: Permission Denied

### Description
The script does not have write permission to create or modify files in the target directory.

### Common Causes

1. Target directory owned by another user
2. Parent directory is read-only
3. SELinux or AppArmor blocking access
4. File system mounted as read-only

### Example Output

```
[1/7] Running pre-deployment validation...
✗ No write permission to $(dirname "$TARGET_DIR")

Error: No write permission on: /home/user/.claude

Current permissions: drwxr-xr-x 2 root root 4096 Dec  2 14:30 /home/user/.claude

To fix this issue:
  chmod u+w /home/user/.claude

Or if you need ownership:
  sudo chown $USER:$USER /home/user/.claude


Command exited with code 1
```

### Solutions

**Solution 1: Fix Permissions**
```bash
chmod u+w ~/.claude
```

**Solution 2: Fix Ownership**
```bash
sudo chown $USER:$USER ~/.claude
```

**Solution 3: Check SELinux** (if applicable)
```bash
# Check if SELinux is enforcing
getenforce

# Allow access
sudo chcon -R -t user_home_t ~/.claude
```

**Solution 4: Remount Filesystem** (rare)
```bash
# Check if mounted read-only
mount | grep /home

# Remount as read-write (requires root)
sudo mount -o remount,rw /home
```

---

## Exit Code 2: Insufficient Disk Space

### Description
Not enough free disk space available for deployment (requires at least 50 MB).

### Example Output

```
[1/7] Running pre-deployment validation...

✗ Insufficient disk space

  Required: 50 MB
  Available: 12 MB
  Location: /home/user

To free up space:
  # Check disk usage
  df -h

  # Find large files
  du -h ~ | sort -h | tail -20

  # Clean old backups
  rm -f ~/.claude/gateway/backups/*.tar.gz

  # Clear package caches (careful!)
  # npm cache clean --force
  # pip cache purge


Command exited with code 2
```

### Solutions

**Solution 1: Remove Old Backups**
```bash
# List backups by size
du -h ~/.claude/gateway/backups/*.tar.gz

# Remove old backups
rm ~/.claude/gateway/backups/gateway-backup-2025*.tar.gz
```

**Solution 2: Clear Caches**
```bash
# Node.js cache
npm cache clean --force

# Python cache
pip cache purge

# System cache (Ubuntu/Debian)
sudo apt clean
```

**Solution 3: Find and Remove Large Files**
```bash
# Find files larger than 100MB
find ~ -type f -size +100M -exec ls -lh {} \;

# Check directory sizes
du -h ~ | sort -h | tail -20
```

**Solution 4: Increase Disk Space**
- Add more disk space to the partition
- Move home directory to larger partition
- Use external storage

---

## Exit Code 3: Invalid Arguments

### Description
Invalid command-line arguments provided (wrong preset, invalid model name, etc.).

### Common Causes

1. Invalid preset name
2. Invalid model name
3. Unknown command
4. Missing required option
5. Wrong option value

### Example 1: Invalid Preset

```bash
$ bash scripts/deploy-gateway-config.sh --preset invalid

✗ Invalid preset: invalid
Valid presets: basic, enterprise, multi-provider, proxy

Command exited with code 3
```

**Solution**: Use a valid preset name
```bash
bash scripts/deploy-gateway-config.sh --preset basic
```

### Example 2: Invalid Model Name

```bash
$ bash scripts/deploy-gateway-config.sh --preset basic --models invalid-model

[1/7] Running pre-deployment validation...
ℹ Validating model selection...
✗ No valid models selected

Available models:

  gemini-2.0-flash-exp      - Gemini 2.0 Flash (Experimental) - Fastest model
  gemini-exp-1206           - Gemini Experimental (Dec 2024) - Latest features
  gemini-2.5-flash          - Gemini 2.5 Flash - Production fast model
  gemini-2.5-pro            - Gemini 2.5 Pro - Most capable model
  deepseek-r1               - DeepSeek R1 - Advanced reasoning model
  deepseek-reasoner         - DeepSeek Reasoner - Chain-of-thought model
  llama-3-3-70b             - Llama 3.3 70B - Open-source model
  llama-3-405b              - Llama 3.1 405B - Largest Llama model

Note: Model availability may vary by GCP region.

Command exited with code 3
```

**Solution**: Use valid model names
```bash
bash scripts/deploy-gateway-config.sh --preset basic --models gemini-2.5-flash,deepseek-r1
```

### Example 3: Missing Required Option

```bash
$ bash scripts/deploy-gateway-config.sh --preset enterprise

✗ Enterprise preset requires --gateway-url

Command exited with code 3
```

**Solution**: Provide required options
```bash
bash scripts/deploy-gateway-config.sh --preset enterprise \
  --gateway-url https://gateway.company.com \
  --auth-token sk-xxx
```

### Example 4: Unknown Command

```bash
$ bash scripts/deploy-gateway-config.sh unknown-command

✗ Unknown command: unknown-command
Valid commands: install, update, rollback, list-backups

Command exited with code 3
```

**Solution**: Use valid command
```bash
bash scripts/deploy-gateway-config.sh install --preset basic
# or just:
bash scripts/deploy-gateway-config.sh --preset basic
```

---

## Exit Code 4: Validation Failed

### Description
Configuration validation failed (invalid YAML, missing required fields, etc.).

### Common Causes

1. Invalid YAML syntax
2. Missing required configuration
3. Corrupted template files
4. Model configuration errors

### Example Output

```
[7/7] Running post-deployment validation...

✗ Invalid YAML syntax in: /home/user/.claude/gateway/templates/litellm-complete.yaml

To debug YAML errors:
  python3 -c "import yaml; yaml.safe_load(open('/home/user/.claude/gateway/templates/litellm-complete.yaml'))"

✗ YAML configuration validation failed

Command exited with code 4
```

### Solutions

**Solution 1: Check YAML Syntax**
```bash
# Validate YAML manually
python3 -c "import yaml; yaml.safe_load(open('~/.claude/gateway/templates/litellm-complete.yaml'))"

# Or use yq
yq eval '.' ~/.claude/gateway/templates/litellm-complete.yaml
```

**Solution 2: Restore from Backup**
```bash
# List backups
bash scripts/deploy-gateway-config.sh list-backups

# Rollback to working configuration
bash scripts/deploy-gateway-config.sh rollback latest
```

**Solution 3: Redeploy**
```bash
# Remove corrupted deployment
rm -rf ~/.claude/gateway

# Deploy fresh copy
bash scripts/deploy-gateway-config.sh --preset basic
```

---

## Exit Code 5: Source Missing

### Description
Source directory (specs/001-llm-gateway-config) is missing or corrupted.

### Example Output

```
[1/7] Running pre-deployment validation...

✗ Source directory does not exist: /path/to/specs/001-llm-gateway-config

This usually means:
  1. The LLM Gateway Configuration (spec 001) is not in the repository
  2. The script is being run from the wrong directory
  3. The repository structure has changed

Expected location:
  specs/001-llm-gateway-config/

To fix this:
  cd <repository-root>
  bash scripts/deploy-gateway-config.sh --preset basic

✗ Source directory validation failed

Command exited with code 5
```

### Solutions

**Solution 1: Change to Repository Root**
```bash
# Find repository root
git rev-parse --show-toplevel

# Change directory
cd $(git rev-parse --show-toplevel)

# Run deployment
bash scripts/deploy-gateway-config.sh --preset basic
```

**Solution 2: Restore Source Files**
```bash
# Check if files exist in git
git ls-files specs/001-llm-gateway-config/

# Restore from git
git checkout specs/001-llm-gateway-config/

# Verify structure
ls -la specs/001-llm-gateway-config/
```

**Solution 3: Clone Repository Fresh**
```bash
# If repository is corrupted
cd ..
git clone <repository-url> claude-code-fresh
cd claude-code-fresh
bash scripts/deploy-gateway-config.sh --preset basic
```

---

## Exit Code 6: Backup Failed

### Description
Cannot create or access backups (backup directory issues, disk space, permissions).

### Common Causes

1. Backup directory permissions
2. Insufficient disk space for backup
3. Corrupted existing backup
4. Disk I/O errors

### Example 1: Cannot Create Backup

```bash
[2/7] Existing deployment found, creating backup...
✗ Backup creation failed

Error: Cannot create backup directory: /home/user/.claude/gateway/backups

Command exited with code 6
```

**Solution**: Fix backup directory permissions
```bash
mkdir -p ~/.claude/gateway/backups
chmod 0700 ~/.claude/gateway/backups
```

### Example 2: No Backups Found (rollback)

```bash
$ bash scripts/deploy-gateway-config.sh rollback latest

==================================
🔙 Rolling back LLM Gateway Configuration
==================================
ℹ Finding latest backup...
✗ No backups found in /home/user/.claude/gateway/backups

Create a backup first by running a deployment:
  deploy-gateway-config.sh --preset basic

Command exited with code 6
```

**Solution**: Deploy first to create a backup
```bash
bash scripts/deploy-gateway-config.sh --preset basic
```

### Example 3: Corrupted Backup (rollback)

```bash
$ bash scripts/deploy-gateway-config.sh rollback gateway-backup-20251202-143022.tar.gz

==================================
🔙 Rolling back LLM Gateway Configuration
==================================
  Backup: gateway-backup-20251202-143022.tar.gz
  Size: 2.3 MB
  Created: 2025-12-02 14:30:22

ℹ Validating backup integrity...
✗ Backup file is corrupted: /home/user/.claude/gateway/backups/gateway-backup-20251202-143022.tar.gz

Command exited with code 6
```

**Solution**: Use different backup or redeploy
```bash
# List all backups
bash scripts/deploy-gateway-config.sh list-backups

# Try another backup
bash scripts/deploy-gateway-config.sh rollback gateway-backup-20251201-162030.tar.gz

# Or redeploy fresh
rm -rf ~/.claude/gateway
bash scripts/deploy-gateway-config.sh --preset basic
```

---

## Troubleshooting Guide

### General Debugging Steps

1. **Check logs**:
   ```bash
   tail -f ~/.claude/gateway/deployment.log
   ```

2. **Verify prerequisites**:
   ```bash
   # Check disk space
   df -h ~
   
   # Check permissions
   ls -la ~/.claude
   
   # Check GCP auth
   gcloud auth application-default print-access-token
   ```

3. **Use dry-run mode**:
   ```bash
   bash scripts/deploy-gateway-config.sh --preset basic --dry-run
   ```

4. **Use verbose mode**:
   ```bash
   bash scripts/deploy-gateway-config.sh --preset basic --verbose
   ```

### Getting Help

**View help message**:
```bash
bash scripts/deploy-gateway-config.sh --help
```

**Check version**:
```bash
bash scripts/deploy-gateway-config.sh --version
```

**List available backups**:
```bash
bash scripts/deploy-gateway-config.sh list-backups
```

### Recovery Procedures

**Complete Reset**:
```bash
# Remove everything
rm -rf ~/.claude/gateway

# Deploy fresh
bash scripts/deploy-gateway-config.sh --preset basic
```

**Restore from Backup**:
```bash
# List backups
bash scripts/deploy-gateway-config.sh list-backups

# Rollback to specific backup
bash scripts/deploy-gateway-config.sh rollback <backup-name>
```

**Manual Validation**:
```bash
# Validate YAML
python3 ~/.claude/gateway/scripts/validate-config.py \
  ~/.claude/gateway/templates/litellm-complete.yaml

# Check file permissions
ls -la ~/.claude/gateway/.env
# Should be: -rw------- (0600)

ls -la ~/.claude/gateway/start-gateway.sh
# Should be: -rwxr-xr-x (0755)
```
