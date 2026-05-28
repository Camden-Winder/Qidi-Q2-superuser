# Happier Hare

Happier Hare is the Qidi Q2 compatibility layer for HelixScreen's Happy Hare
backend. Its first job is native Qidi Box drying in HelixScreen without relying
on macro buttons.

## Goal

On BunnyBox installs, Happy Hare owns the Qidi Box hardware. HelixScreen
v0.99.70 already contains an AMS environment/dryer overlay, but its Happy Hare
backend does not expose that overlay on the Q2 path. Happier Hare patches that
backend so the native environment indicator and dryer controls can appear.

## Patch Set

`patches/helixscreen-v0.99.70-happier-hare.patch` changes HelixScreen v0.99.70:

- exposes Happy Hare as an environment-capable backend for the AMS panel
- marks Happy Hare dryer support available for the Qidi/BunnyBox path
- subscribes to Happy Hare/Qidi Box `temperature_sensor box<N>_env` sensors
  and stock-path `aht20_f heater_box<N>` sensors with humidity fields
- maps `heater_generic box<N>_heater` temperature/target state into the dryer
  status model
- maps Qidi Box heater/environment temperature and humidity into Happy Hare's
  AMS environment model while BunnyBox owns the MMU
- shows the environment indicator even when Happy Hare has no separate humidity
  sensor value to publish
- displays dryer temperature from `DryerInfo` when per-unit environment data is
  absent
- sends `MMU_HEATER DRY=1 TEMP=... TIMER=...` instead of `DURATION=...`
- sends `MMU_HEATER STOP=1` for stop, matching Happy Hare's command parser

## Installer

`install_happier_hare.sh` supports four paths:

```bash
# Install a prebuilt patched HelixScreen zip
./install_happier_hare.sh --install-zip URL

# Patch command strings in the HelixScreen binary already installed on the Q2
./install_happier_hare.sh --patch-installed-binary

# Clone HelixScreen v0.99.70 and apply the source patch
./install_happier_hare.sh --patch-source

# Patch, build, and install locally when a Pi DRM toolchain is available
./install_happier_hare.sh --build-source
```

On the printer, the AIO always installs the official HelixScreen zip first and
then applies an in-place binary command patch. That local patch does not need a
GitHub Actions artifact and fixes the Happy Hare command mismatches:
`DURATION=` becomes `TIMER=`, and `DRY=0` becomes `STOP=1` when the binary has
safe padding for the longer string.

The full native UI and Box humidity patch still requires a rebuilt HelixScreen
binary, because Moonraker subscription fields, environment indicator visibility,
and dryer-overlay behavior are compiled C++ logic. That artifact can be supplied
through `HAPPIER_HARE_ZIP_URL` or `--install-zip`. The AIO also probes the
stable release asset
`happier-hare-rc2.0/helixscreen-pi.zip` and installs it automatically once that
asset exists.

## Local Docker Build

To avoid waiting on GitHub Actions, build the patched Pi archive locally:

```bash
./Happier_Hare/build_patched_helixscreen_zip_docker.sh
```

The script clones HelixScreen v0.99.70 into `/private/tmp`, applies the Happier
Hare patch, builds the Pi DRM/fbdev binaries in Docker, and writes:

```text
Happier_Hare/dist/helixscreen-pi.zip
Happier_Hare/dist/helixscreen-pi-happier-hare-RC2.11.zip
```

Copy the plain zip to the Q2 and point AIO at that local file:

```bash
scp Happier_Hare/dist/helixscreen-pi.zip mks@<printer-ip>:/home/mks/helixscreen-pi-happier-hare.zip

curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/All_in_One_Installer/aio_menu.sh |
HAPPIER_HARE_ZIP_URL=/home/mks/helixscreen-pi-happier-hare.zip \
AIO_REPO_REF=main \
bash
```

Local source builds target the Pi DRM binary used on the Qidi Q2
(`/dev/dri/card0`) and require the `aarch64-linux-gnu-g++` toolchain.

## RC2.0 Scope

RC2.0 should not remove the macro buttons yet. They remain the fallback and a
diagnostic path. The native HelixScreen dryer control becomes the primary path
after a patched HelixScreen artifact is installed and verified on hardware.
