# Research Report: Gateway Configuration Deployment

**Feature**: 002-gateway-config-deploy  
**Date**: 2025-12-02  
**Phase**: Phase 0 - Research & Requirements Clarification

## Research Questions & Findings

### 1. Bash Best Practices for Deployment Scripts

**Question**: What are the essential bash patterns for safe, maintainable deployment automation?

**Research Findings**:

**Error Handling**:
```bash
# Always use strict mode
set -euo pipefail
# -e: Exit on error
# -u: Treat unset variables as error
# -o pipefail: Fail on pipe errors

# Trap cleanup on exit
trap cleanup EXIT ERR INT TERM

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Error occurred, rolling back..." >&2
        rollback_deployment
    fi
}
```

**File Operations Safety**:
```bash
# Atomic file operations (write to temp, then move)
temp_file=$(mktemp)
generate_config > "$temp_file"
validate_config "$temp_file" || { rm "$temp_file"; return 1; }
mv "$temp_file" "$target_file"

# Always quote variables to handle spaces
cp "$source_file" "$destination_file"

# Check file existence before operations
if [ -f "$config_file" ]; then
    # Safe to operate
fi
```

**User Input Validation**:
```bash
# Validate model names against whitelist
validate_model_name() {
    local model="$1"
    local valid_models=(
        "gemini-2.5-flash" "gemini-2.5-pro" "deepseek-r1"
        "llama3-405b" "codestral" "qwen3-coder-480b"
        "qwen3-235b" "gpt-oss-20b"
    )
    
    for valid in "${valid_models[@]}"; do
        if [ "$model" = "$valid" ]; then
            return 0
        fi
    done
    return 1
}

# Sanitize URLs (prevent injection)
sanitize_url() {
    local url="$1"
    # Remove dangerous protocols
    if [[ "$url" =~ ^(file|javascript|data): ]]; then
        echo "Invalid URL protocol" >&2
        return 1
    fi
    echo "$url"
}
```

**Decision**: Use strict mode (`set -euo pipefail`), atomic file operations (write to temp), comprehensive input validation, and trap-based cleanup.

**Rationale**: Prevents partial deployments, handles errors gracefully, protects against user input issues.

---

### 2. Backup Strategies: tar vs rsync

**Question**: What's the best backup method for ~/.claude/gateway/ directory?

**Comparison**:

| Feature | tar + gzip | rsync |
|---------|-----------|-------|
| Compression | ✅ Built-in | ❌ Requires external |
| Incremental | ❌ Full backup each time | ✅ Only changed files |
| Atomic | ✅ Single archive file | ❌ Multiple files |
| Speed (small dirs) | ✅ Fast (~1s) | ⚠️ Overhead (~2s) |
| Restoration | ✅ Simple extract | ⚠️ Need to track state |
| Integrity Check | ✅ gzip -t | ⚠️ Manual checksums |

**Recommendation**: Use `tar + gzip` for this use case

**Rationale**:
- ~/.claude/gateway/ is small (<10MB typically)
- Atomic backup (single .tar.gz file)
- Simple restoration (single extract command)
- Built-in integrity checking
- No incremental backup needed (full backup is fast)

**Implementation**:
```bash
backup_deployment() {
    local backup_dir="$HOME/.claude/gateway/backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$backup_dir/gateway-backup-$timestamp.tar.gz"
    
    mkdir -p "$backup_dir"
    
    # Create backup excluding sensitive files by default
    tar -czf "$backup_file" \
        --exclude='*.log' \
        --exclude='backups' \
        -C "$HOME/.claude" \
        gateway/
    
    # Verify backup integrity
    if gzip -t "$backup_file" 2>/dev/null; then
        echo "$backup_file"
        return 0
    else
        rm "$backup_file"
        return 1
    fi
}

restore_backup() {
    local backup_file="$1"
    
    # Verify integrity before restore
    gzip -t "$backup_file" || return 1
    
    # Extract to temp location first
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Validate extracted config
    python3 specs/001-llm-gateway-config/scripts/validate-config.py \
        "$temp_dir/gateway/litellm_config.yaml" || {
        rm -rf "$temp_dir"
        return 1
    }
    
    # Atomic move
    rm -rf "$HOME/.claude/gateway"
    mv "$temp_dir/gateway" "$HOME/.claude/"
    rm -rf "$temp_dir"
}
```

