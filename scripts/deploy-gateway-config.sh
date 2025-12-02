#!/usr/bin/env bash
#
# deploy-gateway-config.sh - LLM Gateway Configuration Deployment Tool
# Part of LLM Gateway Configuration Deployment (002-gateway-config-deploy)
#
# Deploy LiteLLM gateway configurations from specs/001-llm-gateway-config
# to ~/.claude/gateway/ directory for immediate use.
#
# Usage: deploy-gateway-config.sh [OPTIONS] [COMMAND]
#
# Commands:
#   install (default) - Deploy gateway configuration
#   update           - Update existing deployment
#   rollback         - Rollback to previous backup
#   list-backups     - Show available backups
#
# Options:
#   --preset PRESET        Deployment preset (basic|enterprise|multi-provider|proxy)
#   --models MODELS        Comma-separated model list (optional)
#   --gateway-type TYPE    Gateway type for enterprise preset (optional)
#   --gateway-url URL      Enterprise gateway URL (optional)
#   --auth-token TOKEN     Authentication token (optional)
#   --proxy URL            HTTP/HTTPS proxy URL (optional)
#   --proxy-auth CREDS     Proxy authentication username:password (optional)
#   --dry-run              Preview changes without applying (optional)
#   --force                Skip confirmations (optional)
#   --verbose              Detailed output (optional)
#   --help, -h             Show this help message
#   --version, -v          Show version information

set -euo pipefail

# Script directory and library imports
SCRIPT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="${SCRIPT_DIR}/lib"

# Source library functions
# shellcheck source=lib/deploy-output.sh
source "${LIB_DIR}/deploy-output.sh"
# shellcheck source=lib/deploy-perms.sh
source "${LIB_DIR}/deploy-perms.sh"
# shellcheck source=lib/deploy-env.sh
source "${LIB_DIR}/deploy-env.sh"
# shellcheck source=lib/deploy-presets.sh
source "${LIB_DIR}/deploy-presets.sh"
# shellcheck source=lib/deploy-models.sh
source "${LIB_DIR}/deploy-models.sh"
# shellcheck source=lib/deploy-backup.sh
source "${LIB_DIR}/deploy-backup.sh"
# shellcheck source=lib/deploy-validate.sh
source "${LIB_DIR}/deploy-validate.sh"
# shellcheck source=lib/deploy-log.sh
source "${LIB_DIR}/deploy-log.sh"
# shellcheck source=lib/deploy-core.sh
source "${LIB_DIR}/deploy-core.sh"

# Version
readonly VERSION="1.0.0"

# Default configuration
COMMAND="install"
PRESET=""
MODELS=""
GATEWAY_TYPE=""
GATEWAY_URL=""
AUTH_TOKEN=""
PROXY_URL=""
PROXY_AUTH=""
BACKUP_NAME=""  # For rollback command
DRY_RUN="false"
FORCE="false"
VERBOSE="false"

# Exit codes (FR-034, FR-035, CLI contract)
readonly EXIT_SUCCESS=0
readonly EXIT_PERMISSION_DENIED=1
readonly EXIT_INSUFFICIENT_DISK=2
readonly EXIT_INVALID_ARGS=3
readonly EXIT_VALIDATION_FAILED=4
readonly EXIT_SOURCE_MISSING=5
readonly EXIT_BACKUP_FAILED=6

# Source and target directories
REPO_ROOT=""
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly SOURCE_DIR="${REPO_ROOT}/specs/001-llm-gateway-config"
readonly TARGET_DIR="${HOME}/.claude/gateway"

#
# print_version - Display version information
#
# Usage: print_version
#
print_version() {
    echo "LLM Gateway Configuration Deployment Tool v${VERSION}"
    echo "Part of Claude Code Configuration Repository"
}

