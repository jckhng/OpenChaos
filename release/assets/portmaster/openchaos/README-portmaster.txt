OpenChaos PortMaster package
============================

Install:

1. Copy openchaos.sh and the openchaos/ folder to your PortMaster ports folder.
2. Copy your original Urban Chaos game resources into openchaos/assets/.
3. Launch OpenChaos from PortMaster.

The launcher links files from openchaos/assets/ into the OpenChaos working
directory at startup. At minimum, the game expects clumps/frontend.txc,
data/DARCI1.all, and a language file such as text/lang_english.txt.

This PortMaster build ships an SDL3 shim that uses the device's SDL2 runtime.
The launcher loads libSDL2-2.0.so.0 from the firmware library path. Leave
SDL_VIDEODRIVER unset unless selecting the underlying SDL2 backend through
SDL3SHIM_SDL2_VIDEODRIVER.

This package is built for the handheld OpenGL ES path. Desktop builds still use
the OpenGL 4.1 renderer.

Controls use OpenChaos' native SDL gamepad mapping. gptokeyb is disabled by
default to avoid duplicate controller and synthetic keyboard/mouse input. Set
OPENCHAOS_USE_GPTOKEYB=1 before launch only when testing the fallback
openchaos.gptk mapping.