**Backup Rotation Strategy**:
```bash
# Keep last 5 backups, delete older
rotate_backups() {
    local backup_dir="$HOME/.claude/gateway/backups"
    local keep_count=5
    
    # List backups sorted by date (oldest first)
    local backups=($(ls -1t "$backup_dir"/gateway-backup-*.tar.gz 2>/dev/null))
    local count=${#backups[@]}
    
    if [ $count -gt $keep_count ]; then
        # Delete oldest backups
        for ((i=$keep_count; i<$count; i++)); do
            rm "${backups[$i]}"
        done
    fi
}
```

**Decision**: Use tar + gzip with 5-backup rotation policy.

---

### 3. Settings.json Manipulation with jq

**Question**: How to safely update Claude Code settings.json without corruption?

**Research Findings**:

**jq Basics for Settings Update**:
```bash
# Read current value
current_url=$(jq -r '.ANTHROPIC_BASE_URL // "none"' ~/.claude/settings.json)

# Update single field
jq '.ANTHROPIC_BASE_URL = "http://localhost:4000"' \
    ~/.claude/settings.json > ~/.claude/settings.json.tmp && \
    mv ~/.claude/settings.json.tmp ~/.claude/settings.json

# Update multiple fields atomically
jq '. + {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "CLAUDE_CODE_SKIP_VERTEX_AUTH": true
}' ~/.claude/settings.json > ~/.claude/settings.json.tmp && \
    mv ~/.claude/settings.json.tmp ~/.claude/settings.json

# Create if doesn't exist
if [ ! -f ~/.claude/settings.json ]; then
    echo '{}' > ~/.claude/settings.json
fi
```

**Safe Update Pattern**:
```bash
update_claude_settings() {
    local gateway_url="$1"
    local settings_file="$HOME/.claude/settings.json"
    local backup_file="$settings_file.backup"
    local temp_file=$(mktemp)
    
    # Create empty file if doesn't exist
    if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
    fi
    
    # Backup current settings
    cp "$settings_file" "$backup_file"
    
    # Update with jq
    jq --arg url "$gateway_url" '. + {
        "ANTHROPIC_BASE_URL": $url,
        "CLAUDE_CODE_SKIP_VERTEX_AUTH": true
    }' "$settings_file" > "$temp_file"
    
    # Validate JSON syntax
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$settings_file"
        rm "$backup_file"
        return 0
    else
        # Restore backup on error
        mv "$backup_file" "$settings_file"
        rm "$temp_file"
        return 1
    fi
}
```

**Edge Cases Handled**:
1. Settings.json doesn't exist → Create with `{}`
2. Settings.json is empty → Treat as `{}`
3. Settings.json is invalid JSON → Fail and report error
4. jq command fails → Restore from backup
5. Multiple updates in sequence → Use single jq command

**Decision**: Use jq with atomic update pattern (backup → update to temp → validate → move).

**Rationale**: jq is standard JSON processor, atomic operations prevent corruption, validation catches errors before committing.

---

### 4. Environment Variable Detection

**Question**: How to reliably detect environment variables across different shell configurations?

**Research Findings**:

**Source Precedence** (highest to lowest):
1. Current shell environment (already exported)
2. ~/.claude/.env (user-specific Claude config)
3. ~/.bashrc or ~/.zshrc (shell profile)
4. ~/.profile (POSIX fallback)
5. gcloud CLI configuration (for GCP variables)

