#!/bin/bash
unset LD_PRELOAD

mkdir -p /home/deck/.var/app/info.cemu.Cemu/config/Cemu/controllerProfiles
mkdir -p /home/deck/.var/app/info.cemu.Cemu/data/Cemu/gameProfiles

# Always restore verified controller and game profiles before Cemu boots
cp -f /home/deck/Emulation/tools/.master_config_backup/cemu/controllerProfiles/*.xml \
      /home/deck/.var/app/info.cemu.Cemu/config/Cemu/controllerProfiles/ 2>/dev/null
cp -f /home/deck/Emulation/tools/.master_config_backup/cemu/gameProfiles/*.ini \
      /home/deck/.var/app/info.cemu.Cemu/data/Cemu/gameProfiles/ 2>/dev/null

# Lock permissions to 0444 so Cemu cannot overwrite on exit
chmod 444 /home/deck/.var/app/info.cemu.Cemu/config/Cemu/controllerProfiles/*.xml 2>/dev/null
chmod 444 /home/deck/.var/app/info.cemu.Cemu/data/Cemu/gameProfiles/*.ini 2>/dev/null

exec /usr/bin/flatpak run \
  --filesystem=/run/media/deck/SN850X:rw \
  --filesystem=/home/deck/Emulation:rw \
  info.cemu.Cemu -f -g "$@"
