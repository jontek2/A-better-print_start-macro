<h1 align="center">
  <br>
  <img src="img/start.png" width="75""></a>
  <br>
    A better print_start macro
  <br>
</h1>

<h4>This print_start macro will pass data from your slicer to your printer and perform all necessary preflight commands for a successful print on your Voron printer running Klipper. This means heatsoak, QGL/Z-tilt, bed mesh and a primeline before each print.</h4>


<p>This macro requires you to have a chamber thermistor. This is necessary to achieve your set chamber temp in your slicer.</p>

## :warning: Required changes in your slicer :warning:
You need to update your "Start G-code" in your slicer to be able to send data from slicer to this macro. Click on the slicer you use below and read the instructions.

<details>
<summary>SuperSlicer</summary>
In Superslicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops SuperSlicer from sending temp waits separately
M140 S0
print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```
</details>
<details>
<summary>OrcaSlicer</summary>
In OrcaSlicer go to "Printer settings" -> "Machine start g-code" and update it to:

```
M104 S0 ; Stops OrcaSlicer from sending temp waits separately
M140 S0
print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```
</details>
<details>
<summary>PrusaSlicer</summary>

In PrusaSlicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops PrusaSlicer from sending temp waits separately
M140 S0
print_start EXTRUDER=[first_layer_temperature[initial_extruder]] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```
</details>
<details>
<summary>Cura</summary>

In Cura go to "Settings" -> "Printer" -> "Manage printers" -> "Machine settings" -> "Start G-code" and update it to:

```
print_start EXTRUDER={material_print_temperature_layer_0} BED={material_bed_temperature_layer_0} CHAMBER={build_volume_temperature}
```
</details>


## :warning: Required change in your printer.cfg :warning:

The print_start macro has predefined names for nevermore and chamber thermistor. Make sure that yours are named correctly. In your printer.cfg file verify the following:

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



# V2.4/Trident macro

> [!WARNING]  
> The macro was updated recently (2024-09-07). If you run in to any issues then please let me know by opening a issue on github.

Copy this macro and replace your old print_start macro in your printer.cfg. Then read through and uncomment parts of this macro.

