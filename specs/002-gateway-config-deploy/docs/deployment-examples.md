# Deployment Examples

**Feature**: LLM Gateway Configuration Deployment (002-gateway-config-deploy)  
**Purpose**: Real-world deployment examples with expected output

---

## Example 1: Basic Deployment (All Models)

### Command

```bash
bash scripts/deploy-gateway-config.sh --preset basic
```

### Expected Output

```
==================================
🚀 Deploying LLM Gateway Configuration
==================================
  Preset: basic
  Models: All models from preset
  Target: /home/user/.claude/gateway

[1/7] Running pre-deployment validation...
✓ Pre-flight checks passed
✓ GCP credentials found
⚠ Existing deployment found at: /home/user/.claude/gateway
  This will overwrite the current configuration.
  A backup will be created automatically.

Continue with deployment? [y/N]: y

[2/7] Existing deployment found, creating backup...
✓ Created backup: gateway-backup-20251202-143022.tar.gz

[3/7] Creating directory structure...
✓ Directory structure created

[4/7] Copying configuration files...
✓ Copied 49 files successfully

[5/7] Generating environment configuration...
✓ Created .env file with 8 variables

[6/7] Generating startup script...
✓ Created start-gateway.sh

[7/7] Running post-deployment validation...
✓ Post-deployment validation passed

✅ Deployment completed in 7 seconds

Next steps:
  1. Review configuration: vi /home/user/.claude/gateway/config/litellm.yaml
  2. Start gateway: bash /home/user/.claude/gateway/start-gateway.sh
  3. Test connection: claude 'What is 2+2?'

Documentation: /home/user/.claude/gateway/docs/
```

### Files Created

```
~/.claude/gateway/
├── config/
│   └── litellm.yaml
├── templates/
│   ├── litellm-complete.yaml
│   └── models/*.yaml (8 files)
├── scripts/
│   ├── validate-config.py
│   ├── health-check.sh
│   └── ... (15+ scripts)
├── docs/
│   ├── configuration-reference.md
│   └── ... (10+ docs)
├── examples/
│   └── ... (20+ examples)
├── backups/
│   └── gateway-backup-20251202-143022.tar.gz
├── .env (0600 permissions)
└── start-gateway.sh (0755 permissions)
```

---

## Example 2: Custom Model Selection

### Command

```bash
bash scripts/deploy-gateway-config.sh --preset basic --models gemini-2.5-flash,deepseek-r1
```

### Expected Output

```
==================================
🚀 Deploying LLM Gateway Configuration
==================================
  Preset: basic
  Models: gemini-2.5-flash,deepseek-r1 (2 selected)
  Target: /home/user/.claude/gateway

[1/7] Running pre-deployment validation...
ℹ Validating model selection...
✓ Selected 2 model(s): gemini-2.5-flash deepseek-r1
✓ Pre-flight checks passed

[2/7] No existing deployment found, skipping backup

[3/7] Creating directory structure...
ℹ Creating Claude Code home directory: /home/user/.claude
✓ Directory structure created

[4/7] Copying configuration files...
ℹ Merging selected model configurations...
✓ Copied 49 files successfully

[5/7] Generating environment configuration...
✓ Created .env file with 8 variables

[6/7] Generating startup script...
✓ Created start-gateway.sh

[7/7] Running post-deployment validation...
✓ Post-deployment validation passed

✅ Deployment completed in 5 seconds

Next steps:
  1. Review configuration: vi /home/user/.claude/gateway/config/litellm.yaml
  2. Start gateway: bash /home/user/.claude/gateway/start-gateway.sh
  3. Test connection: claude 'What is 2+2?'

Documentation: /home/user/.claude/gateway/docs/
```

---

## Example 3: Dry Run Preview

### Command

```bash
bash scripts/deploy-gateway-config.sh --preset basic --dry-run
```

### Expected Output

```
==================================
🚀 Deploying LLM Gateway Configuration
==================================
  Preset: basic
  Models: All models from preset
  Target: /home/user/.claude/gateway


==================================
🔍 DRY RUN - Deployment Preview
==================================

No changes will be made to your system

Configuration:
  Preset                    : basic
  Models                    : all models
  Source Directory          : /path/to/specs/001-llm-gateway-config
  Target Directory          : /home/user/.claude/gateway

Actions that would be performed:

  1. ✓ Validate source directory and disk space
  2. ✓ Create backup of existing deployment (if exists)
  3. ✓ Create directory structure:
       - config/
       - templates/
       - scripts/
       - docs/
       - examples/
       - backups/
  4. ✓ Copy template files and documentation
  5. ✓ Generate environment configuration (.env)
  6. ✓ Generate startup script (start-gateway.sh)
  7. ✓ Validate deployment integrity

Files that would be created/updated:
  /home/user/.claude/gateway/config/litellm.yaml
  /home/user/.claude/gateway/.env (with secure 0600 permissions)
  /home/user/.claude/gateway/start-gateway.sh (executable)
  /home/user/.claude/gateway/templates/ (all YAML templates)
  /home/user/.claude/gateway/scripts/ (validation and management scripts)
  /home/user/.claude/gateway/docs/ (configuration documentation)
  /home/user/.claude/gateway/examples/ (user story guides)

To execute this deployment, run the same command without --dry-run
```

---

## Example 4: List Backups

### Command

```bash
bash scripts/deploy-gateway-config.sh list-backups
```

### Expected Output

