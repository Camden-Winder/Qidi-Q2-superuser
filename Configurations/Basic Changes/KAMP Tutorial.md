This will make it so it still levels the bed, but only in the part you will be printing. This is especially helpful when doing small prints. I recomend follwing along with [Heiko910 Integrating KAMP](https://github.com/Heiko910/Qidi-Q2-with-KAMP-fully-integrated/tree/main) because he has pictures. I will go into detail to help explain it some more though as well.
Access the printer interface from your web browser. Just type your IP address into the search bar.
1. Click on configurations in the left tab bar
2. Make a folder called `store for delete` to store config files you don't need anymore
3. Store `KAMP_settings.cfg` and `Adpative_meshing.cfg` in this folder
4. Enter the `KAMP` folder and open `KAMP_settings.cfg`
5. Delete all text and replace with [this text](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Basic%20Changes/KAMP_settings.txt)
6. Press save in the top right corner
## Now we change more settings to make sure our changes do stuff
7. Go to printer.cfg file
8. Remove whatever is in the 3rd line and replace it with this `[include ./KAMP/KAMP_Settings.cfg]`
9. Save again