```
#####################################################################
#   A better print_start macro for v2/trident
#####################################################################

## *** THINGS TO UNCOMMENT: ***
## Bed mesh (2 lines at 2 locations)
## Nevermore (if you have one)
## Z_TILT_ADJUST (For Trident only)
## QUAD_GANTRY_LEVEL (For V2.4 only)
## Beacon Contact logic (if you have one. 4 lines at 4 locations)

[gcode_macro PRINT_START]
gcode:
  # This part fetches data from your slicer. Such as bed, extruder, and chamber temps and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("45")|int %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  ##  Uncomment for Beacon Contact (1 of 4 for beacon contact)
  #SET_GCODE_OFFSET Z=0                                 # Set offset to 0

  # Home the printer, set absolute positioning and update the Stealthburner LEDs.
  STATUS_HOMING                                         # Set LEDs to homing-mode
  G28                                                   # Full home (XYZ)
  G90                                                   # Absolute position

  ##  Uncomment for bed mesh (1 of 2 for bed mesh)
  #BED_MESH_CLEAR                                       # Clear old saved bed mesh (if any)

  # Check if the bed temp is higher than 90c - if so then trigger a heatsoak.
  {% if params.BED|int > 90 %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}c"           # Display info on display
    STATUS_HEATING                                      # Set LEDs to heating-mode
    M106 S255                                           # Turn on the PT-fan

    ##  Uncomment if you have a Nevermore.
    #SET_PIN PIN=nevermore VALUE=1                      # Turn on the nevermore

    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    M190 S{target_bed}                                  # Set the target temp for the bed
    SET_DISPLAY_TEXT MSG="Heatsoak: {target_chamber}c"  # Display info on display
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for chamber temp

  # If the bed temp is not over 90c, then skip the heatsoak and just heat up to set temp with a 5 min soak
  {% else %}
    SET_DISPLAY_TEXT MSG="Bed: {target_bed}c"           # Display info on display
    STATUS_HEATING                                      # Set LEDs to heating-mode
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Go to center of the bed
    M190 S{target_bed}                                  # Set the target temp for the bed
    SET_DISPLAY_TEXT MSG="Soak for 5 min"               # Display info on display
    G4 P300000                                          # Wait 5 min for the bedtemp to stabilize
  {% endif %}

  # Heat hotend to 150c. This helps with getting a correct Z-home.
  SET_DISPLAY_TEXT MSG="Hotend: 150c"                   # Display info on display
  M109 S150                                             # Heat hotend to 150c

  ##  Uncomment for Beacon contact (2 of 4 for beacon contact)
  #G28 Z METHOD=CONTACT CALIBRATE=1                     # Calibrate z offset and beacon model

  ##  Uncomment for Trident (Z_TILT_ADJUST)
  #SET_DISPLAY_TEXT MSG="Leveling"                      # Display info on display
  #STATUS_LEVELING                                      # Set LEDs to leveling-mode
  #Z_TILT_ADJUST                                        # Level the printer via Z_TILT_ADJUST
  #G28 Z                                                # Home Z again after Z_TILT_ADJUST

  ##  Uncomment for V2.4 Faster QGL (regular QGL later)
  #SET_DISPLAY_TEXT MSG="Leveling"                      # Display info on display
  #STATUS_LEVELING                                      # Set LEDs to leveling-mode
  #QUAD_GANTRY_LEVEL horizontal_move_z=20 retries=1 retry_tolerance=1.000    #rough QGL (one run if already roughly alligned, two if gantry is heavily skewed)
  #QUAD_GANTRY_LEVEL horizontal_move_z=3                # secondary & faster QGL, default retries and tolerance.
  #G28 Z                                                # Home Z again after QGL

  ## ALTERNATIVELY add this to your macros to change QGL completely: (and use the regular setup below)
  #[gcode_macro QUAD_GANTRY_LEVEL]
  #rename_existing: _QUAD_GANTRY_LEVEL
  #gcode:
    #{% if "xyz" not in printer.toolhead.homed_axes %}
      #G28
    #{% endif %}
    #_QUAD_GANTRY_LEVEL horizontal_move_z=20 retries=1 retry_tolerance=1.000
    #_QUAD_GANTRY_LEVEL horizontal_move_z=3
    #G28 Z

  ##  Uncomment for V2.4 regular QGL (Quad gantry level AKA QGL)
  #SET_DISPLAY_TEXT MSG="Leveling"                      # Display info on display
  #STATUS_LEVELING                                      # Set LEDs to leveling-mode
  #QUAD_GANTRY_LEVEL                                    # QGL
  #G28 Z                                                # Home Z again after QGL

  ##  Uncomment for bed mesh (2 of 2 for bed mesh)
  #SET_DISPLAY_TEXT MSG="Bed mesh"                      # Display info on display
  #STATUS_MESHING                                       # Set LEDs to bed mesh-mode
  #BED_MESH_CALIBRATE                                   # Start the bed mesh (add ADAPTIVE=1) for adaptive bed mesh

  ## Uncomment for Beacon Contact (3 of 4 for beacon contact)
  #G28 Z METHOD=CONTACT CALIBRATE=0                     # Calibrate z offset only with hot nozzle

  # Heat up the hotend up to target via data from slicer
  SET_DISPLAY_TEXT MSG="Hotend: {target_extruder}c"     # Display info on display
  STATUS_HEATING                                        # Set LEDs to heating-mode
  G1 X{x_wait} Y{y_wait} Z15 F9000                      # Go to center of the bed
  M107                                                  # Turn off partcooling fan
  M109 S{target_extruder}                               # Heat the hotend to set temp

  ##   Uncomment for Beacon Contact (4 of 4 for beacon contact)
  #SET_GCODE_OFFSET Z=0.06                              # Add a little offset for hotend thermal expansion

  # Get ready to print by doing a primeline and updating the LEDs
  SET_DISPLAY_TEXT MSG="Printer goes brr"               # Display info on display
  STATUS_PRINTING                                       # Set LEDs to printing-mode
  G0 X{x_wait - 50} Y4 F10000                           # Go to starting point
  G0 Z0.4                                               # Raise Z to 0.4
  G91                                                   # Incremental positioning 
  G1 X100 E20 F1000                                     # Primeline
  G90                                                   # Absolute position
```

# v0 macro

Copy this macro and replace the old print_start macro in your printer.cfg. Then read through and uncomment parts of this macro.

```
#####################################################################
#   A better print_start macro for v0
#####################################################################

## *** THINGS TO UNCOMMENT: ***
## Nevermore (if you have one)

[gcode_macro PRINT_START]
gcode:
  # Fetches data from your slicer. Such as bed temp, extruder temp, chamber temp and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("45")|int %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer and sets absolute positioning
  G28                                                 # Full home (XYZ)
  G90                                                 # Absolute position

  # Checks if the bed temp is higher than 90c - if so then trigger a heatsoak
  {% if params.BED|int > 90 %}
    M106 S255                                         # Turn on the PT-fan

    ##  Uncomment if you have a Nevermore.
    #SET_PIN PIN=nevermore VALUE=1                    # Turn on the nevermore

    G1 X{x_wait} Y{y_wait} Z15 F9000                  # Go to center of the bed
    M190 S{target_bed}                                # Set target temp for the bed
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Wait for chamber temp

  # If the bed temp is not over 90c it skips the heatsoak and just heats up to set temp with a 1 min soak.
  {% else %}
    G1 X{x_wait} Y{y_wait} Z15 F9000                  # Go to center of the bed
    M190 S{target_bed}                                # Set target temp for the bed
    G4 P300000                                        # Wait 5 min for the bedtemp to stabilize
  {% endif %}

  # Heats up the hotend up to target via slicer
  M107                                                # Turn off partcooling fan
  M109 S{target_extruder}                             # Heat hotend to print temp

  # Create a prime line and starts the print
  G1 X5 Y4 Z0.4 F10000                                # Go to starting point
  G1 X115 E20 F1000                                   # Primeline
```

## Changelog

2024-09-07: Big update! Removed wall of text, added support for Beacon Contact, PrusaSlicer chamber temperature, fixed typos and more!<br>
2024-05-30: Added support for Orcaslicer.<br>
2022-09-??: Release!


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
