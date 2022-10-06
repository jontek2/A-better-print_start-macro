# A better print_start macro

**:warning: = THIS IS VERY MUCH A BETA AND IT HAS NOT BEEN TESTED.**

This macro and document aims to help you get a simple but yet powerful start_macro for your voron printer! With this macro you will be able to pass variables, such as print temps, chamber temps, filament type, to your print start macro. By doing so you will be able to automatically heatsoak and customize your printers behaviour. 


## Requirements

**For V2/Trident:**

- [SuperSlicer](https://github.com/supermerill/SuperSlicer)
- [Stealthburner](https://vorondesign.com/voron_stealthburner)
- Chamber thermistor
- [Nevermore](https://github.com/nevermore3d/Nevermore_Micro)
- Exhaust fan

**For v0:**

- [SuperSlicer](https://github.com/supermerill/SuperSlicer)
- Chamber thermistor
- [Nevermore](https://github.com/nevermore3d/Nevermore_Micro)


## :warning: Required change in SuperSlicer :warning:
You will need to make an update in your SuperSlicer to be able to send the data to this macro. In Superslicer go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] FILAMENT={filament_type[0]} CHAMBER=[chamber_temperature]
```

![](/images/image1.png) 

This will send data about your print temp, bed temp, filament and chamber temp to klipper for each print.

## :warning: Required change in the macro :warning:

The macro below needs to know the the name of your fans and thermistor. I've made it easy for you so you only need to update it in one place.

Look for the following in the macro below:

```
#  This part you will need to update according to what you've defined your printers fans and thermistor as
{% set target_chamberthermistor = temperature_sensor NAME_OF_THERMISTOR_FAN %}
{% set exhaustfan = NAME_OF_EXHAUST_FAN %}
{% set nevermore = NAME_OF_NEVERMORE_FAN %}
```

For me this would be changed to:

```
#  UPDATE THIS: Update this according to what you've defined your printers fans and thermistor as!
{% set target_chamberthermistor = temperature_sensor chamber %}
{% set exhaustfan = exhaust_fan %}
{% set nevermore = nevermore %}
```

# The print_start macro for V2/Trident

Replace this macro with your current print_start macro in your printer.cfg. Don't forget to updated the chamber thermistor, exhaust fan and the nevermore, as mentioned above.

```
#####################################################################
# 	print_start macro
# To be used with "print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] FILAMENT={filament_type[0]} CHAMBER=[chamber_temperature]" in SuperSlicer
#####################################################################

[gcode_macro PRINT_START]
gcode:
  # This part fetches data from SuperSlicer. Such as what bed temp, extruder temp, chamber temp and filament.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|int %}
  {% set filament_type = params.FILAMENT|upper %}
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
  M117 Heating: ~bed~{target_bed}~degrees~           ; Display info on the display
  STATUS_HEATING                                    ; Set SB-leds to heating-mode
  M106 S255                                         ; Turn on the PT-fan
  SET_FAN_SPEED FAN=exhaust SPEED=0.25         ; Turn on the exhaust fan
  SET_PIN PIN=nevermore VALUE=1                   ; Turn on the nevermore
  G1 X{x_wait} Y{y_wait} Z15 F9000                  ; Go to the center of the bed
  M190 S{target_bed}                                ; Set the target temp for the bed
  M117 Soaking ~chamber~: {target_chamber}~degrees~  ; Display info on the display
  TEMPERATURE_WAIT SENSOR="temperature_sensor chamber" MINIMUM={target_chamber}   ; Wait for chamber to reach desired temp

# If it's not ABS or ASA it skips the heatsoak and just heat the bed to the target.
{% else %}
  M117 Heating: ~bed~{target_bed}~degrees~         ; Display info on the display
  STATUS_HEATING                                  ; Set SB-leds to heating-mode
  G1 X{x_wait} Y{y_wait} Z15 F9000                ; Go to the center of the bed
  SET_FAN_SPEED FAN=exhaust SPEED=0.25       ; Turn on the exhaust fan
  M190 S{target_bed}                              ; Set the target temp for the bed
{% endif %}

# Heating nozzle to 150 degrees
M117 Heating: ~extruder~ 150~degrees~   ; Display info on the display
M109 S150                               ; Heat the nozzle to 150c

# Quad gantry leveling and home Z again after.
M117 QGL                        ; Display info on the display
STATUS_LEVELING                 ; Set SB-leds to leveling-mode
G32                             ; Quad gantry level aka QGL
G28 Z                           ; Home Z again after QGL

# Uncomment this line below if you're using klicky with the auto z-function
#CALIBRATE_Z                    ; Calibrate Z-offset with klicky

# Checks if you have a bed mesh possibilty, if so generate a new mesh.
{% if "bed_mesh" in printer.configfile.settings %}
M117 Bed mesh                   ; Display info on the display
STATUS_MESHING                  ; Set SB-leds to bed mesh-mode
bed_mesh_calibrate              ; Start bed mesh
{% endif %}

# Heat the nozzle up to target set in SuperSlicer
M117 Heating: ~extruder~ {target_extruder}~degrees~   ; Display info on the display
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

Replace this macro with your current print_start macro in your printer.cfg. Don't forget to updated the chamber thermistor, exhaust fan and the nevermore, as mentioned above.

```
#####################################################################
#   print_start macro
# To be used with "print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] FILAMENT={filament_type[0]} CHAMBER=[chamber_temperature]" in SuperSlicer
#####################################################################

[gcode_macro PRINT_START]
gcode:
  # This part fetches data from SuperSlicer. Such as what bed temp, extruder temp, chamber temp and filament.
  {% set target_bed = params.BED|int %}
  {% set target_extruder = params.EXTRUDER|int %}
  {% set target_chamber = params.CHAMBER|int %}
  {% set filament_type = params.FILAMENT|upper %}
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

  # Heat the nozzle up to target set in SuperSlicer
  M106 S0                                               ; Turn off the PT-fan
  M109 S{target_extruder}                               ; Heat the nozzle to your print temp

  # Get ready to print
  G1 X25 Y5 Z10 F15000          ; Go to X25 and Y5
  G92 E0.0                      ; Set position 
```

### Feedback

If you have feedback feel free to hit me up on discord jontek2#2992