**Detection Strategy**:
```bash
detect_env_var() {
    local var_name="$1"
    local value=""
    
    # 1. Check current environment
    if [ -n "${!var_name:-}" ]; then
        value="${!var_name}"
        echo "$value"
        return 0
    fi
    
    # 2. Check ~/.claude/.env
    if [ -f "$HOME/.claude/.env" ]; then
        value=$(grep "^${var_name}=" "$HOME/.claude/.env" | cut -d'=' -f2- | tr -d '"'"'"')
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    
    # 3. Check shell profile
    local profile_file=""
    if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
        profile_file="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.zshrc" ]; then
        profile_file="$HOME/.zshrc"
    elif [ -f "$HOME/.profile" ]; then
        profile_file="$HOME/.profile"
    fi
    
    if [ -n "$profile_file" ]; then
        # Extract export or direct assignment
        value=$(grep -E "^export ${var_name}=|^${var_name}=" "$profile_file" | \
                tail -1 | sed "s/^export ${var_name}=//;s/^${var_name}=//" | \
                tr -d '"'"'"')
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    
    # 4. GCP-specific detection
    if [ "$var_name" = "VERTEX_PROJECT" ] || [ "$var_name" = "GOOGLE_CLOUD_PROJECT" ]; then
        value=$(gcloud config get-value project 2>/dev/null)
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    
    if [ "$var_name" = "GOOGLE_APPLICATION_CREDENTIALS" ]; then
        # Check gcloud default credentials path
        local default_creds="$HOME/.config/gcloud/application_default_credentials.json"
        if [ -f "$default_creds" ]; then
            echo "$default_creds"
            return 0
        fi
    fi
    
    # Not found
    return 1
}

# Auto-detect all required variables
auto_detect_environment() {
    local vars=(
        "VERTEX_PROJECT"
        "VERTEX_LOCATION"
        "GOOGLE_APPLICATION_CREDENTIALS"
        "LITELLM_MASTER_KEY"
    )
    
    declare -A detected
    local all_found=true
    
    for var in "${vars[@]}"; do
        if value=$(detect_env_var "$var"); then
            detected[$var]="$value"
            echo "✓ $var: ${value:0:50}..." >&2
        else
            detected[$var]=""
            all_found=false
            echo "⚠ $var: not found" >&2
        fi
    done
    
    # Return as JSON for easy parsing
    printf '{'
    local first=true
    for var in "${vars[@]}"; do
        [ "$first" = true ] && first=false || printf ','
        printf '"%s":"%s"' "$var" "${detected[$var]}"
    done
    printf '}\n'
    
    [ "$all_found" = true ]
}
```

**Special Cases**:

**LITELLM_MASTER_KEY Generation**:
```bash
generate_master_key() {
    # Generate secure random key if not found
    if ! key=$(detect_env_var "LITELLM_MASTER_KEY"); then
        key="sk-$(openssl rand -hex 16)"
        echo "Generated new LITELLM_MASTER_KEY: $key" >&2
    fi
    echo "$key"
}
```

**VERTEX_LOCATION Default**:
```bash
get_vertex_location() {
    local location=$(detect_env_var "VERTEX_LOCATION")
    if [ -z "$location" ]; then
        # Default to us-central1
        location="us-central1"
        echo "Using default VERTEX_LOCATION: $location" >&2
    fi
    echo "$location"
}
```

**Decision**: Implement multi-source detection with precedence, auto-generate LITELLM_MASTER_KEY if missing.

**Rationale**: Users may configure environment variables in different places, detection should check all common locations.

---

### 5. Cross-Platform Compatibility (macOS vs Linux)

**Question**: What are the key differences between macOS and Linux that affect deployment?

**Research Findings**:

**Command Differences**:

| Feature | macOS | Linux | Solution |
|---------|-------|-------|----------|
| sed in-place | `sed -i ''` | `sed -i` | Feature detection |
| readlink absolute | `greadlink -f` (GNU) | `readlink -f` | Use `realpath` or fallback |
| mktemp dir | `mktemp -d` | `mktemp -d` | ✅ Same |
| stat format | `stat -f %Sp` | `stat -c %a` | Feature detection |
| jq | Usually installed | May need install | Check and prompt |

