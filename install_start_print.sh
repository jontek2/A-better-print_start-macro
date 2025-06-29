#!/bin/bash
#####################################################################
# START_PRINT/PRINT_START Macro Installation Script for Klipper
# Author: ss1gohan13
# Created: 2025-02-19 06:16:31 UTC
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
    
    # Remove existing START_PRINT and PRINT_START macros if they exist
    print_color "info" "Updating START_PRINT macro..."
    sed -i '/\[gcode_macro START_PRINT\]/,/^[[:space:]]*$/d' "$macro_path"
    sed -i '/\[gcode_macro PRINT_START\]/,/^[[:space:]]*$/d' "$macro_path"
    
    # Append new START_PRINT macro
    cat >> "$macro_path" << 'EOL'
#####################################################################
#------------------- A better start_print macro --------------------#
#####################################################################

[gcode_macro START_PRINT]
gcode:
    # This part fetches data from your slicer, such as bed temp, extruder temp, chamber temp, and the size of your printer.
    {% set target_bed = params.BED|int %}
    {% set target_extruder = params.EXTRUDER|int %}
    {% set target_chamber = params.CHAMBER|default("40")|int %}
    {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
    {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

    # Homes the printer, sets absolute positioning, and updates the Stealthburner LEDs.
    #STATUS_HOMING
    # Check homing status and home if needed
    {% if "xyz" not in printer.toolhead.homed_axes %}
        G28                                                      # Full home if not already homed
    {% elif 'z' not in printer.toolhead.homed_axes %}
        G28 Z                                                    # Home Z if only Z is unhomed
    {% endif %}
                
    G90                                                          # Use absolute/relative coordinates
    M400                                                         # Wait for current moves to finish
    CLEAR_PAUSE                                                  # Clear any existing pause state

    # Uncomment for bed mesh (1 of 2)
    BED_MESH_CLEAR                                               # Clears old saved bed mesh (if any)

    # Checks if the bed temp is higher than 90C - if so, then trigger a heat soak.
    {% if params.BED|int > 90 %}
        M117 Bed: {target_bed}C                                  # Display bed temperature
        #STATUS_HEATING                                           # Sets SB-LEDs to heating-mode
        M106 S255                                                # Turns on the PT-fan
        # Conditional check for nevermore pin
        {% if printer["output_pin nevermore"] is defined %}
            SET_PIN PIN=nevermore VALUE=1  # Turns on the Nevermore
        {% endif %}
        G1 X{x_wait} Y{y_wait} Z15 F9000                         # Go to the center of the bed
        M190 S{target_bed}                                       # Sets the target temp for the bed
        
        # Start chamber heating progress monitoring (modify just this section)
        M117 Monitoring chamber: {target_chamber}C                # Display chamber monitoring status
        # Conditional check for chamber thermistor
        {% if printer["temperature_sensor chamber"] is defined %}
            TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for the chamber to reach the desired temp
        {% else %}
            M117 Soak: 15min (No chamber thermistor)
            G4 P900000                                           # Wait 15 minutes for heatsoak
        {% endif %}

    # If the bed temp is not over 90c, then handle soak based on material
    {% else %}
        M117 Bed: {target_bed}C                                  # Display bed temperature
        #STATUS_HEATING                                           # Sets SB-leds to heating-mode
        G1 X{x_wait} Y{y_wait} Z15 F9000                         # Go to center of the bed
        M190 S{target_bed}                                       # Sets the target temp for the bed
        
        # Material-based soak times with variant handling
        {% set raw_material = params.MATERIAL|default("PLA")|string|upper %}
        
        # Extract base material type by handling variants
        {% set material = namespace(type="") %}
        {% if "PLA" in raw_material %}
            {% set material.type = "PLA" %}
        {% elif "PETG" in raw_material %}
            {% set material.type = "PETG" %}
        {% elif "TPU" in raw_material or "TPE" in raw_material %}
            {% set material.type = "TPU" %}
        {% elif "PVA" in raw_material %}
            {% set material.type = "PVA" %}
        {% elif "HIPS" in raw_material %}
            {% set material.type = "HIPS" %}
        {% else %}
            {% set material.type = raw_material %}
        {% endif %}

        # Define soak times
        {% set soak_time = {
            "PLA": 180000,    # 3 minutes - Standard PLA soak time
            "PETG": 240000,   # 4 minutes - PETG needs slightly longer to stabilize
            "TPU": 180000,    # 3 minutes - TPU/TPE materials
            "PVA": 180000,    # 3 minutes - Support material, similar to PLA
            "HIPS": 240000    # 4 minutes - When used as support/primary under 90C
        }[material.type]|default(300000) %}                      # Default to 5 minutes if material not found
        
        M117 Soak: {soak_time/60000|int}min ({raw_material})     # Display soak time and material
        G4 P{soak_time}                                          # Execute soak timer
    {% endif %}
    
    # Check if GANTRY_LEVELING macro exists, use it if available
    {% if printer.configfile.config['gcode_macro GANTRY_LEVELING'] is defined %}
        #STATUS_LEVELING                                        # Sets SB-LEDs to leveling-mode
        M117 Gantry Leveling...                                 # Display gantry leveling status
        GANTRY_LEVELING                                         # Performs the appropriate leveling method (QGL or Z_TILT)
    {% else %}
        # Fallback to traditional method if GANTRY_LEVELING doesn't exist
        # Conditional method for Z_TILT_ADJUST and QUAD_GANTRY_LEVEL
        {% if 'z_tilt' in printer %}
            #STATUS_LEVELING                                  # Sets SB-LEDs to leveling-mode
            M117 Z-tilt...                                    # Display Z-tilt adjustment
            Z_TILT_ADJUST                                     # Levels the buildplate via z_tilt_adjust
        {% elif 'quad_gantry_level' in printer %}
            #STATUS_LEVELING                                  # Sets SB-LEDs to leveling-mode
            M117 QGL...                                       # Display QGL status
            QUAD_GANTRY_LEVEL                                 # Levels the gantry
        {% endif %}
    {% endif %}
    # Conditional check to ensure Z is homed after leveling procedures
    {% if 'z' not in printer.toolhead.homed_axes %}
        #STATUS_HOMING                                        # Sets SB-LEDs to homing-mode
        M117 Z homing                                         # Display Z homing status
        G28 Z                                                 # Home Z if needed after leveling
    {% endif %}

    # Heating the nozzle to 150C. This helps with getting a correct Z-home
    #STATUS_HEATING                                              # Sets SB-LEDs to heating-mode
    M117 Hotend: 150C                                           # Display hotend temperature
    M109 S150                                                   # Heats the nozzle to 150C

    M117 Cleaning the nozzle...
    #STATUS_CLEANING                                             # Sets SB-LEDs to cleaning-mode
    CLEAN_NOZZLE #EXTRUDER={target_extruder}                     # Clean nozzle before printing

    # M117 Nozzle cooling 150C...                                # Display wait message
    #STATUS_COOLING                                              # Sets SB-LEDs to cooling-mode
    # M109 S150                                                   # Heats the nozzle to 150C

    # M117 Hang tight...                                         # Display wait message
    # G4 P60000                                                   # Wait 1 min to stablize and cooldown the nozzle

    #STATUS_CALIBRATING_Z                                        # Sets SB-LEDs to z-calibration-mode
    #M117 Tappy Tap...                                           # Display tappy tap message
    #PROBE_EDDY_NG_TAP                                           # See: https://hackmd.io/yEF4CEntSHiFTj230CdD0Q

    SMART_PARK                                                  # Parks the toolhead near the beginning of the print

    # Uncomment for bed mesh (2 of 2)
    #STATUS_MESHING                                              # Sets SB-LEDs to bed mesh-mode
    M117 Bed mesh                                               # Display bed mesh status
    BED_MESH_CALIBRATE ADAPTIVE=1 Method=rapid_scan             # Starts bed mesh  Uncomment Method=rapid_scan for eddy rapid bed meshing

    M400                                                        # Wait for current moves to finish

    SMART_PARK                                                  # KAMP smart park

    # Heats up the nozzle to target via data from the slicer
    M117 Hotend: {target_extruder}C                             # Display target hotend temperature
    #STATUS_HEATING                                              # Sets SB-LEDs to heating-mode
    M107                                                        # Turns off part cooling fan
    M109 S{target_extruder}                                     # Heats the nozzle to printing temp
    
    # Gets ready to print by doing a purge line and updating the SB-LEDs
    M117 The purge...                                           # Display purge status
    #STATUS_CLEANING                                             # Sets SB-LEDs to cleaning-mode
    LINE_PURGE                                                  # KAMP line purge

    M117 Printer goes brrr                                      # Display print starting
    
    #STATUS_PRINTING                                             # Sets SB-LEDs to printing-mode
EOL
    
    # Add include to printer.cfg if needed
    if [ -f "$config_path/printer.cfg" ]; then
        if ! grep -q "^\[include $MACRO_FILE\]" "$config_path/printer.cfg"; then
            print_color "info" "Adding include to printer.cfg..."
            echo -e "\n[include $MACRO_FILE]" >> "$config_path/printer.cfg"
        fi
    fi
    
    print_color "success" "START_PRINT macro has been updated!"
    
    # Automatically restart Klipper
    restart_klipper
}

# Run the script
main