```
==================================
📦 Available Backups
==================================

Backup File                                      Size         Created               Status
====================================================================================================
  1.  gateway-backup-20251202-143022.tar.gz     2.3 MB       2025-12-02 14:30      ✓ Valid
  2.  gateway-backup-20251202-105045.tar.gz     2.1 MB       2025-12-02 10:50      ✓ Valid
  3.  gateway-backup-20251201-162030.tar.gz     2.0 MB       2025-12-01 16:20      ✓ Valid

Total: 3 backup(s) (6 MB)

Rollback examples:
  deploy-gateway-config.sh rollback latest
  deploy-gateway-config.sh rollback gateway-backup-20251202-143022.tar.gz
```

---

## Example 5: Rollback to Previous Configuration

### Command

```bash
bash scripts/deploy-gateway-config.sh rollback latest
```

### Expected Output

```
==================================
🔙 Rolling back LLM Gateway Configuration
==================================
ℹ Finding latest backup...
ℹ Using latest backup: gateway-backup-20251202-143022.tar.gz

  Backup: gateway-backup-20251202-143022.tar.gz
  Size: 2.3 MB
  Created: 2025-12-02 14:30:22

ℹ Validating backup integrity...
✓ Backup integrity verified

⚠ This will overwrite current configuration
  A safety backup will be created first

Continue with rollback? [y/N]: y

ℹ Rolling back configuration...
✓ Configuration restored successfully
ℹ Validating restored configuration...
✓ Configuration validation passed

✅ Rollback completed successfully

Next steps:
  1. Review configuration: vi /home/user/.claude/gateway/config/litellm.yaml
  2. Restart gateway: bash /home/user/.claude/gateway/start-gateway.sh
```

---

## Example 6: Enterprise Gateway Deployment

### Command

```bash
bash scripts/deploy-gateway-config.sh --preset enterprise \
  --gateway-url https://gateway.company.com \
  --auth-token sk-xxx
```

### Expected Output

```
==================================
🚀 Deploying LLM Gateway Configuration
==================================
  Preset: enterprise
  Gateway URL: https://gateway.company.com
  Target: /home/user/.claude/gateway

[1/6] Running pre-deployment validation...
✓ Pre-flight checks passed
✓ Gateway URL validated

[2/6] No existing deployment found, skipping backup

[3/6] Creating directory structure...
✓ Directory structure created

[4/6] Copying enterprise templates...
✓ Copied 35 files successfully

[5/6] Updating Claude Code settings...
✓ Updated ~/.claude/settings.json with gateway endpoint

[6/6] Running post-deployment validation...
✓ Post-deployment validation passed

✅ Deployment completed in 4 seconds

Next steps:
  1. Verify settings: cat ~/.claude/settings.json
  2. Test gateway: curl https://gateway.company.com/health
  3. Use Claude Code with enterprise gateway

Documentation: /home/user/.claude/gateway/docs/
```

---

## Example 7: Update Existing Deployment

### Command

```bash
bash scripts/deploy-gateway-config.sh update --models gemini-2.5-pro
```

### Expected Output

```
==================================
🔄 Updating LLM Gateway Configuration
==================================
  Target: /home/user/.claude/gateway
  Models to update: gemini-2.5-pro (1 selected)

[1/7] Running pre-deployment validation...
✓ Pre-flight checks passed

[2/7] Creating incremental backup...
✓ Created backup: gateway-backup-20251202-164530.tar.gz

[3/7] Preserving user customizations...
✓ Custom .env variables preserved

[4/7] Updating configuration files...
✓ Updated configuration with new models

[5/7] Merging model configurations...
✓ Model configurations merged successfully

[6/7] Running post-deployment validation...
✓ Post-deployment validation passed

✅ Update completed in 3 seconds

Changes:
  + Added 1 model: gemini-2.5-pro
  = Preserved: custom .env settings, deployment.log

Restart gateway: bash /home/user/.claude/gateway/start-gateway.sh
```

---

## Tips for Successful Deployments

### Pre-Deployment Checklist

1. **Authenticate with GCP**:
   ```bash
   gcloud auth application-default login
   ```

2. **Check disk space**:
   ```bash
   df -h ~
   # Need at least 50 MB free
   ```

3. **Stop existing gateway** (if running):
   ```bash
   pkill -f litellm
   ```

### Common Deployment Patterns

**Development Setup**:
```bash
# Quick start with 2 fast models
bash scripts/deploy-gateway-config.sh --preset basic \
  --models gemini-2.5-flash,gemini-2.0-flash-exp
```

**Production Setup**:
```bash
# All models with automatic backup
bash scripts/deploy-gateway-config.sh --preset basic
```

**CI/CD Deployment**:
```bash
# Non-interactive mode
bash scripts/deploy-gateway-config.sh --preset basic --force
```

**Preview Before Deploy**:
```bash
# Check what will happen
bash scripts/deploy-gateway-config.sh --preset basic --dry-run
```

### After Deployment

1. **Verify configuration**:
   ```bash
   python3 ~/.claude/gateway/scripts/validate-config.py \
     ~/.claude/gateway/templates/litellm-complete.yaml
   ```

2. **Start gateway**:
   ```bash
   bash ~/.claude/gateway/start-gateway.sh
   ```

3. **Test endpoint**:
   ```bash
   curl http://localhost:4000/health
   ```

4. **Check logs**:
   ```bash
   tail -f ~/.claude/gateway/deployment.log
   ```
