#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR=/$directory/ports/openchaos/
RUNTIME_DIR="$GAMEDIR/runtime"
ASSETS_DIR="$GAMEDIR/assets"
BIN="$GAMEDIR/OpenChaos.${DEVICE_ARCH}"

mkdir -p "$RUNTIME_DIR" "$RUNTIME_DIR/home" "$ASSETS_DIR"

cd "$GAMEDIR"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

export HOME="$RUNTIME_DIR/home"
export XDG_DATA_HOME="$RUNTIME_DIR"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$GAMEDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [ "${SDL_VIDEODRIVER:-}" = "sdl2" ]; then
  unset SDL_VIDEODRIVER
fi
export SDL3SHIM_SDL2_LIB="${SDL3SHIM_SDL2_LIB:-libSDL2-2.0.so.0}"

# OpenChaos currently reads original game resources from the working directory.
# Allow users to keep those files under assets/ by linking missing entries into
# GAMEDIR without replacing anything already installed at the top level.
if [ -d "$ASSETS_DIR" ]; then
  for item in "$ASSETS_DIR"/* "$ASSETS_DIR"/.[!.]*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"
    [ "$name" = "." ] && continue
    [ "$name" = ".." ] && continue
    [ -e "$GAMEDIR/$name" ] && continue
    ln -s "$item" "$GAMEDIR/$name" 2>/dev/null || true
  done
fi

if [ "${OPENCHAOS_USE_GPTOKEYB:-0}" = "1" ]; then
  $GPTOKEYB "OpenChaos.${DEVICE_ARCH}" -c "$GAMEDIR/openchaos.gptk" &
fi

pm_platform_helper "$BIN"

"$BIN"

pm_finish
