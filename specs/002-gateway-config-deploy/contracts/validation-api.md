# Validation API Contract

**Feature**: 002-gateway-config-deploy  
**Date**: 2025-12-02  
**Purpose**: Define validation interface contracts for deployment operations

---

## Overview

The deployment tool uses multi-layer validation to ensure safe, successful deployments. This contract defines the validation API, check types, and result formats.

---

## Validation Phases

### 1. Pre-Deployment Validation

**Purpose**: Verify prerequisites before any filesystem changes

**Function Signature** (Bash):
```bash
validate_pre_deployment() {
  local -n config=$1
  local -n results=$2  # Output: array of ValidationResult
  
  # Returns: 0 if all checks pass, 1 if any fail
}
```

**Checks**:

| Check Name | Type | Failure Impact | Description |
|------------|------|----------------|-------------|
| `source_directory_exists` | CRITICAL | Block deployment | Source dir must exist |
| `source_structure_valid` | CRITICAL | Block deployment | Required files present |
| `target_directory_writable` | CRITICAL | Block deployment | Can write to target |
| `disk_space_sufficient` | CRITICAL | Block deployment | 50MB+ available |
| `preset_valid` | CRITICAL | Block deployment | Preset name recognized |
| `models_valid` | CRITICAL | Block deployment | Model names recognized |
| `gateway_url_valid` | WARNING | Allow with warning | URL format correct |
| `litellm_not_running` | WARNING | Allow with warning | No process conflicts |
| `env_vars_present` | INFO | Continue | Detect available env vars |

**Example**:
```bash
declare -A deployment_config=(
  [preset]="basic"
  [source_dir]="/path/to/specs/001-llm-gateway-config"
  [target_dir]="$HOME/.claude/gateway"
)

declare -a validation_results=()

if validate_pre_deployment deployment_config validation_results; then
  echo "Pre-flight checks passed"
else
  echo "Validation failed:"
  print_validation_results validation_results
  exit 1
fi
```

---

### 2. Post-Deployment Validation

**Purpose**: Verify deployment completed successfully

**Function Signature** (Bash):
```bash
validate_post_deployment() {
  local target_dir=$1
  local preset=$2
  local -n results=$3  # Output: array of ValidationResult
  
  # Returns: 0 if all checks pass, 1 if any fail
}
```

**Checks**:

| Check Name | Type | Failure Impact | Description |
|------------|------|----------------|-------------|
| `files_copied_count` | CRITICAL | Rollback | Expected file count matches |
| `yaml_config_valid` | CRITICAL | Rollback | YAML syntax correct |
| `yaml_config_semantic` | CRITICAL | Rollback | Config semantics valid |
| `env_file_exists` | CRITICAL | Rollback | .env file created |
| `env_file_permissions` | CRITICAL | Rollback | .env is 0600 |
| `scripts_executable` | WARNING | Continue | Scripts have +x |
| `startup_script_generated` | CRITICAL | Rollback | start-gateway.sh exists |
| `backup_created` | INFO | Continue | Backup file created |

**Example**:
```bash
declare -a post_results=()

if validate_post_deployment "$HOME/.claude/gateway" "basic" post_results; then
  echo "Deployment validated successfully"
else
  echo "Post-deployment validation failed - rolling back"
  rollback_deployment
  exit 1
fi
```

---

### 3. Runtime Health Check (Optional)

**Purpose**: Verify gateway is operational (if URL provided)

**Function Signature** (Bash):
```bash
validate_gateway_health() {
  local gateway_url=$1
  local timeout=${2:-30}  # Timeout in seconds
  local -n results=$3
  
  # Returns: 0 if healthy, 1 if unhealthy
}
```

**Checks**:

| Check Name | Type | Timeout | Description |
|------------|------|---------|-------------|
| `endpoint_reachable` | CRITICAL | 5s | HTTP connection succeeds |
| `health_endpoint_200` | CRITICAL | 5s | /health returns 200 |
| `health_status_healthy` | CRITICAL | - | JSON status: "healthy" |
| `models_endpoint_accessible` | WARNING | 10s | /models returns 200 |
| `models_list_non_empty` | WARNING | - | At least 1 model listed |
| `auth_successful` | WARNING | 5s | Token accepted (if provided) |

**Example**:
```bash
# Only run if gateway URL provided
if [[ -n "${deployment_config[gateway_url]}" ]]; then
  declare -a health_results=()
  
  if validate_gateway_health "${deployment_config[gateway_url]}" 30 health_results; then
    echo "Gateway health check passed"
  else
    echo "Gateway health check failed (deployment still succeeded)"
    print_validation_results health_results
  fi
fi
```

---

## ValidationResult Structure

**Format** (Bash associative array):
```bash
declare -A validation_result=(
  [check_name]="yaml_config_valid"
  [status]="PASS"              # PASS, FAIL, WARN, SKIP, INFO
  [message]="YAML configuration validated successfully"
  [details]="config_file=/home/user/.claude/gateway/config/litellm.yaml;models_found=2;syntax_errors=0"
  [timestamp]="2025-12-02T14:35:15Z"
  [duration_ms]="245"
)
```

