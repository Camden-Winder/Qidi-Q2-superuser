This will make it so it still levels the bed, but only in the part you will be printing. This is especially helpful when doing small prints. I recomend follwing along with [Heiko910 Integrating KAMP](https://github.com/Heiko910/Qidi-Q2-with-KAMP-fully-integrated/tree/main) because he has pictures. I will go into detail to help explain it some more though as well.
Access the printer interface from your web browser. Just type your IP address into the search bar.
1. Click on configurations in the left tab bar
2. Make a folder called `store for delete` to store config files you don't need anymore
3. Store `KAMP_settings.cfg` and `Adpative_meshing.cfg` in this folder
4. Enter the `KAMP` folder and open `KAMP_settings.cfg`
5. Delete all text and replace with this (lots of the comments are removed because I don't know how to do this another way)
```  [include ./Adaptive_Meshing.cfg]
  [include ./Line_Purge.cfg]      
  [include ./Voron_Purge.cfg]    
  [include ./Smart_Park.cfg]   
  [gcode_macro _KAMP_Settings]
  description: This macro contains all adjustable settings for KAMP 
  variable_verbose_enable: True       
  variable_mesh_margin: 0    
  variable_fuzz_amount: 0    
  variable_purge_height: 0.8 
  variable_tip_distance: 0   
  variable_purge_margin: 10   
  variable_purge_amount: 30   
  variable_flow_rate: 12   
  variable_smart_park_height: 10  
  gcode:

    {action_respond_info(" Running the KAMP_Settings macro does nothing, it is only used for storing KAMP settings. ")}
```
6. Press save in the top right corner
## Now we change more settings to make sure our changes do stuff
7. Go to printer.cfg file
8. Remove whatever is in the 3rd line and replace it with this `[include ./KAMP/KAMP_Settings.cfg]`
9. Save again
