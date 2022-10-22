# A better print_start macro

**:warning: This is still in BETA :warning:**

This documents aims to help you get a better, simple and powerful print_start macro for your Voron printer. With this macro you will be able to pass variables such as print temps and chamber temps to your print_start macro. By doing so you will be able to automatically start a heatsoak and customize your printers behaviour. The heatsoak will start when you've sliced a print with a bed temp higher than 90c. It will then heatsoak to your set chamber temp. If no chamber temp is set it will fallback to the macros standard chambertemp of 40c. 

Each command has a comment next to it explaining what it does. Make sure to read through the macro and get an understanding of what it.

In short this macro will perform:

1) Home the printer
2) Heatsoak if neccesary
3) QGL/Z-tilt adjust
4) Bed mesh (if activated)
5) Make a short purge/prime line

## Requirements

### For V2/Trident

 Just like you did in printer.cfg you will need to go through and uncomment parts of the macro in order to make it work with your printer:

 - Bed mesh (2 lines at 2 locations)
 - Screw_tilt_adjust if your printer is a Trident
 - Quad gantry level if your printer is a V2
 - [Nevermore](https://github.com/nevermore3d/Nevermore_Micro) - if you have one

 Other requirements:

  - [Stealthburner](https://vorondesign.com/voron_stealthburner)
  - Chamber thermistor

### For v0

 Just like you did in printer.cfg you will need to go through and uncomment parts of the macro in order to make it work with your printer:

 - [Nevermore](https://github.com/nevermore3d/Nevermore_Micro) - if you have one

Other requirements:
  - Chamber thermistor

## :warning: Required change in your slicer :warning:
You need to update your "Start g-code" in your slicer by adding a few lines of code. This will send data about your print temps and chamber temp to klipper for each print.

### SuperSlicer
In Superslicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops SuperSlicer from sending temp waits separately
M140 S0
print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] CHAMBER=[chamber_temperature]
```

### PrusaSlicer

:warning: PrusaSlicer doesn't give you the option to set a specific chambertemp. Therefor you it will fallback to the standard chambertemp of 40c. 

In PrusaSlicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops PrusaSlicer from sending temp waits separately
M140 S0
print_start EXTRUDER=[first_layer_temperature[initial_extruder]] BED=[first_layer_bed_temperature]
```

### Cura

In Cura go to "Settings" -> "Printer" -> "Manage printers" -> "Machine settings" -> "Start G-code" and update it to:

```
print_start EXTRUDER={material_print_temperature_layer_0} BED={material_bed_temperature_layer_0} CHAMBER={build_volume_temperature}
```

## :warning: Required verification/changes in your printer.cfg :warning:

The print_start macro has predefined names for nevermore and chamber thermistor. Therefor you need to make sure that your's are named correctly.

In your printer.cfg file verify the following:

**Chamber thermistor**:
Make sure that chamber thermistor is named "chamber".

```
[temperature_sensor chamber]
sensor_type:  XXX
sensor_pin:   XXX
```

**Nevermore**:
Make sure that nevermore is named "nevermore".

```
[output_pin nevermore]
pin: XXX
value: 0
shutdown_value: 0
```

# The print_start macro for V2/Trident

As mentioned above you will need to uncomment parts of this macro for it to work on your V2 or Trident. Replace this macro with your current print_start macro in your printer.cfg

```
#####################################################################
#   print_start macro
#####################################################################

## *** THINGS TO UNCOMMENT: ***
## Bed mesh (2 lines at 2 locations)
## Screw_tilt_adjust if your printer is a Trident
## Quad gantry level if your printer is a V2
## Nevermore - if you have one

[gcode_macro PRINT_START]
gcode:
  # This part fetches data from your slicer. Such as bed temp, extruder temp, chamber temp and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("40")|int %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer, sets absolute positioning and updates the Stealthburner leds.
  STATUS_HOMING         # Sets SB-leds to homing-mode
  G28                   # Full home (XYZ)
  G90                   # Absolut position

  ##  Uncomment for bed mesh (1 of 2)
  #BED_MESH_CLEAR       # Clears old saved bed mesh (if any)

  # Checks if the bed temp is higher than 90c - if so then trigger a heatsoak.
  {% if params.BED|int > 90 %}
    SET_DISPLAY_TEXT MSG="Heating bed: {target_bed}"    # Displays info
    STATUS_HEATING                                      # Sets SB-leds to heating-mode
    M106 S255                                           # Turns on the PT-fan

    ##  Uncomment if you have a Nevermore.
    #SET_PIN PIN=nevermore VALUE=1                      # Turns on the nevermore

    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Goes to center of the bed
    M190 S{target_bed}                                  # Sets the target temp for the bed
    SET_DISPLAY_TEXT MSG="Heatsoaking to: {target_chamber}c"                        # Displays info
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for chamber to reach desired temp

  # If the bed temp is not over 90c, then it skips the heatsoak and just heats up to set temp with a 5min soak
  {% else %}
    SET_DISPLAY_TEXT MSG="Heating bed: {target_bed}c"   # Displays info
    STATUS_HEATING                                      # Sets SB-leds to heating-mode
    G1 X{x_wait} Y{y_wait} Z15 F9000                    # Goes to center of the bed
    M190 S{target_bed}                                  # Sets the target temp for the bed
    SET_DISPLAY_TEXT MSG="Soak for 5min"                # Displays info
    G4 P300000                                          # Waits 5 min for the bedtemp to stabilize
  {% endif %}

  # Heating nozzle to 150 degrees. This helps with getting a correct Z-home
  SET_DISPLAY_TEXT MSG="Heating hotend: 150c"          # Displays info
  M109 S150                                            # Heats the nozzle to 150c

  ##  Uncomment for Trident (screw_tilt_adjust)
  #SET_DISPLAY_TEXT MSG="Z-tilt adjust"     # Displays info
  #STATUS_LEVELING                          # Sets SB-leds to leveling-mode
  #Z_TILT_ADJUST                            # Levels the buildplate via z_tilt_adjust
  #G28 Z                                    # Homes Z again after z_tilt_adjust

  ##  Uncomment for V2 (Quad gantry level AKA QGL)
  #SET_DISPLAY_TEXT MSG="QGL"      # Displays info
  #STATUS_LEVELING                 # Sets SB-leds to leveling-mode
  #quad_gantry_level               # Levels the buildplate via QGL
  #G28 Z                           # Homes Z again after QGL

  ##  Uncomment for Klicky auto-z
  #CALIBRATE_Z                                 # Calibrates Z-offset with klicky
  #SET_DISPLAY_TEXT MSG="Calibrate Z-offset"   # Displays info

  ##  Uncomment for bed mesh (2 of 2)
  #SET_DISPLAY_TEXT MSG="Bed mesh"    # Displays info
  #STATUS_MESHING                     # Sets SB-leds to bed mesh-mode
  #bed_mesh_calibrate                 # Starts bed mesh

  # Heats up the nozzle up to target via data from slicer
  SET_DISPLAY_TEXT MSG="Heating hotend: {target_extruder}c"     # Displays info
  STATUS_HEATING                                                # Sets SB-leds to heating-mode
  G1 X{x_wait} Y{y_wait} Z15 F9000                              # Goes to center of the bed
  M107                                                          # Turns off partcooling fan
  M109 S{target_extruder}                                       # Heats the nozzle to printing temp

  # Gets ready to print by doing a purge line and updating the SB-leds
  SET_DISPLAY_TEXT MSG="Printer goes brr"          # Displays info
  STATUS_PRINTING                                  # Sets SB-leds to printing-mode
  G0 X{x_wait - 50} Y4 F10000                      # Moves to starting point
  G0 Z0.4                                          # Raises Z to 0.4
  G91                                              # Incremental positioning 
  G1 X100 E20 F1000                                # Purge line
  G90                                              # Absolut position
```

# The print_start macro for v0

As mentioned above you will need to uncomment parts of this macro for it to work on your v0. Replace this macro with your current print_start macro in your printer.cfg

```
#####################################################################
#   print_start macro
#####################################################################

## *** THINGS TO UNCOMMENT: ***
## Nevermore - if you have one

[gcode_macro PRINT_START]
gcode:
  # This part fetches data from your slicer. Such as bed temp, extruder temp, chamber temp and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("40")|int %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Homes the printer and sets absolute positioning
  G28                   # Full home (XYZ)
  G90                   # Absolut position

  # Checks if the bed temp is higher than 90c - if so then trigger a heatsoak
  {% if params.BED|int > 90 %}
    M106 S255                                         # Turns on the PT-fan

    ##  Uncomment if you have a Nevermore.
    #SET_PIN PIN=nevermore VALUE=1                    # Turns on the nevermore

    G1 X{x_wait} Y{y_wait} Z15 F9000                  # Goes to center of the bed
    M190 S{target_bed}                                # Sets target temp for the bed
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   # Waits for chamber to reach desired temp

  # If the bed temp is not over 90c then it skips the heatsoak and just heats up to set temp with a 5min soak.
  {% else %}
    G1 X{x_wait} Y{y_wait} Z15 F9000                # Goes to center of the bed
    M190 S{target_bed}                              # Sets target temp for the bed
    G4 P300000                                      # Waits 5 min for the bedtemp to stabilize
  {% endif %}

  # Heats up the nozzle up to target via slicer
  M107                                              # Turns off the PT-fan
  M109 S{target_extruder}                           # Heats the nozzle to your print temp

  # Create a purge line and starts the print
  G1 X5 Y4 Z0.4 F10000                             # Moves to starting point
  G1 X115 E20 F1000                                # Purge line
```
### Interested in more macros?

Interested in learning more about macros?

- [Ellis Useful Macros](https://github.com/AndrewEllis93/Print-Tuning-Guide/blob/main/articles/useful_macros.md)
- [Voron Klipper Macros](https://github.com/The-Conglomerate/Voron-Klipper-Common/)
- [Samwiseg0 config](https://github.com/samwiseg0/V2.2265_klipper_config)

### Credits

Credits to the Voron supportteam for making this


### Feedback

If you have feedback feel free to hit me up on discord at jontek2#2992