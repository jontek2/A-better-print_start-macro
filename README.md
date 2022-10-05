# A better print_start macro

**:warning: = THIS IS VERY MUCH A BETA AND IT HAS NOT BEEN TESTED. YET.**

This document aims to help you get a simple but powerful start_macro for your voron printer! With this macro you will be able to pass variables, such as print temps, chamber temps, filamenttype, to your print start. 

By doing so you will be able to automatically heatsoak and customize your printers behaviour. 

## Requirements

This macro expect you to have the following:

- [Superslicer](https://github.com/supermerill/SuperSlicer)
- [Stealthburner](https://vorondesign.com/voron_stealthburner)
- An exhaust fan
- An chamber thermistor


## Required change in SuperSlicer
You will need to make an update in SuperSlicer. Go to "Printer settings" -> "Custom g-code" -> "Start G-code" and update it to:

```
print_start EXTRUDER=[first_layer_temperature] BED=[first_layer_bed_temperature] FILAMENT={filament_type[0]} CHAMBER=[chamber_temperature]
```

![](/images/image1.png) 

This will send info about your print temp, bed temp, filament and chamber temp to klipper for each print.

## Required change in the macro

The macro below needs to know the the name of your nevermore, exhaust fan and chamber thermistor. I've made it easy for you so you only need to update it in one place.

Look for the following in the print_start macro below:

```
#  This part you will need to update according to what you've defined your printers fans and thermistor as
{% set target_chamberthermistor = temperature_sensor NAME_OF_THERMISTOR_FAN %}
{% set exhaustfan = NAME_OF_EXHAUST_FAN %}
{% set nevermore = NAME_OF_NEVERMORE_FAN %}
```

For me this would be changed to:

```
#  This part you will need to update according to what you've defined your printers fans and thermistor as
{% set target_chamberthermistor = temperature_sensor chamber %}
{% set exhaustfan = exhaust_fan %}
{% set nevermore = nevermore %}
```

# The print_start macro

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
{% set filament_type = params.FILAMENT|int %}
{% set x_wait = printer.toolhead.axis_maximum.x|float / 2 %}
{% set y_wait = printer.toolhead.axis_maximum.y|float / 2 %}

#  This part you will need to update according to what you've defined your printers fans and thermistor as
{% set target_chamberthermistor = temperature_sensor NAME_OF_THERMISTOR_FAN %}
{% set exhaustfan = NAME_OF_EXHAUST_FAN %}
{% set nevermore = NAME_OF_NEVERMORE_FAN %}


# Make the printer home, set absolut positioning and change the Stealthburner LED's to homing
STATUS_HOMING         ; Set SB-led's to colors for homing
G28                   ; Full home (XYZ)
G90                   ; Absolut position

# Check what material we're printing. If it's either ABS or ASA we're printing, and if so do a heatsoak.
{% if filament_type == "ABS" or filament_type == "ASA" %}
  STATUS_HEATING                              ; Set SB-led's to colors for heating
  M106 S255                                   ; Turn on the PT-fan
  SET_FAN_SPEED FAN={exhaustfan} SPEED=0.25   ; Turn on the exhaust fan
  SET_PIN PIN={nevermore} VALUE=1             ; Turn on the nevermore
  G1 X{x_wait} Y{y_wait} Z15 F9000            ; Go to the center of the bed
  M190 S{target_bed}                          ; Set the target temp for the bed
  TEMPERATURE_WAIT SENSOR="{target_chamberthermistor}" MINIMUM={target_chamber}   ; Wait for chamber to reach desired temp

# If it's not ABS or ASA we skip the heatsoak and just heat the bed to the target.
{% else %}
  STATUS_HEATING                                  ; Set SB-led's to colors for heating
  G1 X{x_wait} Y{y_wait} Z15 F9000                ; Go to the center of the bed
  SET_FAN_SPEED FAN={exhaustfan} SPEED=0.25       ; Turn on the exhaust fan
  M190 S{target_bed}                              ; Set the target temp for the bed
{% endif %}

# Heating nozzle to 150 degrees
M109 S150                       ; Heat the nozzle to 150c

# Quad gantry leveling and home Z again after.
STATUS_LEVELING                 ; Set SB-led's to colors for leveling
G32                             ; QGL
G28 Z                           ; Home Z again after QGL

# Takes a fresh bed mesh.
BED_MESH_CLEAR                  ; Removes old bed mesh
STATUS_MESHING                  ; Set SB-led's to colors for bed mesh
bed_mesh_calibrate              ; Bed mesh

# Heat the nozzle up to target set in superslicer
STATUS_HEATING                          ; Set SB-led's to colors for heating
G1 X{x_wait} Y{y_wait} Z15 F9000        ; Go to the center of the bed
M106 S10                                ; Turn off the PT-fan
M109 S{target_extruder}                 ; Heat the nozzle to your print temp

# Get ready to print
STATUS_READY                  ; Set SB-led's to colors for ready
G1 X25 Y5 Z10 F15000          ; Go to X25 and Y5
STATUS_PRINTING               ; Set SB-led's to colors for printing
G92 E0.0                      ; Set position 
```