#
# print_help - Display comprehensive help text
#
# Usage: print_help
#
print_help() {
    cat << 'EOF'
LLM Gateway Configuration Deployment Tool

USAGE:
    deploy-gateway-config.sh [OPTIONS] [COMMAND]

COMMANDS:
    install (default)    Deploy gateway configuration to ~/.claude/gateway
    update              Update existing deployment with new settings
    rollback [BACKUP]   Rollback to previous backup
    list-backups        Show available backups with metadata

OPTIONS:
    --preset PRESET         Deployment preset (required for install)
                           Choices: basic, enterprise, multi-provider, proxy

    --models MODELS         Comma-separated model list (optional)
                           Example: gemini-2.5-flash,gemini-2.5-pro,deepseek-r1

    --gateway-type TYPE     Gateway type for enterprise preset (optional)
                           Choices: truefoundry, zuplo, custom

    --gateway-url URL       Enterprise gateway URL (required for enterprise preset)
                           Example: https://gateway.company.com

    --auth-token TOKEN      Authentication token for enterprise gateway (optional)

    --proxy URL             HTTP/HTTPS proxy URL for restricted networks (optional)
                           Example: https://proxy.company.com:8080

    --proxy-auth CREDS      Proxy authentication (optional)
                           Format: username:password

    --dry-run               Preview deployment changes without applying

    --force                 Skip all confirmation prompts (CI/CD mode)

    --verbose               Enable detailed output for debugging

    --help, -h              Show this help message

    --version, -v           Show version information

EXAMPLES:
    # Basic deployment with all 8 Vertex AI models
    deploy-gateway-config.sh --preset basic

    # Deploy with custom model selection
    deploy-gateway-config.sh --preset basic --models gemini-2.5-flash,deepseek-r1

    # Enterprise gateway configuration
    deploy-gateway-config.sh --preset enterprise \\
        --gateway-url https://gateway.company.com \\
        --auth-token sk-xxx

    # Multi-provider setup
    deploy-gateway-config.sh --preset multi-provider

    # Preview deployment without applying changes
    deploy-gateway-config.sh --preset basic --dry-run

    # Force non-interactive deployment (CI/CD)
    deploy-gateway-config.sh --preset basic --force

    # Rollback to previous backup
    deploy-gateway-config.sh rollback

    # List available backups
    deploy-gateway-config.sh list-backups

EXIT CODES:
    0  Success
    1  Permission denied
    2  Insufficient disk space
    3  Invalid preset or arguments
    4  Validation failed
    5  Source directory missing or corrupted
    6  Backup operation failed

DOCUMENTATION:
    Spec:     specs/002-gateway-config-deploy/spec.md
    Plan:     specs/002-gateway-config-deploy/plan.md
    Examples: specs/002-gateway-config-deploy/contracts/

EOF
}

#
# parse_arguments - Parse command-line arguments (FR-031, FR-032)
#
# Usage: parse_arguments "$@"
#
# Validates all arguments and sets global variables
# Exits with code 3 if invalid arguments provided
#
parse_arguments() {
    # Parse positional command if present
    if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; then
        COMMAND="$1"
        shift
        
        # Parse backup name for rollback command
        if [[ "$COMMAND" == "rollback" ]] && [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; then
            BACKUP_NAME="$1"
            shift
        fi
    fi

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --preset)
                PRESET="$2"
                shift 2
                ;;
            --models)
                MODELS="$2"
                shift 2
                ;;
            --gateway-type)
                GATEWAY_TYPE="$2"
                shift 2
                ;;
            --gateway-url)
                GATEWAY_URL="$2"
                shift 2
                ;;
            --auth-token)
                AUTH_TOKEN="$2"
                shift 2
                ;;
            --proxy)
                PROXY_URL="$2"
                shift 2
                ;;
            --proxy-auth)
                PROXY_AUTH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            --version|-v)
                print_version
                exit 0
                ;;
            *)
                echo_error "Unknown option: $1"
                echo "Run 'deploy-gateway-config.sh --help' for usage information."
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done

    # Validate command
    case "$COMMAND" in
        install|update|rollback|list-backups)
            : # Valid command
            ;;
        *)
            echo_error "Unknown command: $COMMAND"
            echo "Valid commands: install, update, rollback, list-backups"
            exit $EXIT_INVALID_ARGS
            ;;
    esac

    # Validate preset is provided for install command
    if [[ "$COMMAND" == "install" ]] && [[ -z "$PRESET" ]]; then
        echo_error "Missing required option: --preset"
        echo "Run 'deploy-gateway-config.sh --help' for usage information."
        exit $EXIT_INVALID_ARGS
    fi

    # Validate preset value
    if [[ -n "$PRESET" ]]; then
        case "$PRESET" in
            basic|enterprise|multi-provider|proxy)
                : # Valid preset
                ;;
            *)
                echo_error "Invalid preset: $PRESET"
                echo "Valid presets: basic, enterprise, multi-provider, proxy"
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    fi

    # Validate enterprise preset requirements
    if [[ "$PRESET" == "enterprise" ]] && [[ -z "$GATEWAY_URL" ]]; then
        echo_error "Enterprise preset requires --gateway-url"
        exit $EXIT_INVALID_ARGS
    fi

    # Validate proxy preset requirements
    if [[ "$PRESET" == "proxy" ]] && [[ -z "$PROXY_URL" ]]; then
        echo_error "Proxy preset requires --proxy"
        exit $EXIT_INVALID_ARGS
    fi
}

