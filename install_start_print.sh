#!/bin/bash
#####################################################################
# START_PRINT/PRINT_START Macro Installation Script for Klipper
# Author: ss1gohan13
# Created: 2025-02-19 06:16:31 UTC
# Repository: https://github.com/ss1gohan13/A-better-print_start-macro
#####################################################################

# Configuration
DEFAULT_CONFIG_PATH="$HOME/printer_data/config"
BACKUP_DIR="$DEFAULT_CONFIG_PATH/backup"
MACRO_FILE="macros.cfg"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d_%H%M%S)"
TAP_METHOD="none"

# Print colored output
print_color() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

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

# Select which tap/Z-offset method START_PRINT should use
select_tap_method() {
    local selection=""

    echo
    print_color "info" "Select the tap/Z-offset method for START_PRINT:"
    echo "  1) None"
    echo "  2) eddy-ng"
    echo "  3) Native Klipper Eddy Tap"
    echo

    # Read from /dev/tty so this still works when launched via curl | bash
    if [ -r /dev/tty ]; then
        read -r -p "Selection [1-3] (default: 1): " selection < /dev/tty
    else
        print_color "warning" "No interactive terminal detected. Tap support will remain disabled."
        TAP_METHOD="none"
        return
    fi

    case "$selection" in
        2)
            TAP_METHOD="eddy-ng"
            print_color "success" "eddy-ng tap selected"
            ;;
        3)
            TAP_METHOD="native-eddy"
            print_color "success" "Native Klipper Eddy Tap selected"
            ;;
        1|"")
            TAP_METHOD="none"
            print_color "info" "Tap support disabled"
            ;;
        *)
            TAP_METHOD="none"
            print_color "warning" "Invalid selection. Tap support will remain disabled."
            ;;
    esac
}

# Remove a complete Klipper config section without stopping at blank lines
remove_macro_section() {
    local macro_name="$1"
    local input_file="$2"
    local temp_file

    temp_file=$(mktemp) || {
        print_color "error" "Failed to create temporary file"
        exit 1
    }

    awk -v target="[gcode_macro ${macro_name}]" '
        BEGIN { skip = 0 }

        $0 == target {
            skip = 1
            next
        }

        skip && $0 ~ /^\[[^]]+\][[:space:]]*$/ {
            skip = 0
        }

        !skip {
            print
        }
    ' "$input_file" > "$temp_file" || {
        rm -f "$temp_file"
        print_color "error" "Failed to remove existing ${macro_name} macro"
        exit 1
    }

    cat "$temp_file" > "$input_file" || {
        rm -f "$temp_file"
        print_color "error" "Failed to update $input_file"
        exit 1
    }

    rm -f "$temp_file"
}

# Write the START_PRINT macro and insert the selected tap method
write_start_print_macro() {
    local macro_path="$1"

    # Ensure the new section starts on a clean line
    printf '\n' >> "$macro_path"

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
            SET_PIN PIN=nevermore VALUE=1                        # Turns on the Nevermore
        {% endif %}

        G1 X{x_wait} Y{y_wait} Z15 F9000                         # Go to the center of the bed
        M190 S{target_bed}                                       # Sets the target temp for the bed
        
        # Start chamber heating progress monitoring
        M117 Monitoring chamber: {target_chamber}C               # Display chamber monitoring status

        # Conditional check for chamber thermistor
        {% if printer["temperature_sensor chamber"] is defined %}
            TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}
        {% else %}
            M117 Soak: 15min (No chamber thermistor)
            G4 P900000                                           # Wait 15 minutes for heatsoak
        {% endif %}

    # If the bed temp is not over 90C, then handle soak based on material
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
        }[material.type]|default(300000) %}
        
        M117 Soak: {soak_time/60000|int}min ({raw_material})
        G4 P{soak_time}
    {% endif %}
    
    # Check if GANTRY_LEVELING macro exists, use it if available
    {% if printer.configfile.config['gcode_macro GANTRY_LEVELING'] is defined %}
        #STATUS_LEVELING
        M117 Gantry Leveling...
        GANTRY_LEVELING

    {% else %}
        # Fallback to traditional method if GANTRY_LEVELING doesn't exist

        {% if 'z_tilt' in printer %}
            #STATUS_LEVELING
            M117 Z-tilt...
            Z_TILT_ADJUST

        {% elif 'quad_gantry_level' in printer %}
            #STATUS_LEVELING
            M117 QGL...
            QUAD_GANTRY_LEVEL

        {% endif %}
    {% endif %}

    # Conditional check to ensure Z is homed after leveling procedures
    {% if 'z' not in printer.toolhead.homed_axes %}
        #STATUS_HOMING
        M117 Z homing
        G28 Z
    {% endif %}

    # Heating the nozzle to 150C. This helps with getting a correct Z-home
    #STATUS_HEATING
    M117 Hotend: 150C
    M109 S150

    M117 Cleaning the nozzle...
    #STATUS_CLEANING
    CLEAN_NOZZLE #EXTRUDER={target_extruder}

    M400
    
    M107                    # Disable part cooling - there was an issue with Eddy tapping with fans spinning.
    G4 P2000                # Allow fans to fully spin down / settle

    M400

    #STATUS_CALIBRATING_Z
    #M117 Tappy Tap...