**Platform Detection**:
```bash
detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

# Portable sed in-place
sed_inplace() {
    local file="$1"
    shift
    local sed_args=("$@")
    
    if [ "$(detect_platform)" = "macos" ]; then
        sed -i '' "${sed_args[@]}" "$file"
    else
        sed -i "${sed_args[@]}" "$file"
    fi
}

# Portable absolute path
get_absolute_path() {
    local path="$1"
    
    # Try realpath first (available on both if coreutils installed)
    if command -v realpath &>/dev/null; then
        realpath "$path"
        return
    fi
    
    # Fallback: readlink
    if [ "$(detect_platform)" = "macos" ]; then
        # macOS needs GNU coreutils for -f
        if command -v greadlink &>/dev/null; then
            greadlink -f "$path"
        else
            # Manual resolution
            ( cd "$(dirname "$path")" && pwd )/$(basename "$path")
        fi
    else
        readlink -f "$path"
    fi
}

# Portable file permissions check
get_file_permissions() {
    local file="$1"
    
    if [ "$(detect_platform)" = "macos" ]; then
        stat -f "%OLp" "$file"
    else
        stat -c "%a" "$file"
    fi
}
```

**Testing Strategy**:
```bash
# Run platform-specific tests
run_compatibility_tests() {
    local platform=$(detect_platform)
    
    echo "Testing on $platform..."
    
    # Test sed
    local temp_file=$(mktemp)
    echo "test" > "$temp_file"
    sed_inplace "$temp_file" 's/test/pass/'
    [ "$(cat "$temp_file")" = "pass" ] || { echo "sed test failed"; return 1; }
    rm "$temp_file"
    
    # Test path resolution
    local abs_path=$(get_absolute_path ".")
    [ -d "$abs_path" ] || { echo "path resolution failed"; return 1; }
    
    # Test permissions
    local perms=$(get_file_permissions "$0")
    [ -n "$perms" ] || { echo "permissions test failed"; return 1; }
    
    echo "✓ All compatibility tests passed"
}
```

**Decision**: Implement platform detection and use portable command wrappers.

**Rationale**: Ensures deployment works on both macOS and Linux without user intervention.

---

### 6. LiteLLM Process Detection

**Question**: How to reliably detect if LiteLLM proxy is running?

**Research Findings**:

**Multiple Detection Methods** (in order of reliability):

```bash
is_litellm_running() {
    # Method 1: Check if port 4000 is in use
    if command -v lsof &>/dev/null; then
        if lsof -i :4000 -t &>/dev/null; then
            return 0
        fi
    fi
    
    # Method 2: Check netstat (fallback)
    if command -v netstat &>/dev/null; then
        if netstat -an | grep -q ":4000.*LISTEN"; then
            return 0
        fi
    fi
    
    # Method 3: Check process list
    if pgrep -f "litellm.*proxy" &>/dev/null; then
        return 0
    fi
    
    # Method 4: Try HTTP request
    if command -v curl &>/dev/null; then
        if curl -s -f -m 2 http://localhost:4000/health &>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

get_litellm_pid() {
    # Try lsof first (most reliable)
    if command -v lsof &>/dev/null; then
        lsof -i :4000 -t 2>/dev/null | head -1
        return
    fi
    
    # Fallback to pgrep
    pgrep -f "litellm.*proxy" | head -1
}

stop_litellm() {
    local pid=$(get_litellm_pid)
    
    if [ -z "$pid" ]; then
        echo "LiteLLM is not running"
        return 1
    fi
    
    echo "Stopping LiteLLM (PID: $pid)..."
    kill "$pid"
    
    # Wait up to 5 seconds for graceful shutdown
    local timeout=5
    while [ $timeout -gt 0 ] && kill -0 "$pid" 2>/dev/null; do
        sleep 1
        ((timeout--))
    done
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        echo "Force stopping LiteLLM..."
        kill -9 "$pid"
    fi
    
    echo "✓ LiteLLM stopped"
}
```