#
# handle_install_command - Execute install command (calls deploy_basic)
#
# Usage: handle_install_command
#
# Orchestrates the deployment based on preset type
# Exits with appropriate error codes on failure
#
handle_install_command() {
    echo_header "🚀 Deploying LLM Gateway Configuration"
    echo "  Preset: ${PRESET}"
    
    if [[ -n "$MODELS" ]]; then
        local model_count
        model_count=$(echo "$MODELS" | tr ',' '\n' | wc -l)
        echo "  Models: ${MODELS} (${model_count} selected)"
    else
        echo "  Models: All models from preset"
    fi
    
    echo "  Target: ${TARGET_DIR}"
    echo ""
    
    # Show dry-run summary if in dry-run mode (FR-031, T068, T069)
    if [[ "$DRY_RUN" == "true" ]]; then
        local model_display="${MODELS:-all models}"
        print_dry_run_summary "$PRESET" "$model_display" "$TARGET_DIR" "$SOURCE_DIR"
        exit $EXIT_SUCCESS
    fi

    # Route to appropriate deployment function based on preset
    case "$PRESET" in
        basic)
            deploy_basic
            ;;
        enterprise)
            deploy_enterprise
            ;;
        multi-provider)
            deploy_multi_provider
            ;;
        proxy)
            deploy_proxy
            ;;
    esac
}

#
# handle_update_command - Execute update command
#
# Usage: handle_update_command
#
# Placeholder for Phase 7 (User Story 5)
#
#
# handle_update_command - Execute update command (US5 - T052, FR-022, FR-023)
#
# Usage: handle_update_command
#
# Updates existing deployment with new settings while preserving customizations
# Exits with appropriate error codes on failure
#
handle_update_command() {
    echo_header "🔄 Updating LLM Gateway Configuration"
    
    # Check if deployment exists
    if [[ ! -d "$TARGET_DIR" ]]; then
        echo_error "No existing deployment found at: $TARGET_DIR"
        echo "Run 'deploy-gateway-config.sh --preset <PRESET>' to install first."
        exit 1
    fi
    
    echo "  Target: ${TARGET_DIR}"
    
    if [[ -n "$MODELS" ]]; then
        local model_count
        model_count=$(echo "$MODELS" | tr ',' '\n' | wc -l)
        echo "  Models to update: ${MODELS} (${model_count} selected)"
    fi
    
    if [[ -n "$GATEWAY_URL" ]]; then
        echo "  Gateway URL: ${GATEWAY_URL}"
    fi
    
    echo ""
    
    # Call deploy_update function
    deploy_update
}

