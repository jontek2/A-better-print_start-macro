<h1 align="center">
  <br>
  <img src="img/start.png" width="75""></a>
  <br>
    A better start_print macro
  <br>
</h1>

<b>NOTES:</b>

[KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging) IS ALSO APPLIED IN THIS MACRO. [Other methods can be used too](https://www.printables.com/model/1035759-adaptive-purge-for-any-3d-printer-using-slicer-var)

There are STATUS_ macros built into the start print sequence. These have all been commented out to prevent unknown errors. [If you have LEDs setup in your printer, look here](https://github.com/julianschill/klipper-led_effect)

<h4>This start_print macro will pass data from your slicer to your printer and perform all necessary preflight commands for a successful print on your printer running Klipper. This means heatsoak, QGL/Z-tilt, bed mesh and a primeline before each print.</h4>

<p>I have included an additional START_PRINT macro that does not call for the chamber thermistor if you do not have one. If you do not have a chamber thermistor, the alt macro has a predefined 15min heat soak timer to ensure the chamber is to temp.</p>

## :warning: Required changes in your slicer :warning:
You need to replace your "Start G-code" in your slicer to be able to send data from slicer to this macro. Click on the slicer you use below and read the instructions.

<details>
<summary>SuperSlicer</summary>
In Superslicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops OrcaSlicer from sending temp waits separately
M140 S0
START_PRINT EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature] MATERIAL=[filament_type]
```
</details>
<details>
<summary>OrcaSlicer</summary>
In OrcaSlicer go to "Printer settings" -> "Machine start g-code" and update it to:

```
M104 S0 ; Stops OrcaSlicer from sending temp waits separately
M140 S0
START_PRINT EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature] MATERIAL=[filament_type]
```
</details>
<details>
<summary>PrusaSlicer</summary>

In PrusaSlicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops PrusaSlicer from sending temp waits separately
M140 S0
start_print EXTRUDER=[first_layer_temperature[initial_extruder]] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature] MATERIAL=[filament_vendor]
```
</details>
<details>
<summary>Cura</summary>

In Cura go to "Settings" -> "Printer" -> "Manage printers" -> "Machine settings" -> "Start G-code" and update it to:

```
start_print EXTRUDER={material_print_temperature_layer_0} BED={material_bed_temperature_layer_0} CHAMBER={build_volume_temperature} MATERIAL={material_type}
```
</details>

## :warning: OPTIONAL changes in your printer configuration :warning:

The start_print macro has predefined names for nevermore and chamber thermistor. If you are adding a nevermore and/or a chamnber thermistor, make sure that yours are named correctly. In your printer.cfg file verify the following:

**Chamber thermistor**:
Make sure chamber thermistor is named "chamber" and update XXX.

```
[temperature_sensor chamber]
sensor_type:  XXX
sensor_pin:   XXX
```

**Nevermore**:
Make sure nevermore is named "nevermore" and update XXX.

```
[output_pin nevermore]
pin: XXX
value: 0
shutdown_value: 0
```

