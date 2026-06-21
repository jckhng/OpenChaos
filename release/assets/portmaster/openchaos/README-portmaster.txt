OpenChaos PortMaster package
============================

Install:

1. Copy openchaos.sh and the openchaos/ folder to your PortMaster ports folder.
2. Copy your original Urban Chaos game resources into openchaos/assets/.
3. Launch OpenChaos from PortMaster.

When original game resources are present in openchaos/assets/, the launcher runs
OpenChaos with that folder as the working directory. This avoids symlink issues
on SD-card filesystems. At minimum, the game expects clumps/frontend.txc,
data/DARCI1.all, and a language file such as text/lang_english.txt.

This PortMaster build ships an SDL3 shim that uses the device's SDL2 runtime.
The launcher loads libSDL2-2.0.so.0 from the firmware library path. Leave
SDL_VIDEODRIVER unset unless selecting the underlying SDL2 backend through
SDL3SHIM_SDL2_VIDEODRIVER.

This package is built for the handheld OpenGL ES path. Desktop builds still use
the OpenGL 4.1 renderer.

Controls use OpenChaos' native SDL gamepad mapping. gptokeyb is started only so
PortMaster's Start+Select quit combo works; openchaos.gptk maps gameplay
buttons to no-ops to avoid duplicate synthetic keyboard/mouse input.

Controller layout:

Open the in-game Options menu and set Controls to HANDHELD for the recommended
PortMaster layout, or CUSTOM to use openchaos/controls/gamepad.json.

OPENCHAOS keeps the upstream native SDL layout. HANDHELD keeps movement on the
left stick, camera on the right stick, A/Cross as jump, B/Circle as sprint/back,
X/Square as punch/shoot, Y/Triangle as kick, R1 as use/interact, L1 as aim/back
walk, L2 as tactical/roll, R3 as inventory/weapon cycle, Start as pause, and the
D-pad as weapon shortcuts. While driving, R2 accelerates, L1 brakes, L2 reverses,
and Y/Triangle toggles the siren.

Custom controls:

Edit openchaos/controls/gamepad.json, then select Controls: CUSTOM in the
in-game Options menu. The file maps game actions to SDL gamepad button names.
Accepted names are south/a/cross, east/b/circle, west/x/square,
north/y/triangle, select/back/view, start/menu/options, l1/lb, r1/rb, l2/lt,
r2/rt, l3/left_stick, r3/right_stick, dpad_up, dpad_down, dpad_left,
dpad_right, and none.

Punch/shoot has two fields: punch for a digital button and punch_trigger for an
analog trigger. Set punch_trigger to none if you want punch/shoot only on the
digital button.

Movement, camera look, D-pad weapon shortcuts, and proportional analog driving
remain fixed in this first custom-binding version.
