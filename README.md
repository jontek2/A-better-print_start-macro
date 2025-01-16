<h1 align="center">
  <br>
  <img src="img/start.png" width="75""></a>
  <br>
    A better start_print macro (SV08 Edition)
  <br>
</h1>

<b>NOTES:</b>

KAMP IS ALSO APPLIED IN THIS MACRO - THIS IS TO GET RID OF THE LARGE, OBSCURE, PRUGE LINE THAT SOVOL CREATED:
[Other methods can be used too](https://www.printables.com/model/1035759-adaptive-purge-for-any-3d-printer-using-slicer-var)

Last, there are STATUS_ macros built into the start print sequence. These have all been commented out to prevent unknown errors. [If you have LEDs setup in your SV08, look here](https://github.com/julianschill/klipper-led_effect)

<h4>This start_print macro will pass data from your slicer to your printer and perform all necessary preflight commands for a successful print on your SV08 printer running Klipper. This means heatsoak, QGL/Z-tilt, bed mesh and a primeline before each print.</h4>


<p>In the current state, this macro requires you to have a chamber thermistor. This is necessary to achieve your set chamber temp in your slicer. If you omit the chamber thermistor from the setup, it will not look/call for the chamber thermistor</p>

## :warning: Required changes in your slicer :warning:
You need to update your "Start G-code" in your slicer to be able to send data from slicer to this macro. Click on the slicer you use below and read the instructions.

<b>NOTE:</b> The CHAMBER call can be omitted out for the SV08. If you have a thermistor, by default, when the bed is 90C or above the chamber thermistor will be called and wait until the slicer defined chamber temp. If you do not wish to use chamber thermistor, see the "No chamber thermistor" variants.

e.g. dont add `CHAMBER=[chamber_temperature]` to your slicer if you don't have a chamber thermistor.

<details>
<summary>SuperSlicer w/ chamber thermistor</summary>
In Superslicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops SuperSlicer from sending temp waits separately
M140 S0
start_print EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```
</details>
<details>
<summary>SuperSlicer w/o chamber thermistor</summary>
In Superslicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops SuperSlicer from sending temp waits separately
M140 S0
start_print EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature]
```
</details>
<details>
<summary>OrcaSlicer w/ chamber thermistor</summary>
In OrcaSlicer go to "Printer settings" -> "Machine start g-code" and update it to:

```
M104 S0 ; Stops OrcaSlicer from sending temp waits separately
M140 S0
start_print EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```
</details>
<details>
<summary>OrcaSlicer w/o chamber thermistor</summary>
In OrcaSlicer go to "Printer settings" -> "Machine start g-code" and update it to:

```
M104 S0 ; Stops OrcaSlicer from sending temp waits separately
M140 S0
start_print EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature]
```
</details>
<details>
<summary>PrusaSlicer w/ chamber thermistor</summary>

In PrusaSlicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops PrusaSlicer from sending temp waits separately
M140 S0
start_print EXTRUDER=[first_layer_temperature[initial_extruder]] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```
</details>
<details>
<summary>PrusaSlicer w/o chamber thermistor</summary>

In PrusaSlicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops PrusaSlicer from sending temp waits separately
M140 S0
start_print EXTRUDER=[first_layer_temperature[initial_extruder]] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```
</details>
<details>
<summary>Cura w/ chamber thermistor</summary>

In Cura go to "Settings" -> "Printer" -> "Manage printers" -> "Machine settings" -> "Start G-code" and update it to:

```
start_print EXTRUDER={material_print_temperature_layer_0} BED={material_bed_temperature_layer_0} CHAMBER={build_volume_temperature}
```
</details>
<details>
<summary>Cura w/o chamber thermistor</summary>

In Cura go to "Settings" -> "Printer" -> "Manage printers" -> "Machine settings" -> "Start G-code" and update it to:

```
start_print EXTRUDER={material_print_temperature_layer_0} BED={material_bed_temperature_layer_0} CHAMBER={build_volume_temperature}
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

:warning: [See how to add a chamber thermistor to the SV08](https://github.com/ss1gohan13/Sovol-SV08-Mainline/tree/main/files-used/config/options/thermistor) :warning:

**Nevermore**:
Make sure nevermore is named "nevermore" and update XXX.

```
[output_pin nevermore]
pin: XXX
value: 0
shutdown_value: 0
```

Remember to add ```SET_PIN PIN=nevermore VALUE=0``` to your print_end macro to turn the nevermore off.

<b> Since the SV08 doesn't come with a fan installed initially, I have commented out the nevermore to prevent unknown issues. If you setup a nevermore, or similar, please make sure to uncomment it in the start print sequence </b>

# SV08 START_PRINT

> [!WARNING]  
> The macro was updated recently (2025-01-15). If you run in to any issues then please let me know by opening a issue on github.

Copy either macro and replace your old start_print/start_print macro in your printer.cfg. Then read through and uncomment parts of this macro.

<details>
<summary>With a Chamber thermistor</summary>
  
```
#####################################################################
#   A better start_print macro for SV08
#####################################################################

[gcode_macro START_PRINT]
gcode:
  # This part fetches data from your slicer. Such as bed temp, extruder temp, chamber temp and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("40")|int %} #Can be commented out if needed
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer, sets absolute positioning and updates the Stealthburner leds.
  #  STATUS_HOMING         # Sets SB-leds to homing-mode
    
    {% if printer.toolhead.homed_axes != "xyz" %}
        G28                      # Full home (XYZ)
        {% else %}
          G28 Z
    {% endif %}
                
    G90

    SMART_PARK

    M400

    CLEAR_PAUSE

  ##  Uncomment for bed mesh (1 of 2)
  BED_MESH_CLEAR       # Clears old saved bed mesh (if any)

  # Checks if the bed temp is higher than 90c - if so then trigger a heatsoak.
  {% if params.BED|int > 90 %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
  #  STATUS_HEATING                                      # Sets SB-leds to heating-mode
    M106 S255                                           # Turns on the PT-fan
    ##  Uncomment if you have a Nevermore.
  #  SET_PIN PIN=nevermore VALUE=1                      # Turns on the nevermore
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    M190 S{target_bed}                                  # Sets the target temp for the bed
    SET_DISPLAY_TEXT MSG="Heatsoak: {target_chamber}C"  # Displays info
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for chamber to reach desired temp

  # If the bed temp is not over 90c, then it skips the heatsoak and just heats up to set temp with a 5min soak
  {% else %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
  #  STATUS_HEATING                                      # Sets SB-leds to heating-mode
    M190 S{target_bed}                                  # Sets the target temp for the bed
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    SET_DISPLAY_TEXT MSG="Soak for 5min"                # Displays info
    G4 P300000                                          # Waits 5 min for the bedtemp to stabilize
  {% endif %}

  ##  Uncomment for V2 (Quad gantry level AKA QGL)
  SET_DISPLAY_TEXT MSG="QGL"      # Displays info
#  STATUS_LEVELING                 # Sets SB-leds to leveling-mode
    {% if printer.quad_gantry_level.applied == False %}
        {% if "xyz" not in printer.toolhead.homed_axes %}
            G28 ; home if not already homed
            {% else %}
              G28 Z
        {% endif %}
        STATUS_LEVELING
        QUAD_GANTRY_LEVEL
        STATUS_HOMING       # Homes Z again after QGL
        G28 Z
    {% endif %}

  SMART_PARK

  # Heating nozzle to 150 degrees. This helps with getting a correct Z-home
  SET_DISPLAY_TEXT MSG="Hotend: 200C"          # Displays info
  M109 S200                                    # Heats the nozzle to 200C

 # STATUS_CLEANING

  _CLEAN_NOZZLE # See: https://github.com/ss1gohan13/SV08-Replacement-Macros/blob/main/macros/macro.cfg

  ##  Uncomment for bed mesh (2 of 2)
  SET_DISPLAY_TEXT MSG="Bed mesh"    # Displays info
  
#  STATUS_MESHING                     # Sets SB-leds to bed mesh-mode

  #BED_MESH_CALIBRATE METHOD=RAPID_SCAN ADAPTIVE=1              # Starts bed mesh for eddy
  BED_MESH_CALIBRATE ADAPTIVE=1                  # Starts bed mesh

  M400

#  STATUS_READY

  SMART_PARK

  # Heats up the nozzle up to target via data from slicer
  SET_DISPLAY_TEXT MSG="Hotend: {target_extruder}C"             # Displays info
#  STATUS_HEATING                                                # Sets SB-leds to heating-mode
  M107                                                          # Turns off partcooling fan
  M109 S{target_extruder}                                       # Heats the nozzle to printing temp
  
  # Gets ready to print by doing a purge line and updating the SB-leds
  SET_DISPLAY_TEXT MSG="The purge..."          # Displays info
#  STATUS_CLEANING

  SET_DISPLAY_TEXT MSG="Printer goes brrr"          # Displays info
  
  LINE_PURGE
#  STATUS_PRINTING
```
</details>

<details>
<summary>Without a Chamber thermistor</summary>
  
```
#####################################################################
#   A better start_print macro for SV08
#####################################################################

[gcode_macro START_PRINT]
gcode:
  # This part fetches data from your slicer. Such as bed temp, extruder temp, chamber temp and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("40")|int %} #Can be commented out if needed
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer, sets absolute positioning and updates the Stealthburner leds.
  #  STATUS_HOMING         # Sets SB-leds to homing-mode
    
    {% if printer.toolhead.homed_axes != "xyz" %}
        G28                      # Full home (XYZ)
        {% else %}
          G28 Z
    {% endif %}
                
    G90

    SMART_PARK

    M400

    CLEAR_PAUSE

  ##  Uncomment for bed mesh (1 of 2)
  BED_MESH_CLEAR       # Clears old saved bed mesh (if any)

  # Checks if the bed temp is higher than 90c - if so then trigger a heatsoak.
  #{% if params.BED|int > 90 %}
  #  SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
  #  STATUS_HEATING                                      # Sets SB-leds to heating-mode
  #  M106 S255                                           # Turns on the PT-fan
  #  ##  Uncomment if you have a Nevermore.
  #  SET_PIN PIN=nevermore VALUE=1                      # Turns on the nevermore
  #  G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
  #  M190 S{target_bed}                                  # Sets the target temp for the bed
  #  SET_DISPLAY_TEXT MSG="Heatsoak: {target_chamber}C"  # Displays info
  #  TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for chamber to reach desired temp

  # If the bed temp is not over 90c, then it skips the heatsoak and just heats up to set temp with a 5min soak
  #{% else %}
SET_DISPLAY_TEXT MSG="Bed: {target_bed}C"           # Displays info
#STATUS_HEATING                                      # Sets SB-leds to heating-mode
M190 S{target_bed}                                  # Sets the target temp for the bed
G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
SET_DISPLAY_TEXT MSG="Soak for 5min"                # Displays info
G4 P300000                                          # Waits 5 min for the bedtemp to stabilize
  #{% endif %}

  ##  Uncomment for V2 (Quad gantry level AKA QGL)
  SET_DISPLAY_TEXT MSG="QGL"      # Displays info
#  STATUS_LEVELING                 # Sets SB-leds to leveling-mode
    {% if printer.quad_gantry_level.applied == False %}
        {% if "xyz" not in printer.toolhead.homed_axes %}
            G28 ; home if not already homed
            {% else %}
              G28 Z
        {% endif %}
        STATUS_LEVELING
        QUAD_GANTRY_LEVEL
        STATUS_HOMING       # Homes Z again after QGL
        G28 Z
    {% endif %}

  SMART_PARK

  # Heating nozzle to 150 degrees. This helps with getting a correct Z-home
  SET_DISPLAY_TEXT MSG="Hotend: 200C"          # Displays info
  M109 S200                                    # Heats the nozzle to 200C

 # STATUS_CLEANING

  CLEAN_NOZZLE

  ##  Uncomment for bed mesh (2 of 2)
  SET_DISPLAY_TEXT MSG="Bed mesh"    # Displays info
  
#  STATUS_MESHING                     # Sets SB-leds to bed mesh-mode

  #BED_MESH_CALIBRATE METHOD=RAPID_SCAN ADAPTIVE=1              # Starts bed mesh for eddy
  BED_MESH_CALIBRATE ADAPTIVE=1                  # Starts bed mesh

  M400

#  STATUS_READY

  SMART_PARK

  # Heats up the nozzle up to target via data from slicer
  SET_DISPLAY_TEXT MSG="Hotend: {target_extruder}C"             # Displays info
#  STATUS_HEATING                                                # Sets SB-leds to heating-mode
  M107                                                          # Turns off partcooling fan
  M109 S{target_extruder}                                       # Heats the nozzle to printing temp
  
  # Gets ready to print by doing a purge line and updating the SB-leds
  SET_DISPLAY_TEXT MSG="The purge..."          # Displays info
#  STATUS_CLEANING

  SET_DISPLAY_TEXT MSG="Printer goes brrr"          # Displays info
  
  LINE_PURGE
#  STATUS_PRINTING
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

If you have feedback please reach out to me on Voron Discord (jontek2) or open an issue on github.
