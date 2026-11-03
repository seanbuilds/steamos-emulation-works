#!/usr/bin/env bash
killall -15 Cemu_relwithdebinfo Cemu-wrapper 2>/dev/null || true
sleep 0.5
/usr/bin/flatpak kill info.cemu.Cemu 2>/dev/null || true
killall -9 Cemu_relwithdebinfo Cemu-wrapper 2>/dev/null || true
cleanup() {
  trap - EXIT TERM INT HUP
  if [ -n "${HELPER_PID:-}" ]; then kill "$HELPER_PID" 2>/dev/null || true; fi
  killall -15 Cemu_relwithdebinfo Cemu-wrapper 2>/dev/null || true
  sleep 1
  /usr/bin/flatpak kill info.cemu.Cemu 2>/dev/null || true
  killall -9 Cemu_relwithdebinfo Cemu-wrapper 2>/dev/null || true
  DISPLAY=:0 xprop -root -f GAMESCOPECTRL_BASELAYER_APPID 32c -set GAMESCOPECTRL_BASELAYER_APPID "769" 2>/dev/null || true
  if [ -x "/home/deck/Games/sync_saves.sh" ]; then nohup "/home/deck/Games/sync_saves.sh" --push >/dev/null 2>&1 & fi
}
trap cleanup EXIT TERM INT HUP
if [ -x "/home/deck/Games/sync_saves.sh" ]; then "/home/deck/Games/sync_saves.sh" --pull >/dev/null 2>&1 || true; fi
if [ -d "/home/deck/Games/.cemu_config_backup/cemu" ]; then
  mkdir -p /home/deck/.var/app/info.cemu.Cemu/config/Cemu /home/deck/.var/app/info.cemu.Cemu/data/Cemu
  cp -rf /home/deck/Games/.cemu_config_backup/cemu/* /home/deck/.var/app/info.cemu.Cemu/config/Cemu/ 2>/dev/null || true
  cp -rf /home/deck/Games/.cemu_config_backup/cemu/* /home/deck/.var/app/info.cemu.Cemu/data/Cemu/ 2>/dev/null || true
fi
export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export GDK_BACKEND=x11
export DISABLE_GAMESCOPE_WSI=1
export ENABLE_GAMESCOPE_WSI=0
export SDL_GAMECONTROLLER_IGNORE_DEVICES=""
export SDL_JOYSTICK_HIDAPI_STEAM=1
export SDL_JOYSTICK_HIDAPI_STEAMDECK=1
export SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1
APP_ID="${SteamAppId:-${STEAM_GAME:-}}"
if [ -z "$APP_ID" ] || [ "$APP_ID" = "0" ]; then
  P=$PPID
  while [ "$P" -gt 1 ] 2>/dev/null; do
    APP_ID=$(tr "\0" "\n" < /proc/$P/cmdline 2>/dev/null | sed -n "s/^AppId=//p" | head -n 1)
    [ -n "$APP_ID" ] && [ "$APP_ID" != "0" ] && break
    P=$(awk '/^PPid:/{print $2}' /proc/$P/status 2>/dev/null || echo 1)
  done
fi
if [ -z "$APP_ID" ] || [ "$APP_ID" = "0" ]; then APP_ID=2348635137; fi
export SteamAppId="$APP_ID"
export STEAM_GAME="$APP_ID"
(
  for _ in $(seq 1 80); do
    sleep 0.25
    for D in "$DISPLAY" :1 :0; do
      WIDS=$(xwininfo -root -tree -display "$D" 2>/dev/null | awk '/Cemu/ && !/10x10/ && !/1x1/{print $1}')
      if [ -n "$WIDS" ]; then
        for W in $WIDS; do
          xprop -display "$D" -id "$W" -f STEAM_GAME 32c -set STEAM_GAME "$APP_ID" 2>/dev/null || true
          for CW in $(xwininfo -id "$W" -tree -display "$D" 2>/dev/null | awk '/0x/ && !/1x1/ && !/10x10/{print $1}'); do
            xprop -display "$D" -id "$CW" -f STEAM_GAME 32c -set STEAM_GAME "$APP_ID" 2>/dev/null || true
          done
        done
        xprop -display :0 -root -f GAMESCOPECTRL_BASELAYER_APPID 32c -set GAMESCOPECTRL_BASELAYER_APPID "$APP_ID, 769" 2>/dev/null || true
      fi
    done
  done
) &
HELPER_PID=$!
ROM_ARG=$(readlink -f "${1:-}" 2>/dev/null || echo "${1:-}")
/usr/bin/flatpak run --filesystem=host --filesystem=/run/media/deck:rw --socket=x11 --nosocket=wayland --nosocket=fallback-x11 --env=GDK_BACKEND=x11 --env=DISABLE_GAMESCOPE_WSI=1 --env=ENABLE_GAMESCOPE_WSI=0 info.cemu.Cemu -f -g "$ROM_ARG" &
CEMU_PID=$!
wait "$CEMU_PID" 2>/dev/null || true
