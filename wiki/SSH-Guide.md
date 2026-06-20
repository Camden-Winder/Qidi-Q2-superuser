# SSH Guide

SSH lets you run commands on your printer from your computer, over your local network. You'll need it to run the AIO installer.

---

## Credentials

| Printer | User | Default password |
|---|---|---|
| Qidi Q2 | `mks` | `makerbase` |
| Qidi Max 4 | `qidi` | `qiditech` |

---

## Find your printer's IP address

On the printer touchscreen, go to **Settings → Network**. The IP address is listed there (e.g. `192.168.1.42`).

**Tip:** Set a DHCP reservation in your router so the printer always gets the same IP. Without it, the IP can change between sessions and you'll need to look it up again each time.

---

## Windows

Windows 10 and 11 include SSH in the terminal. No extra software needed.

1. Open **Command Prompt** or **PowerShell** (search for either in the Start menu)
2. Run:
   ```sh
   ssh mks@YOUR_PRINTER_IP
   ```
   Replace `YOUR_PRINTER_IP` with the IP you found above. Use `qidi` instead of `mks` if you're on a Max 4.
3. The first time you connect, you'll see a fingerprint warning — type `yes` and press Enter
4. When prompted for a password, type the password from the table above
   (You won't see any characters while typing — that's normal)

You're in when you see a prompt like `mks@mkspi:~$` (Q2) or `qidi@qidi:~$` (Max 4).

---

## Mac and Linux

Mac and Linux both have SSH built in.

1. Open **Terminal**
   - Mac: search with Spotlight (`Cmd + Space`, type `Terminal`)
   - Linux: open your terminal application
2. Run:
   ```sh
   ssh mks@YOUR_PRINTER_IP
   ```
   Use `qidi` instead of `mks` for a Max 4.
3. Type `yes` if asked about the fingerprint
4. Enter the password from the table above

---

## Troubleshooting

**"Connection refused" or "No route to host"**

- Make sure the printer is powered on and connected to your network
- Double-check the IP address
- Try pinging the printer first: `ping YOUR_PRINTER_IP`

**"Host key verification failed"**

This happens when the printer was reflashed and its key changed. Run:

```sh
ssh-keygen -R YOUR_PRINTER_IP
```

Then try connecting again.

**Wrong password**

The default passwords are listed in the table at the top. Passwords are case-sensitive.

**On Windows, `ssh` command not found**

You may be on an older version of Windows. Install [PuTTY](https://www.putty.org/) as an alternative SSH client.
