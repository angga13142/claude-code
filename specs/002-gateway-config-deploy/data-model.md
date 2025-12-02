# Data Model: LLM Gateway Configuration Deployment

**Feature**: 002-gateway-config-deploy  
**Date**: 2025-12-02  
**Purpose**: Define entities, relationships, and validation rules for deployment system

---

## Entity Definitions

### 1. DeploymentConfig

**Purpose**: Main configuration entity representing a deployment operation

**Attributes**:

| Field | Type | Required | Validation | Default |
|-------|------|----------|------------|---------|
| `preset` | Enum | Yes | One of: basic, enterprise, multi-provider, proxy | - |
| `models` | Array[String] | No | Must be subset of AVAILABLE_MODELS | All models in preset |
| `source_dir` | Path | Yes | Must exist and be readable | `specs/001-llm-gateway-config` |
| `target_dir` | Path | Yes | Must be writable | `~/.claude/gateway` |
| `gateway_type` | Enum | No | One of: local, truefoundry, zuplo, custom | `local` |
| `gateway_url` | URL | No | Valid HTTP/HTTPS URL | - |
| `auth_token` | String | No | Non-empty string | - |
| `proxy_url` | URL | No | Valid HTTP/HTTPS URL | - |
| `proxy_auth` | String | No | Format: username:password | - |
| `dry_run` | Boolean | No | - | `false` |
| `force` | Boolean | No | - | `false` |
| `verbose` | Boolean | No | - | `false` |

**State Transitions**:

```
CREATED → VALIDATING → BACKING_UP → DEPLOYING → VALIDATING_POST → COMPLETED
                ↓                ↓                 ↓
              FAILED          FAILED           ROLLING_BACK → FAILED
```

**Example**:

```bash
# Bash representation (associative array)
declare -A deployment_config=(
  [preset]="basic"
  [models]="gemini-2.5-flash,gemini-2.5-pro"
  [source_dir]="/home/user/claude-code/specs/001-llm-gateway-config"
  [target_dir]="/home/user/.claude/gateway"
  [gateway_type]="local"
  [dry_run]="false"
  [force]="false"
  [verbose]="true"
)
```

---

### 2. Preset

**Purpose**: Deployment preset configuration template

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Unique preset identifier |
| `description` | String | Yes | User-facing description |
| `template_file` | Path | Yes | Relative path to YAML template in source |
| `default_models` | Array[String] | Yes | Default model list |
| `required_env_vars` | Array[String] | Yes | Required environment variables |
| `optional_env_vars` | Array[String] | No | Optional environment variables |
| `deploy_tests` | Boolean | Yes | Whether to deploy test files |
| `deploy_examples` | Boolean | Yes | Whether to deploy examples |

**Available Presets**:

```bash
# Basic Preset
PRESET_BASIC=(
  [name]="basic"
  [description]="Quick start with all 8 Vertex AI models"
  [template_file]="templates/litellm-complete.yaml"
  [default_models]="gemini-2.5-flash,gemini-2.5-pro,deepseek-r1,llama3-405b,codestral,qwen3-coder-480b,qwen3-235b,gpt-oss-20b"
  [required_env_vars]="LITELLM_MASTER_KEY,GOOGLE_APPLICATION_CREDENTIALS"
  [optional_env_vars]="VERTEX_AI_PROJECT,VERTEX_AI_LOCATION"
  [deploy_tests]="true"
  [deploy_examples]="true"
)

# Enterprise Preset
PRESET_ENTERPRISE=(
  [name]="enterprise"
  [description]="Connect to enterprise gateway (TrueFoundry, Zuplo)"
  [template_file]="templates/enterprise/truefoundry-config.yaml"
  [default_models]=""  # Gateway handles models
  [required_env_vars]="ANTHROPIC_BASE_URL,ANTHROPIC_AUTH_TOKEN"
  [optional_env_vars]="ANTHROPIC_API_VERSION"
  [deploy_tests]="false"
  [deploy_examples]="true"
)

# Multi-Provider Preset
PRESET_MULTI_PROVIDER=(
  [name]="multi-provider"
  [description]="Route to multiple providers (Anthropic, Bedrock, Vertex)"
  [template_file]="templates/multi-provider/multi-provider-config.yaml"
  [default_models]="gemini-2.5-flash,gemini-2.5-pro"  # Vertex models only
  [required_env_vars]="LITELLM_MASTER_KEY,GOOGLE_APPLICATION_CREDENTIALS,ANTHROPIC_API_KEY"
  [optional_env_vars]="AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY,AWS_REGION_NAME"
  [deploy_tests]="true"
  [deploy_examples]="true"
)

# Proxy Preset
PRESET_PROXY=(
  [name]="proxy"
  [description]="Deploy with corporate proxy configuration"
  [template_file]="templates/proxy/proxy-gateway-config.yaml"
  [default_models]="gemini-2.5-flash,gemini-2.5-pro,deepseek-r1,llama3-405b,codestral,qwen3-coder-480b,qwen3-235b,gpt-oss-20b"
  [required_env_vars]="LITELLM_MASTER_KEY,GOOGLE_APPLICATION_CREDENTIALS,HTTPS_PROXY"
  [optional_env_vars]="HTTP_PROXY,NO_PROXY,PROXY_USERNAME,PROXY_PASSWORD"
  [deploy_tests]="true"
  [deploy_examples]="true"
)
```

