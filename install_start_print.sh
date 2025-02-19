#!/bin/bash
#####################################################################
# START_PRINT/PRINT_START Macro Installation Script for Klipper
# Author: ss1gohan13
# Created: 2025-02-19 05:32:29 UTC
# Repository: https://github.com/ss1gohan13/A-better-print_start-macro-SV08
#####################################################################

# Default path for Klipper config
DEFAULT_CONFIG_PATH="$HOME/printer_data/config"
MACRO_FILE="macros.cfg"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d_%H%M%S)"

# Print colored output
print_color() {
    case $1 in
        "info") echo -e "\e[34m[INFO]\e[0m $2" ;;
        "success") echo -e "\e[32m[SUCCESS]\e[0m $2" ;;
        "warning") echo -e "\e[33m[WARNING]\e[0m $2" ;;
        "error") echo -e "\e[31m[ERROR]\e[0m $2"
    esac
}

# Function to restart Klipper
restart_klipper() {
    print_color "info" "Attempting to restart Klipper..."
    
    if curl -s "http://localhost:7125/printer/firmware_restart" -H "Content-Type: application/json" -X POST; then
        print_color "success" "Klipper firmware restart initiated successfully"
        return 0
    else
        print_color "warning" "Moonraker API restart failed, attempting service restart..."
        if sudo systemctl restart klipper; then
            print_color "success" "Klipper service restarted successfully"
            return 0
        else
            print_color "error" "Failed to restart Klipper. Please restart manually"
            return 1
        fi
    fi
}

# Main installation function
install_macro() {
    local config_path="${1:-$DEFAULT_CONFIG_PATH}"
    local macro_path="$config_path/$MACRO_FILE"
    
    print_color "info" "Starting installation of START_PRINT macro..."
    print_color "info" "Using macro file: $MACRO_FILE"
    
    # Check if config directory exists
    if [ ! -d "$config_path" ]; then
        print_color "error" "Config directory not found: $config_path"
        return 1
    fi

    # Create or verify macro file
    if [ ! -f "$macro_path" ]; then
        print_color "info" "Creating new file: $MACRO_FILE"
        touch "$macro_path" || {
            print_color "error" "Failed to create file: $macro_path"
            return 1
        }
        
        # Add include to printer.cfg
        if [ -f "$config_path/printer.cfg" ]; then
            if ! grep -q "^\[include $MACRO_FILE\]" "$config_path/printer.cfg"; then
                print_color "info" "Adding include statement to printer.cfg"
                echo -e "\n[include $MACRO_FILE]" >> "$config_path/printer.cfg"
            fi
        fi
    fi

    # Check write permissions
    if [ ! -w "$macro_path" ]; then
        print_color "error" "Cannot write to $macro_path. Check permissions."
        return 1
    fi

    # Backup existing file
    cp "$macro_path" "$macro_path$BACKUP_SUFFIX" || {
        print_color "error" "Failed to create backup file"
        return 1
    }
    print_color "success" "Backup created: $macro_path$BACKUP_SUFFIX"

    # Remove existing macros
    sed -i '/\[gcode_macro START_PRINT\]/,/^[[:space:]]*$/d' "$macro_path" 2>/dev/null
    sed -i '/\[gcode_macro PRINT_START\]/,/^[[:space:]]*$/d' "$macro_path" 2>/dev/null

    # Add new macro content
    echo "$START_PRINT_CONTENT" >> "$macro_path" || {
        print_color "error" "Failed to write new macro content"
        return 1
    }
    
    print_color "success" "START_PRINT and PRINT_START macros have been installed successfully!"
    
    # Prompt for restart
    print_color "info" "Would you like to restart Klipper now to apply changes? (y/N): "
    read -r restart_response
    if [[ "$restart_response" =~ ^[Yy]$ ]]; then
        restart_klipper
    else
        print_color "info" "Please remember to restart Klipper to apply changes"
    fi
}

# Execute installation
install_macro
