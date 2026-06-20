# Calibrations

---

## Fan Timing Calibration

**What the problem is:** The stock fan kick-start and speed-up times on the Q2 cause slow fan response. When the slicer calls for cooling, the fan takes longer than it should to reach the target speed — this hurts overhang quality because cooling arrives late.

**What the calibration does:** Tests different kick-start durations and target speeds to find the values that get your fan to speed the fastest. You then apply those values to your fan config.

### Steps

1. Download `fan_test.py` from the repo: [wiki/assets/fan_test.py](assets/fan_test.py)
2. Open the file in a text editor and replace `your.ip.adress:7125` with your printer's IP address and port (e.g. `192.168.1.42:7125`)
3. Run the script from your computer:
   - **Windows:** `py fan_test.py`
   - **Mac/Linux:** `python3 fan_test.py`
4. Let it run to completion — it will test several kick-start durations and print recommended values at the end
5. Apply the output `kick_start_time` and `kick_down_time` values to your fan section in `printer.cfg`

The script communicates with your printer over the Moonraker API. The printer must be on and Klipper must be running during the test.

*Original script by @Michael.Smichtz (Qidi Discord).*
