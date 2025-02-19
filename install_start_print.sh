#!/bin/bash
#####################################################################
# START_PRINT/PRINT_START Macro Installation Script for Klipper
# Author: ss1gohan13
# Created: 2025-02-18 23:37:17 UTC
# Repository: https://github.com/ss1gohan13/A-better-print_start-macro-SV08
#####################################################################

# Default path for Klipper config (can be overridden)
DEFAULT_CONFIG_PATH="$HOME/printer_data/config"
# Common macro file names
MACRO_FILES=(
    "macros.cfg"
    "printer_macros.cfg"
    "start_print_macro.cfg"
    "custom_macros.cfg"
    "print_start_macros.cfg"
    "print_macros.cfg"
    "sovol-macros.cfg"
)
BACKUP_SUFFIX=".backup-$(date +%Y%m%d_%H%M%S)"

START_PRINT_CONTENT=$(cat << 'EOL'
#####################################################################
#------------------- A better start_print macro --------------------#
# Created by: ss1gohan13
# Created on: 2025-02-18 23:37:17 UTC
# Version: 1.0.0
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
        G28                             # Full home if not already homed
    {% elif 'z' not in printer.toolhead.homed_axes %}
        G28 Z                          # Home Z if only Z is unhomed
    {% endif %}
                
    G90                                                             # Use absolute/relative coordinates
    M400                                                            # Wait for current moves to finish
    CLEAR_PAUSE                                                     # Clear any existing pause state

    # Uncomment for bed mesh (1 of 2)
    BED_MESH_CLEAR                                                  # Clears old saved bed mesh (if any)

    # Checks if the bed temp is higher than 90C - if so, then trigger a heat soak.
    {% if params.BED|int > 90 %}
        M117 Bed: {target_bed}C                                     # Display bed temperature
        #STATUS_HEATING                                             # Sets SB-LEDs to heating-mode
        M106 S255                                                   # Turns on the PT-fan
        # Conditional check for nevermore pin
        {% if 'nevermore' in printer.configfile.settings %}
            SET_PIN PIN=nevermore VALUE=1                           # Turns on the Nevermore
        {% endif %}
        G1 X{x_wait} Y{y_wait} Z15 F9000                          # Go to the center of the bed
        M190 S{target_bed}                                         # Sets the target temp for the bed
        M117 Heatsoak: {target_chamber}C                           # Display heatsoak info
        # Conditional check for chamber thermistor
        {% if printer["temperature_sensor chamber"] is defined %}
            TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for the chamber to reach the desired temp
        {% else %}
            G4 P900000                                             # Wait 15 minutes for heatsoak
        {% endif %}

    # If the bed temp is not over 90c, then handle soak based on material
    {% else %}
        M117 Bed: {target_bed}C                                    # Display bed temperature
        #STATUS_HEATING                                            # Sets SB-leds to heating-mode
        G1 X{x_wait} Y{y_wait} Z15 F9000                         # Go to center of the bed
        M190 S{target_bed}                                        # Sets the target temp for the bed
        
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
        }[material.type]|default(300000) %}    # Default to 5 minutes if material not found
        
        M117 Soak: {soak_time/60000|int}min ({raw_material})      # Display soak time and material
        G4 P{soak_time}                                           # Execute soak timer
    {% endif %}

    # Conditional method for Z_TILT_ADJUST and QUAD_GANTRY_LEVEL
    {% if 'z_tilt' in printer %}
        {% if not printer.z_tilt.applied %}
            #STATUS_LEVELING                                       # Sets SB-LEDs to leveling-mode
            M117 Z-tilt adjust                                    # Display Z-tilt adjustment
            Z_TILT_ADJUST                                         # Levels the buildplate via z_tilt_adjust
            G28 Z                                                 # Homes Z again after z_tilt_adjust
        {% endif %}
    {% elif 'quad_gantry_level' in printer %}
        {% if not printer.quad_gantry_level.applied %}
            #STATUS_LEVELING                                      # Sets SB-LEDs to leveling-mode
            M117 QGL                                             # Display QGL status
            QUAD_GANTRY_LEVEL                                    # Levels the gantry
            #STATUS_HOMING                                        # Sets SB-LEDs to homing-mode
            G28 Z                                                # Homes Z again after QGL
        {% endif %}
    {% endif %}

    # Heating the nozzle to 150C. This helps with getting a correct Z-home
    #STATUS_HEATING                                              # Sets SB-LEDs to heating-mode
    M117 Hotend: 150C                                           # Display hotend temperature
    M109 S150                                                   # Heats the nozzle to 150C

    #STATUS_CLEANING                                             # Sets SB-LEDs to cleaning-mode
    CLEAN_NOZZLE EXTRUDER={target_extruder}                    # Clean nozzle before printing

    #STATUS_COOLING                                              # Sets SB-LEDs to cooling-mode
    #M109 S150                                                   # Heats the nozzle to 150C

    #M117 Tappy Tap                                             # Display tappy tap message
    #PROBE_EDDY_NG_TAP                                          # See: https://hackmd.io/yEF4CEntSHiFTj230CdD0Q

    SMART_PARK                                                  # Parks the toolhead near the beginning of the print

    # Uncomment for bed mesh (2 of 2)
    #STATUS_MESHING                                             # Sets SB-LEDs to bed mesh-mode
    M117 Bed mesh                                              # Display bed mesh status
    BED_MESH_CALIBRATE ADAPTIVE=1                              # Starts bed mesh

    M400                                                       # Wait for current moves to finish

    SMART_PARK                                                 # KAMP smart park

    # Heats up the nozzle to target via data from the slicer
    M117 Hotend: {target_extruder}C                           # Display target hotend temperature
    #STATUS_HEATING                                            # Sets SB-LEDs to heating-mode
    M107                                                      # Turns off part cooling fan
    M109 S{target_extruder}                                  # Heats the nozzle to printing temp
    
    # Gets ready to print by doing a purge line and updating the SB-LEDs
    M117 The purge...                                         # Display purge status
    #STATUS_CLEANING                                          # Sets SB-LEDs to cleaning-mode
    LINE_PURGE                                               # KAMP line purge

    M117 Printer goes brrr                                   # Display print starting
    
    #STATUS_PRINTING                                          # Sets SB-LEDs to printing-mode