---

### 3. Model

**Purpose**: Vertex AI model definition

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model_id` | String | Yes | Short identifier (e.g., gemini-2.5-flash) |
| `full_name` | String | Yes | Complete model name |
| `publisher` | String | Yes | Model publisher (google, deepseek-ai, meta, etc.) |
| `litellm_route` | String | Yes | LiteLLM provider route |
| `config_file` | Path | Yes | Path to model YAML config in templates/models/ |
| `priority` | Enum | Yes | P1 (MVP), P2, P3 |
| `description` | String | Yes | Model capabilities |

**Available Models** (from 001 research):

```bash
AVAILABLE_MODELS=(
  "gemini-2.5-flash:Google Gemini 2.5 Flash:google:vertex_ai/gemini-2.5-flash:P1"
  "gemini-2.5-pro:Google Gemini 2.5 Pro:google:vertex_ai/gemini-2.5-pro:P1"
  "deepseek-r1:DeepSeek R1 (Reasoning):deepseek-ai:vertex_ai/deepseek-ai/deepseek-r1-0528-maas:P2"
  "llama3-405b:Meta Llama 3 405B:meta:vertex_ai/meta/llama3-405b-instruct-maas:P2"
  "codestral:Mistral Codestral:mistral:vertex_ai/codestral@latest:P2"
  "qwen3-coder-480b:Qwen 3 Coder 480B:qwen:vertex_ai/qwen/qwen3-coder-480b-a35b-instruct-maas:P3"
  "qwen3-235b:Qwen 3 235B:qwen:vertex_ai/qwen/qwen3-235b-a22b-instruct-2507-maas:P3"
  "gpt-oss-20b:OpenAI GPT-OSS 20B:openai:vertex_ai/openai/gpt-oss-20b-maas:P3"
)

# Parse format: model_id:full_name:publisher:litellm_route:priority
```

---

### 4. BackupMetadata

**Purpose**: Track backup files for rollback operations

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filename` | String | Yes | Backup tar.gz filename |
| `filepath` | Path | Yes | Full path to backup file |
| `created_at` | Timestamp | Yes | Creation timestamp (ISO 8601) |
| `size_bytes` | Integer | Yes | File size in bytes |
| `deployment_config` | JSON | Yes | Serialized DeploymentConfig |
| `sha256_checksum` | String | Yes | File integrity checksum |
| `is_valid` | Boolean | Yes | Validation status |

**Storage**: Stored in `~/.claude/gateway/backups/` directory

**Naming Convention**: `gateway-backup-YYYYMMDD-HHMMSS.tar.gz`

**Example**:

```json
{
  "filename": "gateway-backup-20251202-143022.tar.gz",
  "filepath": "/home/user/.claude/gateway/backups/gateway-backup-20251202-143022.tar.gz",
  "created_at": "2025-12-02T14:30:22Z",
  "size_bytes": 2415820,
  "deployment_config": {
    "preset": "basic",
    "models": ["gemini-2.5-flash", "gemini-2.5-pro"]
  },
  "sha256_checksum": "a3c5e7f9b2d1a8c6e4f7b3d9e1c5a7f9b2d1a8c6e4f7b3d9e1c5a7f9b2d1a8c6",
  "is_valid": true
}
```