**User Interaction**:
```bash
handle_running_litellm() {
    if is_litellm_running; then
        echo ""
        echo "⚠️  LiteLLM proxy is currently running"
        echo ""
        echo "Deployment requires stopping the proxy to update configuration."
        echo ""
        echo "What would you like to do?"
        echo "  1) Stop LiteLLM and continue"
        echo "  2) Cancel deployment"
        echo ""
        read -p "Choice [1-2]: " choice
        
        case "$choice" in
            1)
                stop_litellm || return 1
                ;;
            2)
                echo "Deployment cancelled"
                return 1
                ;;
            *)
                echo "Invalid choice"
                return 1
                ;;
        esac
    fi
}
```

**Decision**: Use multi-method detection (lsof → netstat → pgrep → HTTP) with graceful shutdown.

**Rationale**: Different systems have different tools available, multiple methods ensure reliable detection.

---

## Research Summary

### Key Technical Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| **Script Language** | Bash 4.0+ with strict mode | Native file ops, process management, shell integration |
| **Backup Method** | tar + gzip with 5-backup rotation | Fast, atomic, simple restore, built-in integrity check |
| **JSON Manipulation** | jq with atomic update pattern | Standard tool, safe updates, validation built-in |
| **Env Detection** | Multi-source with precedence | Users configure in different places, check all |
| **Platform Support** | Feature detection + portable wrappers | Works on macOS and Linux without user changes |
| **Process Detection** | Multi-method (lsof/netstat/pgrep/HTTP) | Reliable across different system configurations |

### Implementation Patterns

**Error Handling Pattern**:
```bash
#!/bin/bash
set -euo pipefail

trap cleanup EXIT ERR INT TERM

cleanup() {
    if [ $? -ne 0 ]; then
        rollback_deployment
    fi
}

# Atomic operations
write_config() {
    local temp=$(mktemp)
    generate_config > "$temp"
    validate "$temp" || return 1
    mv "$temp" "$target"
}
```

**Safety Checklist** for Every Deployment Operation:
- [ ] Backup created before changes
- [ ] Changes written to temp file first
- [ ] Validation before moving to final location
- [ ] Rollback on any error
- [ ] File permissions verified
- [ ] Sensitive data sanitized in logs

### Resolved Ambiguities

**From plan.md Open Questions**:

1. ✅ **Settings.json handling**: Use jq with atomic updates and validation
2. ✅ **LiteLLM detection**: Multi-method detection with graceful shutdown
3. ✅ **Version mismatches**: Add version field to manifest, warn on mismatch
4. ✅ **Auto-start LiteLLM**: Add `--start` flag (optional)
5. ✅ **Multi-user systems**: Per-user deployment in each ~/.claude directory
6. ✅ **GCP quota validation**: Add `--validate-quota` flag (optional, may be slow)

### Risks & Mitigations

**Identified During Research**:

1. **Race Condition**: Multiple deployment processes
   - **Mitigation**: Use lock file (`~/.claude/gateway/.deploy.lock`)

2. **Partial Deployment**: Interruption during file operations
   - **Mitigation**: Atomic operations + trap cleanup + rollback

3. **Environment Variable Precedence**: User confusion about which value is used
   - **Mitigation**: Show detected values before deployment, allow override

4. **Platform-Specific Bugs**: Behavior differs between macOS/Linux
   - **Mitigation**: Comprehensive testing on both platforms, portable wrappers

### Next Phase Preparation

**Ready for Phase 1 (Design)** ✅

All research questions answered. Can proceed to:
- Create `data-model.md` with manifest schema
- Create `contracts/deployment-api.md` with CLI interface
- Create `quickstart.md` with user guide
- Update agent context with technology choices

**Technology Stack Confirmed**:
- Bash 4.0+ (deployment engine)
- Python 3.9+ (validation utilities - reuse from spec 001)
- jq (JSON manipulation)
- tar + gzip (backup)
- Standard Unix tools (sed, grep, awk, etc.)

**No Blockers Identified** ✅

All technical questions resolved with concrete implementation patterns.

---

## References

- Bash Best Practices: https://google.github.io/styleguide/shellguide.html
- jq Manual: https://jqlang.github.io/jq/manual/
- tar Documentation: GNU tar 1.34+
- Cross-platform Shell Scripting: POSIX compliance guidelines
- LiteLLM Documentation: https://docs.litellm.ai/docs/proxy/quick_start
