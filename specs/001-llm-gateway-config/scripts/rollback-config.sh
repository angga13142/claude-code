#!/bin/bash
# Configuration Rollback Utility
# Safely rollback configuration changes
# Usage: bash scripts/rollback-config.sh [backup_file]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${CONFIG_DIR:-$PROJECT_ROOT}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_help() {
    cat << EOF
Configuration Rollback Utility

Usage: $0 [options] [backup_file]

Options:
  --list, -l           List available backups
  --interactive, -i    Interactive mode (select from list)
  --config-dir DIR     Configuration directory (default: $CONFIG_DIR)
  --help, -h           Show this help message

Arguments:
  backup_file          Path to backup file to restore

Examples:
  # List available backups
  $0 --list

  # Interactive rollback (select from list)
  $0 --interactive

  # Rollback to specific backup
  $0 config/litellm.yaml.backup.20251201_120000

  # Rollback latest backup
  $0 config/litellm.yaml.backup.latest
EOF
}

list_backups() {
    local config_file="$1"
    local backup_pattern="${config_file}.backup.*"
    
    log_info "Searching for backups: $backup_pattern"
    echo ""
    
    local backups=()
    while IFS= read -r -d '' backup; do
        backups+=("$backup")
    done < <(find "$CONFIG_DIR" -name "$(basename "$backup_pattern")" -type f -print0 2>/dev/null | sort -rz)
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_warning "No backups found for pattern: $backup_pattern"
        return 1
    fi
    
    echo "Available backups:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local i=1
    for backup in "${backups[@]}"; do
        local timestamp=$(basename "$backup" | grep -oP '\d{8}_\d{6}')
        local size=$(du -h "$backup" | cut -f1)
        local date=$(echo "$timestamp" | sed 's/_/ /')
        
        printf "%2d) %s\n" "$i" "$(basename "$backup")"
        printf "    Date: %s | Size: %s\n" "$date" "$size"
        
        ((i++))
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Return backups array via global variable
    FOUND_BACKUPS=("${backups[@]}")
    return 0
}

interactive_rollback() {
    local config_file="$1"
    
    # List backups
    if ! list_backups "$config_file"; then
        return 1
    fi
    
    # Prompt for selection
    echo -n "Select backup to restore (1-${#FOUND_BACKUPS[@]}), or 'q' to quit: "
    read -r selection
    
    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        log_info "Rollback cancelled"
        return 1
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#FOUND_BACKUPS[@]}" ]; then
        log_error "Invalid selection: $selection"
        return 1
    fi
    
    local backup_file="${FOUND_BACKUPS[$((selection-1))]}"
    log_info "Selected: $(basename "$backup_file")"
    
    # Confirm
    echo -n "Restore this backup? This will overwrite the current configuration. (y/N): "
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Rollback cancelled"
        return 1
    fi
    
    # Perform rollback
    rollback_config "$backup_file" "$config_file"
}

rollback_config() {
    local backup_file="$1"
    local config_file="$2"
    
    log_info "Starting rollback process..."
    echo ""
    
    # Validate backup file
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Check YAML validity
    if command -v python3 &> /dev/null; then
        log_info "Validating backup file..."
        if ! python3 -c "import yaml; yaml.safe_load(open('$backup_file'))" 2>/dev/null; then
            log_error "Backup file is not valid YAML"
            return 1
        fi
        log_success "Backup file is valid YAML"
    fi
    
    # Create backup of current config
    if [ -f "$config_file" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local pre_rollback_backup="${config_file}.pre-rollback.${timestamp}"
        
        log_info "Creating backup of current config: $(basename "$pre_rollback_backup")"
        cp "$config_file" "$pre_rollback_backup"
        log_success "Pre-rollback backup created"
    fi
    
    # Restore from backup
    log_info "Restoring configuration from backup..."
    cp "$backup_file" "$config_file"
    
    log_success "Configuration restored successfully!"
    echo ""
    log_info "Config file: $config_file"
    log_info "Restored from: $backup_file"
    
    if [ -f "$pre_rollback_backup" ]; then
        log_info "Pre-rollback backup: $pre_rollback_backup"
    fi
    
    echo ""
    log_warning "Remember to restart any services using this configuration"
    echo ""
    
    return 0
}

# Parse arguments
INTERACTIVE=false
LIST_ONLY=false
BACKUP_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --list|-l)
            LIST_ONLY=true
            shift
            ;;
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --config-dir)
            CONFIG_DIR="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

# Main logic
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Configuration Rollback Utility                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Determine config file
if [ -n "$BACKUP_FILE" ]; then
    # Extract original config file name from backup
    CONFIG_FILE=$(echo "$BACKUP_FILE" | sed 's/\.backup\..*//' | sed 's/\.pre-rollback\..*//')
else
    # Look for config files in common locations
    if [ -f "$CONFIG_DIR/litellm-config.yaml" ]; then
        CONFIG_FILE="$CONFIG_DIR/litellm-config.yaml"
    elif [ -f "$CONFIG_DIR/config.yaml" ]; then
        CONFIG_FILE="$CONFIG_DIR/config.yaml"
    elif [ -f "$CONFIG_DIR/litellm.yaml" ]; then
        CONFIG_FILE="$CONFIG_DIR/litellm.yaml"
    else
        log_error "No configuration file found in $CONFIG_DIR"
        log_info "Specify backup file explicitly or use --config-dir"
        exit 1
    fi
fi

log_info "Configuration file: $CONFIG_FILE"
echo ""

# Execute based on mode
if [ "$LIST_ONLY" = true ]; then
    list_backups "$CONFIG_FILE"
    exit $?
elif [ "$INTERACTIVE" = true ]; then
    interactive_rollback "$CONFIG_FILE"
    exit $?
elif [ -n "$BACKUP_FILE" ]; then
    rollback_config "$BACKUP_FILE" "$CONFIG_FILE"
    exit $?
else
    log_error "No action specified"
    echo ""
    show_help
    exit 1
fi