**Rotation Policy**: Keep most recent 5 backups, delete older ones

---

### 5. ValidationResult

**Purpose**: Store validation check results

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `check_name` | String | Yes | Name of validation check |
| `status` | Enum | Yes | PASS, FAIL, WARN, SKIP |
| `message` | String | No | Human-readable message |
| `details` | Object | No | Structured validation details |
| `timestamp` | Timestamp | Yes | When check was performed |
| `duration_ms` | Integer | No | Check execution time |

**Validation Phases**:

```bash
# Pre-deployment Validations
PRE_DEPLOYMENT_CHECKS=(
  "source_directory_exists"
  "source_structure_valid"
  "target_directory_writable"
  "disk_space_sufficient"
  "no_litellm_running"
  "required_env_vars_present"
)

# Post-deployment Validations
POST_DEPLOYMENT_CHECKS=(
  "files_copied_count"
  "yaml_config_valid"
  "env_file_permissions"
  "scripts_executable"
  "startup_script_generated"
)

# Optional Runtime Validations
RUNTIME_CHECKS=(
  "gateway_endpoint_reachable"
  "gateway_health_check"
  "models_endpoint_accessible"
  "authentication_successful"
)
```

**Example**:

```json
{
  "check_name": "yaml_config_valid",
  "status": "PASS",
  "message": "YAML configuration validated successfully",
  "details": {
    "config_file": "/home/user/.claude/gateway/config/litellm.yaml",
    "models_found": 2,
    "syntax_errors": 0
  },
  "timestamp": "2025-12-02T14:35:15Z",
  "duration_ms": 245
}
```

---

### 6. EnvironmentVariable

**Purpose**: Environment variable definition and detection

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Variable name (e.g., LITELLM_MASTER_KEY) |
| `value` | String | No | Current value (may be placeholder) |
| `source` | Enum | No | cli, shell, file, placeholder | 
| `required` | Boolean | Yes | Whether variable is required |
| `preset` | String | No | Which preset requires this var |
| `description` | String | Yes | User-facing description |
| `example` | String | No | Example value |
| `is_secret` | Boolean | Yes | Whether value should be masked in logs |

**Detection Priority** (highest to lowest):

1. CLI flags: `--gateway-url`, `--auth-token`
2. Current shell: `$ANTHROPIC_API_KEY`
3. Existing `~/.claude/.env`
4. Shell rc files: `~/.bashrc`, `~/.zshrc`
5. Placeholder: `CHANGE-ME-xxx`

**Example**:

```bash
# Array of EnvironmentVariable structs
ENV_VAR_LITELLM_KEY=(
  [name]="LITELLM_MASTER_KEY"
  [value]=""  # Populated during detection
  [source]="placeholder"
  [required]="true"
  [preset]="basic,multi-provider,proxy"
  [description]="Master key for LiteLLM proxy authentication"
  [example]="sk-1234567890abcdef"
  [is_secret]="true"
)
```

---

### 7. DeploymentLog

**Purpose**: Audit trail of deployment operations

**Attributes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `operation` | Enum | Yes | install, update, rollback |
| `timestamp` | Timestamp | Yes | Operation start time |
| `duration_seconds` | Integer | Yes | Total operation duration |
| `status` | Enum | Yes | success, failed, rolled_back |
| `preset` | String | Yes | Preset used |
| `models_deployed` | Array[String] | No | List of models deployed |
| `files_copied` | Integer | Yes | Number of files copied |
| `backup_created` | String | No | Backup filename if created |
| `error_message` | String | No | Error details if failed |
| `user` | String | Yes | User who performed operation |
| `hostname` | String | Yes | Machine hostname |

**Storage**: Appended to `~/.claude/gateway/deployment.log` (newline-delimited JSON)

**Example**:

```json
{
  "operation": "install",
  "timestamp": "2025-12-02T14:30:00Z",
  "duration_seconds": 7,
  "status": "success",
  "preset": "basic",
  "models_deployed": ["gemini-2.5-flash", "gemini-2.5-pro"],
  "files_copied": 49,
  "backup_created": "gateway-backup-20251202-143022.tar.gz",
  "error_message": null,
  "user": "john",
  "hostname": "developer-laptop"
}
```

