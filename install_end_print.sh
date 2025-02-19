#!/bin/bash
#####################################################################
# END_PRINT Macro Installation Script for Klipper
# Author: ss1gohan13
# Created: 2025-02-19 15:47:06 UTC
# Repository: https://github.com/ss1gohan13/A-better-print_start-macro-SV08
#####################################################################

# Configuration
DEFAULT_CONFIG_PATH="$HOME/printer_data/config"
BACKUP_DIR="$DEFAULT_CONFIG_PATH/backup"
MACRO_FILE="macros.cfg"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d_%H%M%S)"

# Print colored output
print_color() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$1" in
        "info") echo -e "[$timestamp] \e[34m[INFO]\e[0m $2" ;;
        "success") echo -e "[$timestamp] \e[32m[SUCCESS]\e[0m $2" ;;
        "warning") echo -e "[$timestamp] \e[33m[WARNING]\e[0m $2" ;;
        "error") echo -e "[$timestamp] \e[31m[ERROR]\e[0m $2" ;;
    esac
}

# Create backup directory if it doesn't exist
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_color "info" "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || {
            print_color "error" "Failed to create backup directory"
            exit 1
        }
    fi
}

# Restart Klipper function - simplified to only use systemctl
restart_klipper() {
    print_color "info" "Restarting Klipper service..."
    
    if command -v systemctl >/dev/null 2>&1; then
        if sudo -n systemctl restart klipper 2>/dev/null; then
            print_color "success" "Klipper service restarted successfully"
            return 0
        else
            print_color "error" "Failed to restart Klipper service automatically"
            print_color "info" "Please run: sudo systemctl restart klipper"
            return 1
        fi
    else
        print_color "error" "System service manager not found"
        print_color "info" "Please restart Klipper manually"
        return 1
    fi
}

# Main installation function
main() {
    local config_path="$DEFAULT_CONFIG_PATH"
    local macro_path="$config_path/$MACRO_FILE"
    
    print_color "info" "Starting installation..."
    
    # Check config directory
    if [ ! -d "$config_path" ]; then
        print_color "error" "Config directory not found: $config_path"
        exit 1
    fi
    
    # Create backup directory
    create_backup_dir
    
    # Create or verify macro file
    if [ ! -f "$macro_path" ]; then
        print_color "info" "Creating new file: $MACRO_FILE"
        touch "$macro_path" || {
            print_color "error" "Failed to create file"
            exit 1
        }
    fi
    
    # Check write permissions
    if [ ! -w "$macro_path" ]; then
        print_color "error" "Cannot write to $macro_path"
        exit 1
    fi
    
    # Create backup in backup directory
    local backup_file="$BACKUP_DIR/$(basename "$MACRO_FILE")$BACKUP_SUFFIX"
    print_color "info" "Creating backup in: $backup_file"
    cp "$macro_path" "$backup_file" || {
        print_color "error" "Failed to create backup"
        exit 1
    }
    
    # Remove existing END_PRINT macro if it exists
    print_color "info" "Updating END_PRINT macro..."
    sed -i '/\[gcode_macro END_PRINT\]/,/^[[:space:]]*$/d' "$macro_path"
    
    # Append new END_PRINT macro
    cat >> "$macro_path" << 'EOL'
#####################################################################
#   A better end_print macro
#####################################################################

[gcode_macro END_PRINT]
gcode:
  # Get Boundaries
  {% set max_x = printer.configfile.config["stepper_x"]["position_max"]|float %}
  {% set max_y = printer.configfile.config["stepper_y"]["position_max"]|float %}
  {% set max_z = printer.configfile.config["stepper_z"]["position_max"]|float %}
  {% set min_x = printer.configfile.config["stepper_x"]["position_endstop"]|float %}

  # Check end position to determine safe directions to move
  {% if printer.toolhead.position.x < (max_x - 20) %}
      {% set x_safe = 20.0 %}
    {% else %}
      {% set x_safe = -20.0 %}
    {% endif %}

  {% if printer.toolhead.position.y < (max_y - 20) %}
      {% set y_safe = 20.0 %}
    {% else %}
      {% set y_safe = -20.0 %}
    {% endif %}

  {% if printer.toolhead.position.z < (max_z - 2) %}
      {% set z_safe = 2.0 %}
    {% else %}
      {% set z_safe = max_z - printer.toolhead.position.z %}
    {% endif %}

  # Commence END_PRINT
  # STATUS_COOLING
  M400                                                           # wait for buffer to clear
  G92 E0                                                         # zero the extruder
  G1 E-4.0 F3600                                                 # retract
  G91                                                            # relative positioning
  G0 Z{z_safe} F3600                                             # move nozzle up
  M104 S0                                                        # turn off hotend
  M140 S0                                                        # turn off bed
  M106 S0                                                        # turn off fan
  M107                                                           # turn off part cooling fan
  G90                                                            # absolute positioning
  G1 X{min_x} Y{max_y} F2000                                     # move nozzle and present

  # Safe Z-drop if near maximum height (after parking)
  {% if printer.toolhead.position.z > (max_z - 20) %}
    G91                                                          # relative positioning
    G1 Z-10 F600                                                 # drop 10mm if near the top
    G90                                                          # back to absolute
  {% endif %}

  # Conditional check for nevermore pin
  {% if 'nevermore' in printer.configfile.settings %}
    SET_PIN PIN=nevermore VALUE=1                                 # Keep the nevermore running
    UPDATE_DELAYED_GCODE ID=check_nevermore_status DURATION=300   # Schedule to check the nevermore status after 5 minutes
  {% endif %}

  M117 Print finished!!                                          # Displays info on LCD
  # STATUS_PART_READY
  UPDATE_DELAYED_GCODE ID=set_ready_status DURATION=60            # Schedule ready status
  # UPDATE_DELAYED_GCODE ID=reset_printer_status DURATION=65
  # M84                                                           # Disable motors (currently disabled to allow idle timeout)
EOL
    
    # Add include to printer.cfg if needed
    if [ -f "$config_path/printer.cfg" ]; then
        if ! grep -q "^\[include $MACRO_FILE\]" "$config_path/printer.cfg"; then
            print_color "info" "Adding include to printer.cfg..."
            echo -e "\n[include $MACRO_FILE]" >> "$config_path/printer.cfg"
        fi
    fi
    
    print_color "success" "END_PRINT macro has been updated!"
    
    # Automatically restart Klipper
    restart_klipper
}

# Run the script
main
