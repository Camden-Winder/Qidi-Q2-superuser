# How to SSH into Your Qidi Q2

SSH lets you run commands on the printer from your computer. You'll need it to run the install scripts.

---

## Find your printer's IP address

On the printer touchscreen, go to **System Settings** → **Network**. The IP address will be listed there (e.g. `192.168.1.42`).

---

## Windows

Windows 10 and 11 include SSH built into the terminal. No extra software needed.

1. Open **Command Prompt** or **PowerShell** (search for either in the Start menu)
2. Run:
   ```sh
   ssh mks@YOUR_PRINTER_IP
   ```
   Replace `YOUR_PRINTER_IP` with the IP you found above.
3. The first time you connect, you'll see a fingerprint warning — type `yes` and press Enter.
4. When prompted for a password, type:
   ```
   makerbase
   ```
   (You won't see any characters while typing — that's normal.)

You're in when you see a prompt like `mks@mkspi:~$`.

---

## Mac

Mac has SSH built into Terminal.

1. Open **Terminal** (search with Spotlight: `Cmd + Space`, type `Terminal`)
2. Run:
   ```sh
   ssh mks@YOUR_PRINTER_IP
   ```
3. Type `yes` if asked about the fingerprint.
4. Password: `makerbase`

---

## Troubleshooting

**"Connection refused" or "No route to host"**
- Make sure the printer is powered on and connected to your network.
- Double-check the IP address — it can change if your router assigns a new one. Set a static IP in your router's DHCP settings to avoid this.
- Try pinging the printer first: `ping YOUR_PRINTER_IP`

**"Host key verification failed"**
- This happens if you've connected before and the printer was reflashed. Run:
  ```sh
  ssh-keygen -R YOUR_PRINTER_IP
  ```
  Then try connecting again.

**Wrong password**
- The default password is `makerbase` (all lowercase). If you've changed it and forgotten it, a factory reset will restore it.

**On Windows, `ssh` command not found**
- You may be on an older version of Windows. Install [PuTTY](https://www.putty.org/) as an alternative SSH client.