---

## Entity Relationships

```
DeploymentConfig
    │
    ├─── uses ────▶ Preset (1:1)
    │                 │
    │                 └─── defines ────▶ Model (1:N)
    │
    ├─── creates ───▶ BackupMetadata (1:N)
    │
    ├─── produces ──▶ ValidationResult (1:N)
    │
    ├─── requires ──▶ EnvironmentVariable (1:N)
    │
    └─── logs ──────▶ DeploymentLog (1:1)
```

**Relationships Explained**:

- **DeploymentConfig → Preset**: Each deployment uses exactly one preset
- **Preset → Model**: Each preset defines default models (0 to 8)
- **DeploymentConfig → BackupMetadata**: Each deployment may create multiple backups over time
- **DeploymentConfig → ValidationResult**: Each deployment produces multiple validation results
- **DeploymentConfig → EnvironmentVariable**: Each deployment requires specific environment variables
- **DeploymentConfig → DeploymentLog**: Each deployment operation creates one log entry

---

## Validation Rules

### DeploymentConfig Validation

```bash
validate_deployment_config() {
  local -n config=$1
  
  # Preset validation
  if [[ ! "${config[preset]}" =~ ^(basic|enterprise|multi-provider|proxy)$ ]]; then
    echo "Invalid preset: ${config[preset]}"
    return 1
  fi
  
  # Model validation (if specified)
  if [[ -n "${config[models]}" ]]; then
    IFS=',' read -ra selected_models <<< "${config[models]}"
    for model in "${selected_models[@]}"; do
      if ! model_exists "$model"; then
        echo "Invalid model: $model. Available: $(list_available_models)"
        return 1
      fi
    done
  fi
  
  # Source directory validation
  if [[ ! -d "${config[source_dir]}" ]]; then
    echo "Source directory not found: ${config[source_dir]}"
    return 1
  fi
  
  # Target directory validation (must be writable)
  if [[ ! -w "$(dirname "${config[target_dir]}")" ]]; then
    echo "Target directory not writable: ${config[target_dir]}"
    return 1
  fi
  
  # Gateway URL validation (if provided)
  if [[ -n "${config[gateway_url]}" ]]; then
    if [[ ! "${config[gateway_url]}" =~ ^https?:// ]]; then
      echo "Invalid gateway URL: ${config[gateway_url]}"
      return 1
    fi
  fi
  
  return 0
}
```

### Preset Validation

```bash
validate_preset() {
  local preset_name=$1
  
  # Check if preset definition exists
  declare -n preset="PRESET_${preset_name^^}"
  
  if [[ -z "${preset[template_file]}" ]]; then
    echo "Preset not found: $preset_name"
    return 1
  fi
  
  # Check if template file exists
  local template_path="${SOURCE_DIR}/${preset[template_file]}"
  if [[ ! -f "$template_path" ]]; then
    echo "Template file not found: $template_path"
    return 1
  fi
  
  return 0
}
```

### Backup Validation

```bash
validate_backup() {
  local backup_file=$1
  
  # Check file exists
  if [[ ! -f "$backup_file" ]]; then
    echo "Backup file not found: $backup_file"
    return 1
  fi
  
  # Validate tar.gz format
  if ! tar -tzf "$backup_file" &>/dev/null; then
    echo "Invalid backup file (corrupt tar.gz): $backup_file"
    return 1
  fi
  
  # Check backup contains expected files
  local required_files=("gateway/config/litellm.yaml" "gateway/.env")
  for file in "${required_files[@]}"; do
    if ! tar -tzf "$backup_file" | grep -q "^$file$"; then
      echo "Backup missing required file: $file"
      return 1
    fi
  done
  
  return 0
}
```

---

## Data Flow

### Deployment Data Flow