Remember to add ```SET_PIN PIN=nevermore VALUE=0``` to your [End Print Macro](https://github.com/ss1gohan13/A-Better-End-Print-Macro) to turn the nevermore off.

# START_PRINT Macro

> [!WARNING]  
> The macro was updated recently (02-01-2025). If you run in to any issues then please let me know by opening a issue on github.

Copy either macro and replace your old print_start/start_print macro in your printer configuration (e.g. printer.cfg, macros.cfg, ect). Then read through and uncomment parts of this macro.

<details>
<summary>With a Chamber thermistor</summary>
  
```
#####################################################################
#   A better start_print macro
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
  #STATUS_HOMING                                                    # Sets SB-LEDs to homing-mode

  {% if not 'xyz' in printer.toolhead.homed_axes %}
      # If not fully homed, check if X and Y are homed
      {% if not ('x' in printer.toolhead.homed_axes and 'y' in printer.toolhead.homed_axes) %}
          # If X or Y not homed, do full homing
          G28
      {% else %}
          # If only X and Y are homed, check if Z is homed
          {% if not 'z' in printer.toolhead.homed_axes %}
              # If Z is not homed, home Z
              G28 Z
          {% endif %}
      {% endif %}
  {% endif %}
                
  G90                                                             # Use absolute/relative coordinates
  M400                                                            # Wait for current moves to finish
  CLEAR_PAUSE                                                     # Clear any existing pause state

  # Uncomment for bed mesh (1 of 2)
  BED_MESH_CLEAR                                                  # Clears old saved bed mesh (if any)

  # Checks if the bed temp is higher than 90C - if so, then trigger a heat soak.
  {% if params.BED|int > 90 %}
    M117 Bed: {target_bed}C                                      # Display bed temperature
    #STATUS_HEATING                                              # Sets SB-LEDs to heating-mode
    M106 S255                                                    # Turns on the PT-fan
    # Uncomment if you have a Nevermore.
    SET_PIN PIN=nevermore VALUE=1                                # Turns on the Nevermore
    G1 X{x_wait} Y{y_wait} Z15 F9000                            # Go to the center of the bed
    M190 S{target_bed}                                          # Sets the target temp for the bed
    M117 Heatsoak: {target_chamber}C                            # Display heatsoak info
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for the chamber to reach the desired temp

  # If the bed temp is not over 90c, then handle soak based on material
  {% else %}
    M117 Bed: {target_bed}C                                     # Display bed temperature
    #STATUS_HEATING                                              # Sets SB-leds to heating-mode
    G1 X{x_wait} Y{y_wait} Z15 F9000                            # Go to center of the bed
    M190 S{target_bed}                                          # Sets the target temp for the bed
    
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
    
    M117 Soak: {soak_time/60000|int}min ({raw_material})        # Display soak time and material
    G4 P{soak_time}                                             # Execute soak timer
  {% endif %}

  #   # Comment out for Trident (Z_TILT_ADJUST)
  # {% if 'z_tilt' in printer and not printer.z_tilt.applied %}
  #   #STATUS_LEVELING                                            # Sets SB-LEDs to leveling-mode
  #   M117 Z-tilt adjust                                         # Display Z-tilt adjustment
  #   Z_TILT_ADJUST                                              # Levels the buildplate via z_tilt_adjust
  #   G28 Z                                                      # Homes Z again after z_tilt_adjust
  # {% endif %}

  # Uncomment for V2 (Quad gantry level AKA QGL)
  #{% if printer.quad_gantry_level.applied == False %}
  #  #STATUS_LEVELING                                             # Sets SB-LEDs to leveling-mode
  #  M117 QGL                                                    # Display QGL status
  #  QUAD_GANTRY_LEVEL                                           # Levels the gantry
  #  #STATUS_HOMING                                               # Sets SB-LEDs to homing-mode
  #  G28 Z                                                       # Homes Z again after QGL
  #{% endif %}

  # Heating the nozzle to 150C. This helps with getting a correct Z-home
  #STATUS_HEATING                                                # Sets SB-LEDs to heating-mode
  M117 Hotend: 150C                                             # Display hotend temperature
  M109 S150                                                     # Heats the nozzle to 150C

  #STATUS_CLEANING                                               # Sets SB-LEDs to cleaning-mode
  CLEAN_NOZZLE EXTRUDER={target_extruder}                      # Clean nozzle before printing

  SMART_PARK                                                    # Parks the toolhead neat the beginning of the print

  # Uncomment for bed mesh (2 of 2)
  #STATUS_MESHING                                               # Sets SB-LEDs to bed mesh-mode
  M117 Bed mesh                                                # Display bed mesh status
  BED_MESH_CALIBRATE ADAPTIVE=1                                # Starts bed mesh

  M400                                                         # Wait for current moves to finish

  SMART_PARK                                                   # KAMP smart park

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
```
</details>

<details>
<summary>Without a Chamber thermistor (15 min soak)</summary>
  
```
#####################################################################
#   A better start_print macro
#####################################################################

[gcode_macro START_PRINT]
gcode:
  # This part fetches data from your slicer, such as bed temp, extruder temp, and the size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer, sets absolute positioning, and updates the Stealthburner LEDs.
  #STATUS_HOMING                                                    # Sets SB-LEDs to homing-mode

  {% if not 'xyz' in printer.toolhead.homed_axes %}
      # If not fully homed, check if X and Y are homed
      {% if not ('x' in printer.toolhead.homed_axes and 'y' in printer.toolhead.homed_axes) %}
          # If X or Y not homed, do full homing
          G28
      {% else %}
          # If only X and Y are homed, check if Z is homed
          {% if not 'z' in printer.toolhead.homed_axes %}
              # If Z is not homed, home Z
              G28 Z
          {% endif %}
      {% endif %}
  {% endif %}
                
  G90                                                             # Use absolute/relative coordinates
  M400                                                            # Wait for current moves to finish
  CLEAR_PAUSE                                                     # Clear any existing pause state

  # Uncomment for bed mesh (1 of 2)
  BED_MESH_CLEAR                                                  # Clears old saved bed mesh (if any)

  # Checks if the bed temp is higher than 90C - if so, then trigger a fixed 15-minute heatsoak
  {% if params.BED|int > 90 %}
    M117 Bed: {target_bed}C                                      # Display bed temperature
    #STATUS_HEATING                                              # Sets SB-LEDs to heating-mode
    M106 S255                                                    # Turns on the PT-fan at full speed for high temp
    # Uncomment if you have a Nevermore.
    #SET_PIN PIN=nevermore VALUE=1                               # Turns on the Nevermore
    G1 X{x_wait} Y{y_wait} Z15 F9000                            # Go to the center of the bed
    M190 S{target_bed}                                          # Sets the target temp for the bed
    M117 High Temp Heatsoak: 15min                              # Display heatsoak info
    G4 P900000                                                  # Wait 15 minutes for heatsoak

  # If the bed temp is not over 90c, then handle soak based on material
  {% else %}
    M117 Bed: {target_bed}C                                     # Display bed temperature
    #STATUS_HEATING                                              # Sets SB-leds to heating-mode
    M106 S150                                                    # Turns on the PT-fan at lower speed for low temp
    G1 X{x_wait} Y{y_wait} Z15 F9000                            # Go to center of the bed
    M190 S{target_bed}                                          # Sets the target temp for the bed
    
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
    
    M117 Soak: {soak_time/60000|int}min ({raw_material})        # Display soak time and material
    G4 P{soak_time}                                             # Execute soak timer
  {% endif %}

  # Comment out for Trident (Z_TILT_ADJUST)
  #{% if 'z_tilt' in printer and not printer.z_tilt.applied %}
  #  STATUS_LEVELING                                            # Sets SB-LEDs to leveling-mode
  #  M117 Z-tilt adjust                                        # Display Z-tilt adjustment
  #  Z_TILT_ADJUST                                              # Levels the buildplate via z_tilt_adjust
  #  G28 Z                                                      # Homes Z again after z_tilt_adjust
  #{% endif %}

  # Comment out for V2 (Quad gantry level AKA QGL)
  #{% if printer.quad_gantry_level.applied == False %}
  #  STATUS_LEVELING                                             # Sets SB-LEDs to leveling-mode
  #  M117 QGL                                                    # Display QGL status
  #  QUAD_GANTRY_LEVEL                                           # Levels the gantry
  #  STATUS_HOMING                                               # Sets SB-LEDs to homing-mode
  #  G28 Z                                                       # Homes Z again after QGL
  #{% endif %}

  # Heating the nozzle to 150C. This helps with getting a correct Z-home
  #STATUS_HEATING                                                # Sets SB-LEDs to heating-mode
  M117 Hotend: 150C                                             # Display hotend temperature
  M109 S150                                                     # Heats the nozzle to 150C

  #STATUS_CLEANING                                               # Sets SB-LEDs to cleaning-mode
  CLEAN_NOZZLE EXTRUDER={target_extruder}                      # Clean nozzle before printing

  SMART_PARK                                                    # Parks the toolhead near the beginning of the print

  # Uncomment for bed mesh (2 of 2)
  #STATUS_MESHING                                               # Sets SB-LEDs to bed mesh-mode
  M117 Bed mesh                                                # Display bed mesh status
  BED_MESH_CALIBRATE ADAPTIVE=1                                # Starts bed mesh

  M400                                                         # Wait for current moves to finish

  SMART_PARK                                                   # KAMP smart park

  # Heats up the nozzle to target via data from the slicer
  M117 Hotend: {target_extruder}C                             # Display target hotend temperature
  #STATUS_HEATING                                              # Sets SB-LEDs to heating-mode
  M107                                                        # Turns off part cooling fan
  M109 S{target_extruder}                                     # Heats the nozzle to printing temp
  
  # Gets ready to print by doing a purge line and updating the SB-LEDs
  M117 Printer goes brrr                                      # Display print starting
  #STATUS_CLEANING                                             # Sets SB-LEDs to cleaning-mode
  LINE_PURGE                                                  # KAMP line purge
  
  #STATUS_PRINTING                                             # Sets SB-LEDs to printing-mode
```
</details>

## Changelog

01-11-2025: Initial creation 
02-01-2025: WTFBBQAUCE I forgot to put all of the changes down. It's been a lot of formatting, additions, ect. 

## Interested in more macros?

Hungry for more macromania? Make sure to check out these awesome links.

- [A Better End Print Macro](https://github.com/ss1gohan13/A-Better-End-Print-Macro)
- [More replacement SV08 Macros](https://github.com/ss1gohan13/SV08-Replacement-Macros)
- [Mjonuschat optimized bed leveling macros for](https://mjonuschat.github.io/voron-mods/docs/guides/optimized-bed-leveling-macros/)
- [Ellis Useful Macros](https://ellis3dp.com/Print-Tuning-Guide/articles/index_useful_macros.html)
- [Voron Klipper Macros](https://github.com/The-Conglomerate/Voron-Klipper-Common/)
- [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging)
- [Klipper Shake&Tune plugin](https://github.com/Frix-x/klippain-shaketune)


## Credits

A big thank you to the Voron Communuity for helping make this macro. 

## Feedback

If you have feedback please open an issue on github.