# Add compatibility alias for PRINT_START
[gcode_macro PRINT_START]
gcode:
    START_PRINT {rawparams}
EOL
)

# Print colored output
print_color() {
    case $1 in
        "info") echo -e "\e[34m[INFO]\e[0m $2" ;;
        "success") echo -e "\e[32m[SUCCESS]\e[0m $2" ;;
        "warning") echo -e "\e[33m[WARNING]\e[0m $2" ;;
        "error") echo -e "\e[31m[ERROR]\e[0m $2" ;;
    esac
}

# Function to check if START_PRINT or PRINT_START macro exists in file
check_existing_macro() {
    local file="$1"
    if grep -q "\[gcode_macro START_PRINT\]" "$file" 2>/dev/null || grep -q "\[gcode_macro PRINT_START\]" "$file" 2>/dev/null; then
        return 0  # Found either macro
    fi
    return 1  # Neither macro found
}

# Function to find all potential macro files in printer.cfg
find_printer_includes() {
    local config_path="$1"
    local printer_cfg="$config_path/printer.cfg"
    
    if [ -f "$printer_cfg" ]; then
        grep -i "^\[include\s\+" "$printer_cfg" | sed 's/\[include\s\+\(.*\)\]/\1/' | tr -d ' '
    fi
}

# Function to find the appropriate macro file
find_macro_file() {
    local config_path="$1"
    local selected_file=""
    local found_files=()
    local includes
    
    print_color "info" "Checking printer.cfg for included macro files..."
    includes=$(find_printer_includes "$config_path")
    
    for include in $includes; do
        if [ -f "$config_path/$include" ] && grep -q "gcode_macro" "$config_path/$include" 2>/dev/null; then
            found_files+=("$include")
        fi
    done
    
    for macro_file in "${MACRO_FILES[@]}"; do
        if [ -f "$config_path/$macro_file" ]; then
            found_files+=("$macro_file")
        fi
    done
    
    if [ ${#found_files[@]} -gt 0 ]; then
        print_color "info" "Found the following potential macro files:"
        for i in "${!found_files[@]}"; do
            echo "[$((i+1))] ${found_files[$i]}"
        done
        
        if [ ${#found_files[@]} -gt 1 ]; then
            while true; do
                echo "Please select a file number (1-${#found_files[@]}) or enter a new filename:"
                read -r selection
                
                if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#found_files[@]}" ]; then
                    selected_file="${found_files[$((selection-1))]}"
                    break
                elif [[ "$selection" == *.cfg ]]; then
                    selected_file="$selection"
                    break
                else
                    print_color "error" "Invalid selection. Please try again."
                fi
            done
        else
            selected_file="${found_files[0]}"
        fi
    else
        print_color "warning" "No existing macro files found."
        echo "Please enter a name for the new macro file (default: macros.cfg):"
        read -r new_file
        selected_file="${new_file:-macros.cfg}"
    fi
    
    echo "$selected_file"
}

# Function to check if file is included in printer.cfg
check_and_add_include() {
    local config_path="$1"
    local macro_file="$2"
    local printer_cfg="$config_path/printer.cfg"
    
    if [ -f "$printer_cfg" ]; then
        if ! grep -q "^\[include $macro_file\]" "$printer_cfg"; then
            print_color "info" "Adding include statement for $macro_file to printer.cfg"
            echo -e "\n[include $macro_file]" >> "$printer_cfg"
        fi
    else
        print_color "warning" "printer.cfg not found. Please manually include $macro_file in your configuration."
    fi
}

# Main installation function
install_macro() {
    local config_path="${1:-$DEFAULT_CONFIG_PATH}"
    
    if [ ! -d "$config_path" ]; then
        print_color "error" "Config directory not found: $config_path"
        return 1
    fi

    local macro_file=$(find_macro_file "$config_path")
    local macro_path="$config_path/$macro_file"
    
    print_color "info" "Selected macro file: $macro_file"

    if [ ! -f "$macro_path" ]; then
        print_color "info" "Creating new file: $macro_file"
        touch "$macro_path"
        check_and_add_include "$config_path" "$macro_file"
    fi

    if [ ! -w "$macro_path" ]; then
        print_color "error" "Cannot write to $macro_path. Check permissions."
        return 1
    fi

    cp "$macro_path" "$macro_path$BACKUP_SUFFIX"
    print_color "info" "Backup created: $macro_path$BACKUP_SUFFIX"

    if check_existing_macro "$macro_path"; then
        print_color "warning" "Existing START_PRINT or PRINT_START macro found. Both will be replaced."
        # Remove both variations if they exist
        sed -i '/\[gcode_macro START_PRINT\]/,/^[[:space:]]*$/d' "$macro_path"
        sed -i '/\[gcode_macro PRINT_START\]/,/^[[:space:]]*$/d' "$macro_path"
    fi

    echo "$START_PRINT_CONTENT" >> "$macro_path"
    
    print_color "success" "START_PRINT and PRINT_START macros have been installed successfully in $macro_file
