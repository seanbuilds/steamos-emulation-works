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
