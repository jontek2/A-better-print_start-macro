# A better print_start macro

**:warning: This is still in BETA :warning:**

This macro and document aims to help you get a simple but powerful start_macro for your voron printer! With this macro you will be able to pass variables (print temps, chamber temps, filament type) to your print start macro. By doing so you will be able to automatically heatsoak and customize your printers behaviour based upon what material you're printing, 

Each command has a comment next to it explaining what it does. Make sure to read thru the macro and get an understanding of what it does.

If you have a klicky with the auto-z function then uncomment the line for #CALIBRATE_Z.

## Requirements

**For V2/Trident:**

- [Stealthburner](https://vorondesign.com/voron_stealthburner)
- Chamber thermistor
- [Nevermore](https://github.com/nevermore3d/Nevermore_Micro)
- Exhaust fan

**For v0:**

- Chamber thermistor
- [Nevermore](https://github.com/nevermore3d/Nevermore_Micro)


## :warning: Required change in your slicer :warning:
You will need to make an update in your slicer where you add a line of code in your start-gocde. This will send data about your print temp, bed temp, filament and chamber temp to klipper for each print.

### SuperSlicer
In Superslicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops SuperSlicer from sending temp waits separately
M140 S0
print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] FILAMENT={filament_type[0]} CHAMBER=[chamber_temperature]
```

### PrusaSlicer

:warning: PrusaSlicer doesn't give you the option to set a specific chambertemp. Therefor you it will fallback to the standard chambertemp of 40c.

In PrusaSlicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
M104 S0 ; Stops PrusaSlicer from sending temp waits separately
M140 S0
print_start EXTRUDER=[first_layer_temperature[initial_extruder]] BED=[first_layer_bed_temperature] FILAMENT={filament_type[0]}
```

### Cura

In Cura go to "Settings" -> "Printer" -> "Manage printers" -> "Machine settings" -> "Start G-code" and update it to:

```
print_start EXTRUDER={material_print_temperature_layer_0} BED={material_bed_temperature_layer_0} FILAMENT={material_type} CHAMBER={build_volume_temperature}
```

## :warning: Required verification/changes in your printer.cfg :warning:

The print_start macro has predefined names for your exhaust, nevermore and chamber thermistor. Therefor you need to make sure that your's are named correctly.

In your printer.cfg file verify the following:

**Chamber thermistor**:
Make sure that chamber thermistor is named "chamber".

```
[temperature_sensor chamber]
```

**Nevermore**:
Make sure that nevermore is named "nevermore".

```
[output_pin nevermore]
```

**Exhaust**:
Make sure that exhaust fan is named "exhaust_fan".

```
[output_pin exhaust_fan]
```

# The print_start macro for V2/Trident

Replace this macro with your current print_start macro in your printer.cfg

```
#####################################################################
#   print_start macro
#####################################################################

[gcode_macro PRINT_START]
gcode:
  # This part fetches data from your slicer. Such as what bed temp, extruder temp, chamber temp, filament and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("40")|int %}
  {% set filament_type = params.FILAMENT|string %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Make the printer home, set absolut positioning and update the Stealthburner leds
  STATUS_HOMING         ; Set SB-leds to homing-mode
  G28                   ; Full home (XYZ)
  G90                   ; Absolut position

  # Remove any old bed_mesh that may be active
  {% if "bed_mesh" in printer.configfile.settings %}
  BED_MESH_CLEAR                  ; Clear any old saved bed mesh
  {% endif %}

  # Check what filament we're printing. If it's ABS or ASA we're printing then start a heatsoak.
  {% if filament_type == "ABS" or filament_type == "ASA" %}
    M117 Heating ~bed~{target_bed}~degrees~             ; Display info on the display
    STATUS_HEATING                                      ; Set SB-leds to heating-mode
    M106 S255                                           ; Turn on the PT-fan
    SET_FAN_SPEED FAN=exhaust_fan SPEED=0.25            ; Turn on the exhaust fan
    SET_PIN PIN=nevermore VALUE=1                       ; Turn on the nevermore
    G1 X{x_wait} Y{y_wait} Z15 F9000                    ; Go to the center of the bed
    M190 S{target_bed}                                  ; Set the target temp for the bed
    M117 Soaking ~chamber~ {target_chamber}~degrees~    ; Display info on the display
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   ; Wait for chamber to reach desired temp.

  # If it's not ABS or ASA it skips the heatsoak and just heat the bed to the target.
  {% else %}
    M117 Heating ~bed~{target_bed}~degrees~         ; Display info on the display
    STATUS_HEATING                                  ; Set SB-leds to heating-mode
    G1 X{x_wait} Y{y_wait} Z15 F9000                ; Go to the center of the bed
    SET_FAN_SPEED FAN=exhaust_fan SPEED=0.25        ; Turn on the exhaust fan
    M190 S{target_bed}                              ; Set the target temp for the bed
  {% endif %}

  # Heating nozzle to 150 degrees
  M117 Heating ~extruder~ 150~degrees~    ; Display info on the display
  M109 S150                               ; Heat the nozzle to 150c


  # If the script recognizes that you have a z_tilt_adjust script (trident) then use that to level the buildplate.
  {% if printer.z_tilt_adjust is defined and not printer.z_tilt_adjust.applied %}
    M117 Z-tilt adjust              ; Display info on the display
    STATUS_LEVELING                 ; Set SB-leds to leveling-mode
    Z_TILT_ADJUST                   ; Level the buildplate via z_tilt_adjust
    G28 Z                           ; Home Z again after z_tilt_adjust
    {% endif %}

  # If the script recognizes that you have a QGL script (v2) then use that to level the buildplate.
  {% if printer.quad_gantry_level is defined and not printer.quad_gantry_level.applied %}
    M117 QGL                        ; Display info on the display
    STATUS_LEVELING                 ; Set SB-leds to leveling-mode
    quad_gantry_level               ; Quad gantry level aka QGL
    G28 Z                           ; Home Z again after QGL
    {% endif %}

  # Uncomment this line below if you're using klicky with the auto z-function
  #CALIBRATE_Z                    ; Calibrate Z-offset with klicky

  # Checks if you have a bed mesh possibilty, if so generate a new mesh.
  {% if "bed_mesh" in printer.configfile.settings %}
  M117 Bed mesh                   ; Display info on the display
  STATUS_MESHING                  ; Set SB-leds to bed mesh-mode
  bed_mesh_calibrate              ; Start bed mesh
  {% endif %}

  # Heat the nozzle up to target via slicer
  M117 Heating ~extruder~ {target_extruder}~degrees~    ; Display info on the display
  STATUS_HEATING                                        ; Set SB-leds to heating-mode
  G1 X{x_wait} Y{y_wait} Z15 F9000                      ; Go to the center of the bed
  M106 S0                                               ; Turn off the PT-fan
  M109 S{target_extruder}                               ; Heat the nozzle to your print temp

  # Get ready to print
  M117 Print started!           ; Display info on the display
  STATUS_READY                  ; Set SB-leds to ready-mode
  G1 X25 Y5 Z10 F15000          ; Go to X25 and Y5
  STATUS_PRINTING               ; Set SB-leds to printing-mode
  G92 E0.0                      ; Set position 
```

# The print_start macro for v0

Replace this macro with your current print_start macro in your printer.cfg
```
#####################################################################
#   print_start macro
#####################################################################

[gcode_macro PRINT_START]
gcode:
  # This part fetches data from your slicer. Such as what bed temp, extruder temp, chamber temp, filament and size of your printer.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|default("40")|int %}
  {% set filament_type = params.FILAMENT|string %}
  {% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
  {% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

  # Make the printer home and set absolut positioning
  G28                   ; Full home (XYZ)
  G90                   ; Absolut position

  # Check what filament we're printing. If it's ABS or ASA we're printing then start a heatsoak.
  {% if filament_type == "ABS" or filament_type == "ASA" %}
    M106 S255                                         ; Turn on the PT-fan
    SET_PIN PIN=nevermore VALUE=1                     ; Turn on the nevermore
    G1 X{x_wait} Y{y_wait} Z15 F9000                  ; Go to the center of the bed
    M190 S{target_bed}                                ; Set the target temp for the bed
    TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   ; Wait for chamber to reach desired temp

# If it's not ABS or ASA it skips the heatsoak and just heat the bed to the target.
  {% else %}
    G1 X{x_wait} Y{y_wait} Z15 F9000                ; Go to the center of the bed
    M190 S{target_bed}                              ; Set the target temp for the bed
  {% endif %}

  # Heat the nozzle up to target via slicer
  M106 S0                                           ; Turn off the PT-fan
  M109 S{target_extruder}                           ; Heat the nozzle to your print temp

  # Get ready to print
  G1 X25 Y5 Z10 F15000          ; Go to X25 and Y5
  G92 E0.0                      ; Set position 
```

### Feedback

If you have feedback feel free to hit me up on discord at jontek2#2992