**Status Levels**:

| Status | Meaning | Deployment Impact | Color |
|--------|---------|-------------------|-------|
| `PASS` | Check succeeded | Continue | Green |
| `FAIL` | Check failed (critical) | Block/rollback | Red |
| `WARN` | Check failed (non-critical) | Continue with warning | Yellow |
| `SKIP` | Check not applicable | Continue | Gray |
| `INFO` | Informational only | Continue | Blue |

---

## Validation Functions

### Core Validation Functions

#### validate_source_directory()

```bash
validate_source_directory() {
  local source_dir=$1
  local -n result=$2
  
  result[check_name]="source_directory_exists"
  result[timestamp]="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  local start_ms=$(date +%s%3N)
  
  if [[ ! -d "$source_dir" ]]; then
    result[status]="FAIL"
    result[message]="Source directory not found: $source_dir"
    result[details]="expected_path=$source_dir"
  elif [[ ! -r "$source_dir" ]]; then
    result[status]="FAIL"
    result[message]="Source directory not readable: $source_dir"
    result[details]="permission_denied=true"
  else
    result[status]="PASS"
    result[message]="Source directory exists and is readable"
    result[details]="path=$source_dir"
  fi
  
  local end_ms=$(date +%s%3N)
  result[duration_ms]=$((end_ms - start_ms))
  
  [[ "${result[status]}" == "PASS" ]]
}
```

#### validate_yaml_config()

```bash
validate_yaml_config() {
  local config_file=$1
  local -n result=$2
  
  result[check_name]="yaml_config_valid"
  result[timestamp]="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  local start_ms=$(date +%s%3N)
  
  # Use Python script from 001 implementation
  local validation_output
  if validation_output=$(python3 "$SCRIPTS_DIR/validate-config.py" "$config_file" 2>&1); then
    result[status]="PASS"
    result[message]="YAML configuration validated successfully"
    result[details]="config_file=$config_file;validation_output=$validation_output"
  else
    result[status]="FAIL"
    result[message]="YAML validation failed"
    result[details]="config_file=$config_file;error=$validation_output"
  fi
  
  local end_ms=$(date +%s%3N)
  result[duration_ms]=$((end_ms - start_ms))
  
  [[ "${result[status]}" == "PASS" ]]
}
```

#### validate_disk_space()

```bash
validate_disk_space() {
  local target_dir=$1
  local required_mb=${2:-50}  # Default 50 MB
  local -n result=$3
  
  result[check_name]="disk_space_sufficient"
  result[timestamp]="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  local start_ms=$(date +%s%3N)
  
  local available_kb=$(df -k "$(dirname "$target_dir")" | awk 'NR==2 {print $4}')
  local available_mb=$((available_kb / 1024))
  
  if [[ $available_mb -ge $required_mb ]]; then
    result[status]="PASS"
    result[message]="Sufficient disk space available"
    result[details]="available_mb=$available_mb;required_mb=$required_mb"
  else
    result[status]="FAIL"
    result[message]="Insufficient disk space"
    result[details]="available_mb=$available_mb;required_mb=$required_mb;shortage_mb=$((required_mb - available_mb))"
  fi
  
  local end_ms=$(date +%s%3N)
  result[duration_ms]=$((end_ms - start_ms))
  
  [[ "${result[status]}" == "PASS" ]]
}
```

#### validate_file_permissions()

```bash
validate_file_permissions() {
  local file=$1
  local expected_perms=$2  # e.g., "0600"
  local -n result=$3
  
  result[check_name]="file_permissions_${file##*/}"
  result[timestamp]="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  local start_ms=$(date +%s%3N)
  
  if [[ ! -e "$file" ]]; then
    result[status]="FAIL"
    result[message]="File not found: $file"
    result[details]="expected_file=$file"
  else
    local actual_perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Mp%Lp" "$file")
    
    if [[ "$actual_perms" == "$expected_perms" ]]; then
      result[status]="PASS"
      result[message]="File permissions correct"
      result[details]="file=$file;perms=$actual_perms"
    else
      result[status]="FAIL"
      result[message]="Incorrect file permissions"
      result[details]="file=$file;expected=$expected_perms;actual=$actual_perms"
    fi
  fi
  
  local end_ms=$(date +%s%3N)
  result[duration_ms]=$((end_ms - start_ms))
  
  [[ "${result[status]}" == "PASS" ]]
}
```

---

## Validation Result Display

### print_validation_results()

