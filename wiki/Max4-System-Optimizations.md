# Max 4 System Optimizations

The AIO includes optional system-level improvements available under **option 3 — System Optimizations**. Each item is confirmed individually before running. All are reversible via **Revert to Backup**.

---

## 1. DNS Fix

**What the problem is:** The Max 4 ships with `/etc/resolv.conf` hardcoded to `114.114.114.114`, a Chinese public DNS resolver. This can cause slow or failed DNS lookups if you're outside China, and is not integrated with your router's DHCP-assigned DNS.

**What the fix does:** Replaces the hardcoded resolver with Cloudflare (`1.1.1.1`) and Google (`8.8.8.8`) and integrates with the system's DHCP client so DNS updates when your network changes.

---

## 2. APT Sources Fix

**What the problem is:** The package manager is configured to use USTC mirrors (China-based), which are slow or unreachable outside China.

**What the fix does:** Switches the APT sources to `deb.debian.org`, the standard Debian mirror network, which selects a geographically appropriate mirror automatically.

---

## 3. Disable xl2tpd

**What it is:** `xl2tpd` is an L2TP VPN daemon. It has no purpose on a 3D printer.

**What the fix does:** Disables and masks `xl2tpd.service`, removing it from the network attack surface. No printer functionality is affected.

---

## 4. Disable algo_app

**What it is:** `algo_app.service` is Qidi's AI/video detection service. It ships with the following credentials hardcoded in plaintext:

- **Username:** `qidi`
- **Password:** `qiditech`
- **LAN API port:** `9010`

The API is exposed to your local network with no authentication beyond these credentials.

**What the fix does:** Disables and masks `algo_app.service`, which:
- Removes 13–15% idle CPU usage
- Closes LAN-exposed port 9010
- Prevents the plaintext credentials from being accessible on your network

**What stops working:** The AI detection features in the touchscreen UI. These are Qidi's camera-based detection overlays. If you need them, re-enable via System Optimizations.

---

## 5. Static GIFs

**What the problem is:** The touchscreen UI (`qidi-client`) uses animated GIF spinners for loading states. Rendering animated GIFs consumes approximately 55% of the touchscreen CPU continuously.

**What the fix does:** Replaces the animated GIFs with single-frame static versions. This drops touchscreen CPU usage from ~55% to ~3%.

**What changes:** The animated spinners become static. Functionality is unchanged — the spinners appear and disappear the same way, they just don't animate.

---

All five optimizations are reversible. **Revert to Backup** restores the original system state including these changes.
