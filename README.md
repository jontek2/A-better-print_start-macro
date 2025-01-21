<h1 align="center">
  <br>
  <img src="img/start.png" width="75""></a>
  <br>
    A better start_print macro
  <br>
</h1>

<b>NOTES:</b>

KAMP IS ALSO APPLIED IN THIS MACRO. [Other methods can be used too](https://www.printables.com/model/1035759-adaptive-purge-for-any-3d-printer-using-slicer-var)

Last, there are STATUS_ macros built into the start print sequence. These have all been commented out to prevent unknown errors. [If you have LEDs setup in your printer, look here](https://github.com/julianschill/klipper-led_effect)

<h4>This start_print macro will pass data from your slicer to your printer and perform all necessary preflight commands for a successful print on your printer running Klipper. This means heatsoak, QGL/Z-tilt, bed mesh and a primeline before each print.</h4>

<p>I have included an additional START_PRINT macro that does not call for the chamber thermistor if you do not have one. If you do not have a chamber thermistor, the alt macro has a predefined 15min heat soak timer to ensure the chamber is to temp.</p>

## :warning: Required changes in your slicer :warning:
You need to update your "Start G-code" in your slicer to be able to send data from slicer to this macro. Click on the slicer you use below and read the instructions.

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

## :warning: Required change in your printer.cfg :warning:

The start_print macro has predefined names for nevermore and chamber thermistor. Make sure that yours are named correctly. In your printer.cfg file verify the following:

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

Remember to add ```SET_PIN PIN=nevermore VALUE=0``` to your print_end macro to turn the nevermore off.

# START_PRINT Macro

> [!WARNING]  
> The macro was updated recently (2025-01-15). If you run in to any issues then please let me know by opening a issue on github.

Copy either macro and replace your old start_print/start_print macro in your printer.cfg. Then read through and uncomment parts of this macro.

<details>
<summary>With a Chamber thermistor</summary>
  
```
#####################################################################
#   A better start_print macro
#####################################################################

[gcode_macro START_PRINT]
gcode:
  # This part fetches data from your slicer. Such as bed temp and extruder temp
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer, sets absolute positioning and updates the Stealthburner leds.
    #STATUS_HOMING
    {% if printer.toolhead.homed_axes != "xyz" %}
        G28                      # Full home (XYZ)
        {% else %}
          G28 Z
    {% endif %}
    G90

    M400

    CLEAR_PAUSE

  ##  Uncomment for bed mesh (1 of 2)
  BED_MESH_CLEAR       # Clears old saved bed mesh (if any)

  # Checks if the bed temp is higher than 90c - if so then trigger a time-based heatsoak
  {% if params.BED|int > 90 %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
    #STATUS_HEATING                                      # Sets SB-leds to heating-mode
    M106 S150                                           # Turns on the PT-fan

    #  Uncomment if you have a Nevermore.
    #SET_PIN PIN=!PC13 VALUE=1                      # Turns on the nevermore
    #SET_PIN PIN=nevermore VALUE=1                      # Turns on the nevermore
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    M190 S{target_bed}                                  # Sets the target temp for the bed
    
    # For high-temp prints, use a fixed 15-minute heatsoak
    SET_DISPLAY_TEXT MSG="Heatsoak: 15min"             # Displays info
    G4 P900000                                         # Wait 15 minutes for heatsoak

  # If the bed temp is not over 90c, then handle soak based on material
  {% else %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
    #STATUS_HEATING                                      # Sets SB-leds to heating-mode
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    M190 S{target_bed}                                  # Sets the target temp for the bed
    
    # Material-based soak times with variant handling
    {% set raw_material = params.MATERIAL|default("PLA")|string|upper %}
    
    # Extract base material type by handling variants
    {% set material = namespace(type="") %}
    {% if "PLA" in raw_material %}
        {% set material.type = "PLA" %}
    {% elif "PETG" in raw_material %}
        {% set material.type = "PETG" %}
    {% elif "ABS" in raw_material %}
        {% set material.type = "ABS" %}
    {% elif "ASA" in raw_material %}
        {% set material.type = "ASA" %}
    {% elif "PC" in raw_material %}
        {% set material.type = "PC" %}
    {% elif "TPU" in raw_material %}
        {% set material.type = "TPU" %}
    {% else %}
        {% set material.type = raw_material %}
    {% endif %}

    # Define soak times
    {% set soak_time = {
        "PLA": 180000,    # 3 minutes
        "PETG": 240000,   # 4 minutes
        "ABS": 300000,    # 5 minutes
        "ASA": 300000,    # 5 minutes
        "PC": 300000,     # 5 minutes
        "TPU": 180000     # 3 minutes
    }[material.type]|default(300000) %}    # Default to 5 minutes if material not found
    
    SET_DISPLAY_TEXT MSG="Soak: {soak_time/60000|int}min ({raw_material})"
    G4 P{soak_time}
  {% endif %}

  ##  Comment out for Trident (Z_TILT_ADJUST)
  #{% if 'z_tilt' in printer and not printer.z_tilt.applied %}
  #  STATUS_LEVELING
  #  SET_DISPLAY_TEXT MSG="Z-tilt adjust"     # Displays info
  #  Z_TILT_ADJUST                            # Levels the buildplate via z_tilt_adjust
  #  G28 Z                                    # Homes Z again after z_tilt_adjust
  #{% endif %}

  ## Comment out for Voron (QUAD_GANTRY_LEVEL)
  #{% if 'quad_gantry_level' in printer and not printer.quad_gantry_level.applied %}
  #  STATUS_LEVELING
  #  SET_DISPLAY_TEXT MSG="QGL"                # Displays info
  #  QUAD_GANTRY_LEVEL                         # Levels the gantry
  #  G28 Z                                     # Homes Z again after QGL
  #{% endif %}

  SMART_PARK

  # Heating nozzle to 150 degrees. This helps with getting a correct Z-home
  #STATUS_HEATING
  SET_DISPLAY_TEXT MSG="Hotend: 150C"          # Displays info
  M109 S150                                    # Heats the nozzle to 150c

  #CLEAN_NOZZLE EXTRUDER={target_extruder}     # Pass the actual print temperature for cleaning

  #STATUS_HOMING
  # Only home Z if leveling was performed
  #{% if 'z_tilt' in printer and printer.z_tilt.applied %}
  #    G28 Z                                    # Re-home Z after z_tilt_adjust
  #{% endif %}

  #STATUS_MESHING
  ##  Uncomment for bed mesh (2 of 2)
  SET_DISPLAY_TEXT MSG="Bed mesh"    # Displays info
  BED_MESH_CALIBRATE ADAPTIVE=1                # Starts bed mesh

  SMART_PARK

  # Heats up the nozzle up to target via data from slicer
  SET_DISPLAY_TEXT MSG="Hotend: {target_extruder}C"             # Displays info
  #STATUS_HEATING                                                # Sets SB-leds to heating-mode
  M107                                                          # Turns off partcooling fan
  M109 S{target_extruder}                                       # Heats the nozzle to printing temp

  # Gets ready to print by doing a purge line and updating the SB-leds
  SET_DISPLAY_TEXT MSG="Printer goes brr"          # Displays info
  #STATUS_CLEANING
  LINE_PURGE
  #STATUS_PRINTING
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
  # This part fetches data from your slicer. Such as bed temp and extruder temp
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer, sets absolute positioning and updates the Stealthburner leds.
    #STATUS_HOMING
    {% if printer.toolhead.homed_axes != "xyz" %}
        G28                      # Full home (XYZ)
        {% else %}
          G28 Z
    {% endif %}
    G90

    M400

    CLEAR_PAUSE

  ##  Uncomment for bed mesh (1 of 2)
  BED_MESH_CLEAR       # Clears old saved bed mesh (if any)

  # Checks if the bed temp is higher than 90c - if so then trigger a time-based heatsoak
  {% if params.BED|int > 90 %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
    #STATUS_HEATING                                      # Sets SB-leds to heating-mode
    M106 S150                                           # Turns on the PT-fan

    #  Uncomment if you have a Nevermore.
    #SET_PIN PIN=!PC13 VALUE=1                      # Turns on the nevermore
    #SET_PIN PIN=nevermore VALUE=1                      # Turns on the nevermore
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    M190 S{target_bed}                                  # Sets the target temp for the bed
    
    # For high-temp prints, use a fixed 15-minute heatsoak
    SET_DISPLAY_TEXT MSG="Heatsoak: 15min"             # Displays info
    G4 P900000                                         # Wait 15 minutes for heatsoak

  # If the bed temp is not over 90c, then handle soak based on material
  {% else %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
    #STATUS_HEATING                                      # Sets SB-leds to heating-mode
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    M190 S{target_bed}                                  # Sets the target temp for the bed
    
    # Material-based soak times with variant handling
    {% set raw_material = params.MATERIAL|default("PLA")|string|upper %}
    
    # Extract base material type by handling variants
    {% set material = namespace(type="") %}
    {% if "PLA" in raw_material %}
        {% set material.type = "PLA" %}
    {% elif "PETG" in raw_material %}
        {% set material.type = "PETG" %}
    {% elif "ABS" in raw_material %}
        {% set material.type = "ABS" %}
    {% elif "ASA" in raw_material %}
        {% set material.type = "ASA" %}
    {% elif "PC" in raw_material %}
        {% set material.type = "PC" %}
    {% elif "TPU" in raw_material %}
        {% set material.type = "TPU" %}
    {% else %}
        {% set material.type = raw_material %}
    {% endif %}

    # Define soak times
    {% set soak_time = {
        "PLA": 180000,    # 3 minutes
        "PETG": 240000,   # 4 minutes
        "ABS": 300000,    # 5 minutes
        "ASA": 300000,    # 5 minutes
        "PC": 300000,     # 5 minutes
        "TPU": 180000     # 3 minutes
    }[material.type]|default(300000) %}    # Default to 5 minutes if material not found
    
    SET_DISPLAY_TEXT MSG="Soak: {soak_time/60000|int}min ({raw_material})"
    G4 P{soak_time}
  {% endif %}

  ##  Comment out for Trident (Z_TILT_ADJUST)
  #{% if 'z_tilt' in printer and not printer.z_tilt.applied %}
  #  STATUS_LEVELING
  #  SET_DISPLAY_TEXT MSG="Z-tilt adjust"     # Displays info
  #  Z_TILT_ADJUST                            # Levels the buildplate via z_tilt_adjust
  #  G28 Z                                    # Homes Z again after z_tilt_adjust
  #{% endif %}

  ## Comment out for Voron (QUAD_GANTRY_LEVEL)
  #{% if 'quad_gantry_level' in printer and not printer.quad_gantry_level.applied %}
  #  STATUS_LEVELING
  #  SET_DISPLAY_TEXT MSG="QGL"                # Displays info
  #  QUAD_GANTRY_LEVEL                         # Levels the gantry
  #  G28 Z                                     # Homes Z again after QGL
  #{% endif %}

  SMART_PARK

  # Heating nozzle to 150 degrees. This helps with getting a correct Z-home
  #STATUS_HEATING
  SET_DISPLAY_TEXT MSG="Hotend: 150C"          # Displays info
  M109 S150                                    # Heats the nozzle to 150c

  #CLEAN_NOZZLE EXTRUDER={target_extruder}     # Pass the actual print temperature for cleaning

  #STATUS_HOMING
  # Only home Z if leveling was performed
  #{% if 'z_tilt' in printer and printer.z_tilt.applied %}
  #    G28 Z                                    # Re-home Z after z_tilt_adjust
  #{% endif %}

  #STATUS_MESHING
  ##  Uncomment for bed mesh (2 of 2)
  SET_DISPLAY_TEXT MSG="Bed mesh"    # Displays info
  BED_MESH_CALIBRATE ADAPTIVE=1                # Starts bed mesh

  SMART_PARK

  # Heats up the nozzle up to target via data from slicer
  SET_DISPLAY_TEXT MSG="Hotend: {target_extruder}C"             # Displays info
  #STATUS_HEATING                                                # Sets SB-leds to heating-mode
  M107                                                          # Turns off partcooling fan
  M109 S{target_extruder}                                       # Heats the nozzle to printing temp

  # Gets ready to print by doing a purge line and updating the SB-leds
  SET_DISPLAY_TEXT MSG="Printer goes brr"          # Displays info
  #STATUS_CLEANING
  LINE_PURGE
  #STATUS_PRINTING
```
</details>

## Changelog

2025-01-11: Initial creation 

## Interested in more macros?

Hungry for more macromania? Make sure to check out these awesome links.

- [Mjonuschat optimized bed leveling macros for](https://mjonuschat.github.io/voron-mods/docs/guides/optimized-bed-leveling-macros/)
- [Ellis Useful Macros](https://ellis3dp.com/Print-Tuning-Guide/articles/index_useful_macros.html)
- [Voron Klipper Macros](https://github.com/The-Conglomerate/Voron-Klipper-Common/)
- [KAMP](https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging)
- [Klipper Shake&Tune plugin](https://github.com/Frix-x/klippain-shaketune)


## Credits

A big thank you to the Voron Communuity for helping make this macro. 

## Feedback

If you have feedback please open an issue on github.