```
User Input (CLI args)
    │
    ▼
DeploymentConfig (parse & validate)
    │
    ├─▶ Load Preset definition
    │   └─▶ Validate template files exist
    │
    ├─▶ Detect EnvironmentVariables
    │   └─▶ Merge from CLI, shell, files
    │
    ├─▶ Create BackupMetadata
    │   └─▶ Tar existing ~/.claude/gateway
    │
    ├─▶ Execute Deployment
    │   ├─▶ Copy files (templates, scripts, docs)
    │   ├─▶ Generate .env file
    │   ├─▶ Generate start-gateway.sh
    │   └─▶ Set permissions
    │
    ├─▶ Run ValidationResults
    │   ├─▶ YAML syntax check
    │   ├─▶ File permissions check
    │   └─▶ Optional health check
    │
    └─▶ Write DeploymentLog
        └─▶ Append to deployment.log
```

### Rollback Data Flow

```
User Request (rollback command)
    │
    ▼
List BackupMetadata files
    │
    ▼
Select backup (latest or specific)
    │
    ▼
Validate BackupMetadata
    ├─▶ Check file integrity
    └─▶ Verify tar.gz format
    │
    ▼
Create safety backup (current state)
    │
    ▼
Extract backup to temp directory
    │
    ▼
Atomic swap (mv current → .old, mv temp → current)
    │
    ▼
Run ValidationResults
    │
    └─▶ If failed: restore from safety backup
    │
    ▼
Write DeploymentLog (rollback operation)
```

---

## Storage Schema

### File System Structure

```
~/.claude/
└── gateway/
    ├── config/
    │   └── litellm.yaml           # Active configuration (YAML)
    ├── templates/                 # Reference templates (read-only)
    ├── scripts/                   # Validation scripts (executable)
    ├── docs/                      # Documentation (markdown)
    ├── examples/                  # User story guides (markdown)
    ├── backups/                   # Backup archives (tar.gz)
    │   ├── gateway-backup-*.tar.gz
    │   └── metadata.json          # Optional: BackupMetadata index
    ├── .env                       # Environment variables (KEY=VALUE)
    ├── start-gateway.sh           # Generated startup script (bash)
    └── deployment.log             # Deployment audit trail (JSONL)
```

### deployment.log Format

Newline-delimited JSON (JSONL):

```
{"operation":"install","timestamp":"2025-12-02T14:30:00Z","status":"success",...}
{"operation":"update","timestamp":"2025-12-02T16:45:00Z","status":"success",...}
{"operation":"rollback","timestamp":"2025-12-02T17:10:00Z","status":"success",...}
```

---

## Constraints

### Business Rules

1. **Single Active Deployment**: Only one deployment per user home directory
2. **Backup Rotation**: Maximum 5 backups retained, oldest deleted first
3. **Env Var Preservation**: Existing .env values NEVER overwritten
4. **Atomic Operations**: Deployment either completes fully or rolls back
5. **Preset Immutability**: Preset definitions are read-only after release

### Technical Constraints

1. **File Permissions**: 
   - Directories: 0700 (owner only)
   - .env files: 0600 (owner read/write only)
   - Scripts: 0755 (owner rwx, group/other rx)
   - Configs: 0644 (owner rw, group/other r)

2. **Disk Space**: 
   - Minimum 50MB required
   - Recommended 100MB (includes backups)

3. **Backup Size**: 
   - Typical: 2-3 MB per backup
   - Maximum 5 backups: ~15 MB total

4. **Deployment Time**:
   - Basic preset: 5-8 seconds
   - Enterprise preset: 4-6 seconds
   - Multi-provider: 6-9 seconds
   - Proxy: 5-8 seconds

---

## Future Considerations

### Potential Extensions

1. **Multi-User Support**: Deploy to shared team directory with proper permissions
2. **Version Tracking**: Track 001 source version in deployment metadata
3. **Migration Scripts**: Automatic migration between deployment versions
4. **Remote Source**: Support downloading from GitHub releases
5. **Preset Customization**: Allow users to define custom presets in ~/.claude/presets/
6. **Deployment History**: Web UI for browsing deployment.log with filters
7. **Health Monitoring**: Periodic health checks with alerting
8. **Auto-Updates**: Opt-in automatic updates from upstream source

### Data Model Evolution

- **Backward Compatibility**: New fields must be optional
- **Versioning**: Include `schema_version` in serialized entities
- **Migration Path**: Provide migration scripts for schema changes
