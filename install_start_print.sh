#!/bin/bash
#####################################################################
# START_PRINT/PRINT_START Macro Installation Script for Klipper
# Author: ss1gohan13
# Created: 2025-02-19 05:34:53 UTC
# Repository: https://github.com/ss1gohan13/A-better-print_start-macro-SV08
#####################################################################

# Configuration
DEFAULT_CONFIG_PATH="$HOME/printer_data/config"
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
    
    # Create backup
    print_color "info" "Creating backup..."
    cp "$macro_path" "$macro_path$BACKUP_SUFFIX"
    
    # Install macro
    print_color "info" "Installing START_PRINT macro..."
    cat > "$macro_path" << 'EOL'
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

[gcode_macro PRINT_START]
gcode:
    START_PRINT {rawparams}
EOL
    
    # Add include to printer.cfg if needed
    if [ -f "$config_path/printer.cfg" ]; then
        if ! grep -q "^\[include $MACRO_FILE\]" "$config_path/printer.cfg"; then
            print_color "info" "Adding include to printer.cfg..."
            echo -e "\n[include $MACRO_FILE]" >> "$config_path/printer.cfg"
        fi
    fi
    
    print_color "success" "Installation complete!"
    print_color "info" "Would you like to restart Klipper? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if curl -s "http://localhost:7125/printer/firmware_restart" -H "Content-Type: application/json" -X POST; then
            print_color "success" "Klipper restarting..."
        else
            print_color "error" "Failed to restart Klipper"
        fi
    fi
}

# Run the script
main
