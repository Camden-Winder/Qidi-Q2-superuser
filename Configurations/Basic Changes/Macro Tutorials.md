# Startup Macros
### For each of these changes the easiest way to do it is
1. Control + F to the correct macro
2. Copy all text from gcode (so including that line) to where the macro ends (right before the "view `'' documentation of the next)
3. Replace that text with the correct text you copied from the given .txt file

## Macros
1. Go to gcode_macro.cfg
2. Go to the `CLEAR_NOZZLE` macro
3.Replace the old macro with [this new one](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Basic%20Changes/CLEAR_NOZZLE.txt)
EDIT: PRINT_START macro is currently broken! You will run into erros on large prints! Do not use it yet, I am working on fixing it
4.Go to the `PRINT_START` macro
5. If you have the Qidi box use [this text](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Basic%20Changes/PRINT_START%20(box).txt)

If you do not have the Qidi box, copy and paste [this text](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Basic%20Changes/PRINT-START%20(No%20Box).txt)
6.Replace the old macro with the text you coppied from the correct.txt file

7. Go to the `PRINT_END` macro
8. Replace old text with [this text](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Basic%20Changes/PRINT_END.txt)

9. Go to the VERY BOTTOM of the gcode_macro.cfg (you are already in gcode_macro.cfg by the way, just go to the bottom)
10. Copy the [BRUSH macro](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Basic%20Changes/New%20Macros/BRUSH.txt) to the very bottom
11. Copy the [WIPE macro](https://github.com/Camden-Winder/Qidi-Q2-superuser/tree/main/Configurations/Basic%20Changes/New%20Macros) to the very bottom

## For box users only
1. You will also need to edit the `EXTRUSION_AND_FLUSH` macro
2. Replace the old macro with [this one](https://github.com/Camden-Winder/Qidi-Q2-superuser/tree/main/Configurations/Basic%20Changes)

# Macros in Orca (all users)
It is important to change all the macros in the orca as I have built all the macros into the gcode_macro.cfg

Copy and paste both of these into the machine gcode of printer settings

1. Click the edit button on the printer
2. Go to machine gcode
3. [This text](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Basic%20Changes/Machine%20Start.txt) goes in machine start
4. Delete everything in machine end, we don't need it anymore