#
# handle_rollback_command - Execute rollback command (FR-034, T066)
#
# Usage: handle_rollback_command
#
# Restores gateway configuration from backup
# Exits with appropriate error codes on failure
#
handle_rollback_command() {
    echo_header "🔙 Rolling back LLM Gateway Configuration"
    
    # Determine backup to use
    local backup_file=""
    
    if [[ -z "$BACKUP_NAME" ]] || [[ "$BACKUP_NAME" == "latest" ]]; then
        # Use latest backup
        echo_info "Finding latest backup..."
        if ! backup_file=$(get_latest_backup); then
            echo_error "No backups found in ${BACKUP_DIR}"
            echo ""
            echo "Create a backup first by running a deployment:"
            echo "  deploy-gateway-config.sh --preset basic"
            exit $EXIT_BACKUP_FAILED
        fi
        echo_info "Using latest backup: $(basename "$backup_file")"
    else
        # Use specified backup
        if [[ "$BACKUP_NAME" =~ ^/ ]]; then
            # Absolute path provided
            backup_file="$BACKUP_NAME"
        else
            # Relative filename provided
            backup_file="${BACKUP_DIR}/${BACKUP_NAME}"
        fi
        
        if [[ ! -f "$backup_file" ]]; then
            echo_error "Backup not found: $backup_file"
            echo ""
            echo "List available backups:"
            echo "  deploy-gateway-config.sh list-backups"
            exit $EXIT_BACKUP_FAILED
        fi
    fi
    
    # Display backup information
    echo ""
    echo "  Backup: $(basename "$backup_file")"
    local size
    size=$(du -h "$backup_file" | cut -f1)
    echo "  Size: ${size}"
    
    local date_created
    if [[ "$OSTYPE" == "darwin"* ]]; then
        date_created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup_file")
    else
        date_created=$(stat -c "%y" "$backup_file" | cut -d'.' -f1)
    fi
    echo "  Created: ${date_created}"
    echo ""
    
    # Validate backup integrity
    echo_info "Validating backup integrity..."
    if ! validate_backup_integrity "$backup_file"; then
        echo_error "Backup file is corrupted or invalid"
        exit $EXIT_VALIDATION_FAILED
    fi
    echo_success "Backup integrity verified"
    
    # Confirm rollback unless --force
    if [[ "$FORCE" != "true" ]]; then
        echo ""
        echo_warning "This will overwrite current configuration"
        if [[ -d "$TARGET_DIR" ]]; then
            echo "  A safety backup will be created first"
        fi
        echo ""
        read -p "Continue with rollback? [y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo_info "Rollback cancelled"
            exit $EXIT_SUCCESS
        fi
    fi
    
    # Perform rollback
    echo ""
    echo_info "Rolling back configuration..."
    if ! rollback_from_backup "$backup_file" "$TARGET_DIR"; then
        echo_error "Rollback failed"
        exit $EXIT_BACKUP_FAILED
    fi
    
    echo_success "Configuration restored successfully"
    
    # Validate restored configuration
    if [[ -f "${TARGET_DIR}/config/litellm.yaml" ]]; then
        echo_info "Validating restored configuration..."
        if command -v python3 >/dev/null 2>&1; then
            if python3 "${SOURCE_DIR}/scripts/validate-config.py" "${TARGET_DIR}/config/litellm.yaml" 2>/dev/null; then
                echo_success "Configuration validation passed"
            else
                echo_warning "Configuration validation failed (may need manual review)"
            fi
        fi
    fi
    
    # Final summary
    echo ""
    echo_success "✅ Rollback completed successfully"
    echo ""
    echo "Next steps:"
    echo "  1. Review configuration: vi ${TARGET_DIR}/config/litellm.yaml"
    echo "  2. Restart gateway: bash ${TARGET_DIR}/start-gateway.sh"
    echo ""
}

