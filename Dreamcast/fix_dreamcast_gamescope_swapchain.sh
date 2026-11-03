#!/usr/bin/env bash
# ==============================================================================
# Dreamcast (Flycast) & SteamOS Gamescope Vulkan Swapchain Fix
# Resolves:
#   "CreateSwapchainKHR: Creating swapchain for non-Gamescope swapchain.
#    Hooking has failed somewhere! You may have a bad Vulkan layer interfering."
# ==============================================================================
set -euo pipefail

flatpak override --user \
  --env=DISABLE_GAMESCOPE_WSI=1 \
  --env=ENABLE_GAMESCOPE_WSI=0 2>/dev/null || true

for fp_id in org.flycast.Flycast info.cemu.Cemu org.libretro.RetroArch; do
  flatpak override --user \
    --filesystem=/home/deck/Games \
    --filesystem=/run/udev:ro \
    --device=all \
    --env=DISABLE_GAMESCOPE_WSI=1 \
    --env=ENABLE_GAMESCOPE_WSI=0 \
    --env=SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD=1 \
    --env=SDL_JOYSTICK_HIDAPI_STEAM=1 \
    --env=SDL_JOYSTICK_HIDAPI_STEAMDECK=1 \
    --env=SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1 \
    --env=SDL_GAMECONTROLLER_IGNORE_DEVICES= \
    "$fp_id" 2>/dev/null || true
done

mkdir -p /home/deck/Games/launchers
cat << 'EOF' > /home/deck/Games/launchers/flycast.sh
#!/usr/bin/env bash
if [ -x "/home/deck/Games/sync_saves.sh" ]; then "/home/deck/Games/sync_saves.sh" --pull >/dev/null 2>&1 || true; fi
export DISABLE_GAMESCOPE_WSI=1
export ENABLE_GAMESCOPE_WSI=0
export SDL_GAMECONTROLLER_IGNORE_DEVICES=""
export SDL_JOYSTICK_HIDAPI_STEAM=1
export SDL_JOYSTICK_HIDAPI_STEAMDECK=1
export SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1
if [ -f "/home/deck/Games/.master_config_backup/flycast/emu.cfg" ]; then
  mkdir -p /home/deck/.var/app/org.flycast.Flycast/config/flycast
  cp -f "/home/deck/Games/.master_config_backup/flycast/emu.cfg" /home/deck/.var/app/org.flycast.Flycast/config/flycast/emu.cfg
fi
ORIG_ARG="${1:-}"
ROM_ARG="$ORIG_ARG"
if [[ "$ROM_ARG" == *.m3u ]] && [ -f "$ROM_ARG" ]; then
  FIRST_DISC=$(grep -v '^[[:space:]]*#' "$ROM_ARG" | grep -v '^[[:space:]]*$' | head -n 1 | tr -d "\r\n")
  if [ -n "$FIRST_DISC" ]; then
    if [[ "$FIRST_DISC" == /* ]]; then
      ROM_ARG="$FIRST_DISC"
    else
      ROM_ARG="$(dirname "$ROM_ARG")/$FIRST_DISC"
    fi
  fi
fi
if [[ "$ROM_ARG" == *.cdi ]] && [ -f "${ROM_ARG%.cdi}.chd" ]; then
  ROM_ARG="${ROM_ARG%.cdi}.chd"
fi
DC_REGION=1
REGION_CHECK="${ORIG_ARG,,} ${ROM_ARG,,}"
case "$REGION_CHECK" in
  *"(europe"*|*"(eur"*|*"(pal"*)
    DC_REGION=2
    ;;
  *"(japan"*|*"(jpn"*|*"(jp"*)
    DC_REGION=0
    ;;
esac
/usr/bin/flatpak run \
  --env=DISABLE_GAMESCOPE_WSI=1 \
  --env=ENABLE_GAMESCOPE_WSI=0 \
  org.flycast.Flycast \
  -config audio:backend=alsa \
  -config config:aica.BufferSize=4096 \
  -config config:aica.AutoLatency=no \
  -config config:aica.DSPEnabled=no \
  -config config:pvr.rend=4 \
  -config config:rend.ThreadedRendering=yes \
  -config config:Dreamcast.Broadcast=0 \
  -config config:Dreamcast.Region="$DC_REGION" \
  -config config:Dreamcast.Cable=0 \
  -config window:fullscreen=yes \
  "$ROM_ARG"
if [ -x "/home/deck/Games/sync_saves.sh" ]; then nohup "/home/deck/Games/sync_saves.sh" --push >/dev/null 2>&1 & fi
EOF
chmod +x /home/deck/Games/launchers/flycast.sh

python3 -c '
import glob, os
targets = [
    "/home/deck/Games/launchers/cemu.sh",
    "/home/deck/Games/launchers/retroarch.sh",
    "/home/deck/Games/launchers/azahar.sh",
    "/home/deck/Games/launchers/xenia.sh",
] + sorted(glob.glob("/home/deck/Games/launchers/port_*.sh"))

for p in targets:
    if not os.path.exists(p):
        continue
    with open(p, "r", encoding="utf-8") as f:
        s = f.read()
    changed = False
    if "export DISABLE_GAMESCOPE_WSI=1" not in s:
        lines = s.splitlines(keepends=True)
        if lines and lines[0].startswith("#!"):
            lines.insert(1, "export DISABLE_GAMESCOPE_WSI=1\nexport ENABLE_GAMESCOPE_WSI=0\n")
        else:
            lines.insert(0, "export DISABLE_GAMESCOPE_WSI=1\nexport ENABLE_GAMESCOPE_WSI=0\n")
        s = "".join(lines)
        changed = True
    if "/usr/bin/flatpak run " in s and "--env=DISABLE_GAMESCOPE_WSI=1" not in s:
        s = s.replace("/usr/bin/flatpak run ", "/usr/bin/flatpak run --env=DISABLE_GAMESCOPE_WSI=1 --env=ENABLE_GAMESCOPE_WSI=0 ")
        changed = True
    if changed:
        with open(p, "w", encoding="utf-8") as f:
            f.write(s)
'

echo "[OK] Applied DISABLE_GAMESCOPE_WSI=1 and ENABLE_GAMESCOPE_WSI=0 across Flycast & SteamOS emulator launchers."