```bash
print_validation_results() {
  local -n results=$1
  local show_all=${2:-false}  # Show only failures by default
  
  echo "Validation Results:"
  echo "==================="
  
  local pass_count=0
  local fail_count=0
  local warn_count=0
  
  for result_json in "${results[@]}"; do
    local -A result
    parse_result_json "$result_json" result
    
    local status="${result[status]}"
    local symbol color
    
    case "$status" in
      PASS)
        symbol="✓"
        color="\033[32m"  # Green
        ((pass_count++))
        [[ "$show_all" == "true" ]] || continue
        ;;
      FAIL)
        symbol="✗"
        color="\033[31m"  # Red
        ((fail_count++))
        ;;
      WARN)
        symbol="⚠"
        color="\033[33m"  # Yellow
        ((warn_count++))
        ;;
      INFO)
        symbol="ℹ"
        color="\033[34m"  # Blue
        [[ "$show_all" == "true" ]] || continue
        ;;
      SKIP)
        symbol="○"
        color="\033[90m"  # Gray
        [[ "$show_all" == "true" ]] || continue
        ;;
    esac
    
    echo -e "  ${color}${symbol} ${result[check_name]}\033[0m"
    echo "    ${result[message]}"
    
    if [[ -n "${result[duration_ms]}" ]]; then
      echo "    Duration: ${result[duration_ms]}ms"
    fi
  done
  
  echo ""
  echo "Summary: $pass_count passed, $fail_count failed, $warn_count warnings"
  
  [[ $fail_count -eq 0 ]]
}
```

---

## Integration with Deployment Script

### Validation Workflow

```bash
#!/bin/bash
# deploy-gateway-config.sh validation integration

main() {
  local -A deployment_config
  parse_arguments "$@" deployment_config
  
  # Phase 1: Pre-deployment validation
  local -a pre_results=()
  echo "⏳ Running pre-deployment checks..."
  
  if ! validate_pre_deployment deployment_config pre_results; then
    print_validation_results pre_results
    echo "❌ Pre-deployment validation failed"
    exit 4
  fi
  
  print_validation_results pre_results
  echo "✓ Pre-deployment validation passed"
  
  # Phase 2: Create backup
  local backup_file
  create_backup "${deployment_config[target_dir]}" backup_file
  
  # Phase 3: Execute deployment
  execute_deployment deployment_config
  
  # Phase 4: Post-deployment validation
  local -a post_results=()
  echo "⏳ Running post-deployment checks..."
  
  if ! validate_post_deployment \
    "${deployment_config[target_dir]}" \
    "${deployment_config[preset]}" \
    post_results; then
    
    print_validation_results post_results
    echo "❌ Post-deployment validation failed - rolling back"
    rollback_from_backup "$backup_file"
    exit 4
  fi
  
  print_validation_results post_results
  echo "✓ Post-deployment validation passed"
  
  # Phase 5: Optional runtime health check
  if [[ -n "${deployment_config[gateway_url]}" ]]; then
    local -a health_results=()
    echo "⏳ Running gateway health check..."
    
    if validate_gateway_health \
      "${deployment_config[gateway_url]}" \
      30 \
      health_results; then
      print_validation_results health_results
      echo "✓ Gateway health check passed"
    else
      print_validation_results health_results
      echo "⚠️  Gateway health check failed (deployment still succeeded)"
    fi
  fi
  
  echo "✅ Deployment completed successfully"
}
```

---

## Error Codes

Validation functions return these exit codes:

| Code | Meaning | Usage |
|------|---------|-------|
| `0` | All checks passed | Continue deployment |
| `1` | At least one FAIL status | Block/rollback deployment |
| `2` | Validation script error | Internal error, abort |

---

## Testing Contract

### Validation Function Tests

Each validation function MUST have tests covering:

1. **Success case**: Valid input returns PASS
2. **Failure case**: Invalid input returns FAIL
3. **Edge cases**: Empty strings, null values, boundary conditions
4. **Performance**: Completes within expected time (<1s for unit checks)

**Example Test** (BATS):

```bash
@test "validate_disk_space: passes with sufficient space" {
  local -A result
  local target_dir=$(mktemp -d)
  
  validate_disk_space "$target_dir" 1 result  # Require only 1 MB
  
  [[ "${result[status]}" == "PASS" ]]
  [[ "${result[check_name]}" == "disk_space_sufficient" ]]
  [[ -n "${result[duration_ms]}" ]]
  
  rm -rf "$target_dir"
}

@test "validate_disk_space: fails with insufficient space" {
  local -A result
  local target_dir=$(mktemp -d)
  
  validate_disk_space "$target_dir" 999999999 result  # Require 1 TB
  
  [[ "${result[status]}" == "FAIL" ]]
  [[ "${result[message]}" == *"Insufficient disk space"* ]]
  
  rm -rf "$target_dir"
}
```

---

## Performance Requirements

| Validation Phase | Max Duration | Target Duration |
|------------------|--------------|-----------------|
| Pre-deployment | 5 seconds | 2 seconds |
| Post-deployment | 10 seconds | 5 seconds |
| Runtime health check | 30 seconds | 10 seconds |
| Individual check | 1 second | 200ms |

---

## Future Enhancements

1. **Parallel Validation**: Run independent checks concurrently
2. **Caching**: Cache validation results within single run
3. **Validation Profiles**: Quick vs thorough validation modes
4. **Remote Validation**: Validate gateway availability before deployment
5. **Validation Reports**: Generate HTML/JSON validation reports