EOL

    # Insert the selected tap method
    case "$TAP_METHOD" in
        eddy-ng)
            cat >> "$macro_path" << 'EOL'
    PROBE_EDDY_NG_TAP                                            # eddy-ng Auto Z offset
    #SET_Z_FROM_PROBE METHOD=tap                                 # Native Klipper Auto Z offset with Eddy Tap
EOL
            ;;

        native-eddy)
            cat >> "$macro_path" << 'EOL'
    #PROBE_EDDY_NG_TAP                                           # eddy-ng Auto Z offset
    SET_Z_FROM_PROBE METHOD=tap                                  # Native Klipper Auto Z offset with Eddy Tap
EOL
            ;;

        *)
            cat >> "$macro_path" << 'EOL'
    #PROBE_EDDY_NG_TAP                                           # eddy-ng Auto Z offset
    #SET_Z_FROM_PROBE METHOD=tap                                 # Native Klipper Auto Z offset with Eddy Tap
EOL
            ;;
    esac

    cat >> "$macro_path" << 'EOL'

    # Uncomment for bed mesh (2 of 2)
    #STATUS_MESHING
    M117 Bed mesh
    BED_MESH_CALIBRATE ADAPTIVE=1 #Method=rapid_scan             # Starts bed mesh. Uncomment Method=rapid_scan for Eddy rapid bed meshing

    M400                                                        # Wait for current moves to finish

    SMART_PARK                                                  # KAMP smart park

    # Heats up the nozzle to target via data from the slicer
    M117 Hotend: {target_extruder}C
    #STATUS_HEATING
    M107                                                        # Turns off part cooling fan
    M109 S{target_extruder}                                     # Heats the nozzle to printing temp
    
    # Gets ready to print by doing a purge line and updating the SB-LEDs
    M117 The purge...
    #STATUS_CLEANING
    LINE_PURGE                                                  # KAMP line purge

    M400                                                        # Wait for the purge moves to finish

    M117 Printer goes brrr
    
    #STATUS_PRINTING
EOL
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
    local backup_file
    
    print_color "info" "Starting installation..."
    
    # Check config directory
    if [ ! -d "$config_path" ]; then
        print_color "error" "Config directory not found: $config_path"
        exit 1
    fi

    # Select tap/Z-offset method before modifying any files
    select_tap_method
    
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
    backup_file="$BACKUP_DIR/$(basename "$MACRO_FILE")$BACKUP_SUFFIX"

    print_color "info" "Creating backup in: $backup_file"

    cp "$macro_path" "$backup_file" || {
        print_color "error" "Failed to create backup"
        exit 1
    }
    
    # Remove existing START_PRINT and PRINT_START sections if they exist
    print_color "info" "Updating START_PRINT macro..."

    remove_macro_section "START_PRINT" "$macro_path"
    remove_macro_section "PRINT_START" "$macro_path"

    # Append new START_PRINT macro
    write_start_print_macro "$macro_path"
    
    # Add include to printer.cfg if needed
    if [ -f "$config_path/printer.cfg" ]; then
        if ! grep -Fqx "[include $MACRO_FILE]" "$config_path/printer.cfg"; then
            print_color "info" "Adding include to printer.cfg..."
            sed -i "1i [include $MACRO_FILE]" "$config_path/printer.cfg"
        fi
    fi
    
    print_color "success" "START_PRINT macro has been updated!"

    case "$TAP_METHOD" in
        eddy-ng)
            print_color "info" "Installed START_PRINT with eddy-ng tap enabled"
            ;;

        native-eddy)
            print_color "info" "Installed START_PRINT with native Klipper Eddy Tap enabled"
            ;;

        *)
            print_color "info" "Installed START_PRINT with tap support disabled"
            ;;
    esac
    
    # Automatically restart Klipper
    restart_klipper
}

# Run the script
main
