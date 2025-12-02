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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
DRY_RUN="false"
FORCE="false"
VERBOSE="false"

# Source and target directories
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
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
                exit 3
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
            exit 3
            ;;
    esac

    # Validate preset is provided for install command
    if [[ "$COMMAND" == "install" ]] && [[ -z "$PRESET" ]]; then
        echo_error "Missing required option: --preset"
        echo "Run 'deploy-gateway-config.sh --help' for usage information."
        exit 3
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
                exit 3
                ;;
        esac
    fi

    # Validate enterprise preset requirements
    if [[ "$PRESET" == "enterprise" ]] && [[ -z "$GATEWAY_URL" ]]; then
        echo_error "Enterprise preset requires --gateway-url"
        exit 3
    fi

    # Validate proxy preset requirements
    if [[ "$PRESET" == "proxy" ]] && [[ -z "$PROXY_URL" ]]; then
        echo_error "Proxy preset requires --proxy"
        exit 3
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

    # Route to appropriate deployment function based on preset
    case "$PRESET" in
        basic)
            deploy_basic
            ;;
        enterprise)
            deploy_enterprise
            ;;
        multi-provider)
            # Placeholder for T045 (Phase 6)
            echo_error "Multi-provider preset not yet implemented (Phase 6)"
            exit 3
            ;;
        proxy)
            # Placeholder for T060 (Phase 8)
            echo_error "Proxy preset not yet implemented (Phase 8)"
            exit 3
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
handle_update_command() {
    echo_error "Update command not yet implemented (Phase 7)"
    exit 3
}

#
# handle_rollback_command - Execute rollback command (FR-034)
#
# Usage: handle_rollback_command
#
# Placeholder for Phase 9
#
handle_rollback_command() {
    echo_error "Rollback command not yet implemented (Phase 9)"
    exit 3
}

#
# handle_list_backups_command - Execute list-backups command (FR-035)
#
# Usage: handle_list_backups_command
#
# Placeholder for Phase 9
#
handle_list_backups_command() {
    echo_error "List-backups command not yet implemented (Phase 9)"
    exit 3
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