#
# handle_list_backups_command - Execute list-backups command (FR-035, T067)
#
# Usage: handle_list_backups_command
#
# Lists all available backups with detailed metadata
# Exits with code 1 if no backups found
#
handle_list_backups_command() {
    echo_header "📦 Available Backups"
    echo ""
    
    # Check if backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo_warning "No backup directory found: ${BACKUP_DIR}"
        echo ""
        echo "Backups are created automatically during deployments."
        echo "Run a deployment to create your first backup:"
        echo "  deploy-gateway-config.sh --preset basic"
        exit $EXIT_BACKUP_FAILED
    fi
    
    # Find all backups
    local backup_files=("$BACKUP_DIR"/gateway-backup-*.tar.gz)
    
    if [[ ! -e "${backup_files[0]}" ]]; then
        echo_warning "No backups found in: ${BACKUP_DIR}"
        echo ""
        echo "Backups are created automatically during deployments."
        echo "Run a deployment to create your first backup:"
        echo "  deploy-gateway-config.sh --preset basic"
        exit $EXIT_BACKUP_FAILED
    fi
    
    # Count and calculate total size
    local count=0
    local total_size=0
    
    # Print header
    printf "%-50s %-12s %-20s %s\n" "Backup File" "Size" "Created" "Status"
    printf "%s\n" "$(printf '=%.0s' {1..100})"
    
    # List backups (newest first)
    local backup_list=()
    for backup_file in "${backup_files[@]}"; do
        if [[ -f "$backup_file" ]]; then
            backup_list+=("$backup_file")
        fi
    done
    
    # Sort by modification time (newest first)
    if [[ ${#backup_list[@]} -gt 0 ]]; then
        mapfile -t backup_list < <(ls -t "${backup_list[@]}" 2>/dev/null)
    fi
    
    # Print each backup with details
    local num=1
    for backup_file in "${backup_list[@]}"; do
        if [[ -f "$backup_file" ]]; then
            local filename
            filename=$(basename "$backup_file")
            
            # Get size
            local size
            size=$(du -h "$backup_file" | cut -f1)
            
            # Get creation date
            local date_created
            if [[ "$OSTYPE" == "darwin"* ]]; then
                date_created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$backup_file")
            else
                date_created=$(stat -c "%y" "$backup_file" | cut -d'.' -f1 | cut -d' ' -f1,2 | cut -d':' -f1,2)
            fi
            
            # Validate integrity
            local status
            if validate_backup_integrity "$backup_file" 2>/dev/null; then
                status="✓ Valid"
            else
                status="✗ Corrupted"
            fi
            
            # Print row
            printf "  %-2s %-45s %-12s %-20s %s\n" "${num}." "$filename" "$size" "$date_created" "$status"
            
            ((count++))
            ((num++))
            
            # Add to total size (convert to KB for summing)
            local size_kb
            size_kb=$(du -k "$backup_file" | cut -f1)
            ((total_size += size_kb))
        fi
    done
    
    # Print summary
    echo ""
    printf "Total: %d backup(s)" "$count"
    
    # Convert total size to human readable
    local total_mb=$((total_size / 1024))
    if [[ $total_mb -gt 1024 ]]; then
        local total_gb=$((total_mb / 1024))
        printf " (%.1f GB)\n" "$(echo "scale=1; $total_mb / 1024" | bc 2>/dev/null || echo "$total_gb")"
    else
        printf " (%d MB)\n" "$total_mb"
    fi
    
    # Print usage examples
    echo ""
    echo "Rollback examples:"
    echo "  deploy-gateway-config.sh rollback latest"
    if [[ ${#backup_list[@]} -gt 0 ]]; then
        echo "  deploy-gateway-config.sh rollback $(basename "${backup_list[0]}")"
    fi
    echo ""
}

#
# main - Main entry point
#
# Usage: main "$@"
#
main() {
    parse_arguments "$@"

    # Enable verbose mode if requested
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    # Set up error trapping for automatic rollback (T072)
    # Note: Only trap errors during install/update commands
    if [[ "$COMMAND" == "install" ]] || [[ "$COMMAND" == "update" ]]; then
        trap 'handle_error $? $LINENO' ERR
    fi

    # Route to command handler
    case "$COMMAND" in
        install)
            handle_install_command
            ;;
        update)
            handle_update_command
            ;;
        rollback)
            handle_rollback_command
            ;;
        list-backups)
            handle_list_backups_command
            ;;
    esac
}

# Execute main function
main "$@"
