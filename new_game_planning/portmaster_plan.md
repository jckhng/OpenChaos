# PortMaster Handheld Port Plan

## Goal

Package `new_game` as an OpenChaos PortMaster port for SBC handhelds, following
standard PortMaster package conventions.

The target output is a PortMaster-compatible archive containing:

- a top-level launcher script
- an `openchaos/` game directory
- `port.json`
- `gameinfo.xml`
- a `gptokeyb` mapping
- the `aarch64` OpenChaos binary
- bundled shared libraries needed by the binary
- empty runtime/resource folders with install instructions

Original game resources must not be committed or bundled unless the repository
already has the legal right to redistribute them.

## Reference

Important PortMaster conventions for this package:

- `openchaos.sh` lives at the package root.
- The game payload lives under `openchaos/`.
- Runtime state is isolated under `openchaos/runtime/`.
- User-supplied assets live under `openchaos/assets/`.
- The launcher discovers PortMaster's `control.txt`, calls `get_controls`,
  exports `SDL_GAMECONTROLLERCONFIG`, calls `pm_platform_helper`, runs the
  binary, then calls `pm_finish`.
- `port.json` uses PortMaster metadata version `2`.
- `gameinfo.xml` points EmulationStation-style frontends at the top-level
  launcher script.

## Current OpenChaos Facts To Confirm

- Binary name is `OpenChaos` on Linux.
- Build output currently lands in `new_game/build/Release/`.
- Runtime resources are copied beside the executable from
  `original_game_resources/`.
- The current Linux launcher simply runs `./OpenChaos "$@"`.
- OpenChaos uses SDL3, OpenAL, FFmpeg, nlohmann-json, and OpenGL.
- The OpenGL backend currently targets OpenGL 4.1 Core Profile.
- On the target muOS/PortMaster handheld, native vcpkg SDL3 failed with
  `SDL_INIT_VIDEO failed: No available video device`. The current hardware path
  uses bmdhacks' SDL3 `sdl2-backend` branch, which exposes SDL3 to OpenChaos but
  delegates video/audio/input to the firmware's SDL2 library.
- The same target could not create the original desktop OpenGL 4.1 core context.
  PortMaster builds now use the `OPENCHAOS_GLES=ON` CMake switch to request an
  OpenGL ES context and adapt embedded GLSL sources to `#version 300 es`.

The OpenGL requirement is the main handheld risk. Many PortMaster devices expose
OpenGL ES rather than desktop OpenGL 4.1. Before treating the port as shippable,
verify the target firmware/device GPU stack can create the required context or
add an OpenGL ES-compatible backend/path.

## Proposed Package Layout

```text
OpenChaos-portmaster/
  openchaos.sh
  openchaos/
    OpenChaos.aarch64
    openchaos.gptk
    port.json
    gameinfo.xml
    assets/
      .gitkeep
    controls/
      .gitkeep
    lib/
      .gitkeep
    libs.aarch64/
      .gitkeep
    runtime/
      .gitkeep
```

`assets/` should be where users place the original game resources, unless code
inspection shows OpenChaos must have resources directly beside the binary. If it
does, the launcher or package layout should adapt to the current resource lookup
instead of requiring code changes for the first packaging pass.

## Launcher Plan

Create `openchaos.sh` for PortMaster:

1. Locate PortMaster's control folder.
2. Source `control.txt` and optional `mod_${CFW_NAME}.txt`.
3. Call `get_controls`.
4. Set:
   - `GAMEDIR=/$directory/ports/openchaos/`
   - `RUNTIME_DIR="$GAMEDIR/runtime"`
   - `ASSETS_DIR="$GAMEDIR/assets"`
   - `BIN="$GAMEDIR/OpenChaos.${DEVICE_ARCH}"`
5. Create runtime, home, and assets directories.
6. Redirect stdout/stderr to `openchaos/log.txt`.
7. Export:
   - `HOME="$RUNTIME_DIR/home"`
   - `XDG_DATA_HOME="$RUNTIME_DIR"`
   - `SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"`
   - `LD_LIBRARY_PATH` including `libs.${DEVICE_ARCH}` and `lib`
   - `SDL3SHIM_SDL2_LIB=libSDL2-2.0.so.0` by default
   - leave `SDL_VIDEODRIVER` unset so the real SDL2 runtime can choose the
     handheld's native video backend
8. Leave `gptokeyb` disabled by default because OpenChaos reads SDL gamepad
   input natively. Keep `openchaos.gptk` as an opt-in fallback for diagnostics.
9. Call `pm_platform_helper "$BIN"`.
10. Launch the binary from `GAMEDIR`.
11. Call `pm_finish`.

If OpenChaos gains CLI flags for resource directory, resolution, or fullscreen,
pass them from the launcher. If it does not, prefer environment/runtime layout
that matches current behavior before changing game code.

## Controls Plan

OpenChaos has native SDL gamepad support, so the launcher should use the native
mapping by default. Keep a `gptokeyb` fallback based on OpenChaos'
keyboard/mouse layout for menu or firmware-specific diagnostics:

- left stick: `WASD`
- D-pad: arrow keys or weapon quick-select keys after testing menu behavior
- A: `space`
- B: `esc`
- X: `f`
- Y: `c`
- L1: `mouse_middle` or the keyboard equivalent for aim
- L2: `leftctrl`
- R1: `mouse_right`
- R2: `mouse_left`
- Start: `esc`
- Select: `tab`

This mapping should remain opt-in. Running native SDL input and `gptokeyb`
together can duplicate gameplay controls.

## Build Plan

1. Add a PortMaster/aarch64 CMake toolchain or documented build path.
2. Build a Release `aarch64` binary named `OpenChaos.aarch64`.
3. For SDL3 on handheld firmware, build against bmdhacks' SDL
   `sdl2-backend` branch with:
   - `VCPKG_MANIFEST_NO_DEFAULT_FEATURES=ON` so vcpkg does not install normal
     SDL3
   - `OPENCHAOS_GLES=ON`
   - `OPENCHAOS_SDL3_SOURCE_DIR` pointing at the SDL shim source tree
   - `SDL_SDL2_BACKEND=ON`
   - `SDL_UNIX_CONSOLE_BUILD=ON`
   - desktop/native SDL video and audio backends disabled
4. Collect shared libraries required by the binary, including vcpkg runtime
   libs and the source-built shim `libSDL3.so*`.
5. Stage the package layout under `release/dist/` or `artifacts/portmaster/`.
6. Zip the staged package.

Do not assume the existing `linux-x64` release package is usable on handhelds.
The PortMaster package needs a target-device `aarch64` build and matching
runtime libraries.

## Metadata Plan

Create `port.json` with:

- `name`: `openchaos`
- `title`: `OpenChaos`
- `desc`: native OpenChaos rewrite packaged for PortMaster handhelds
- `inst`: tell users where to place original game resources
- `genres`: `action`, `adventure`
- `runtime`: `blank` unless testing proves a PortMaster runtime is required
- `arch`: `aarch64`

Create `gameinfo.xml` with:

- path `./openchaos.sh`
- name `OpenChaos`
- genre/action-adventure metadata
- one player
- community/rewrite developer and publisher fields

## Implementation Steps

1. Audit resource lookup paths in `new_game/src`.
2. Audit command-line/runtime options in startup code.
3. Add staged PortMaster template files.
4. Add packaging automation that fails clearly when the aarch64 binary is absent.
5. Add concise install/readme text for original resources.
6. Run validation:
   - shell syntax check for launcher
   - JSON parse for `port.json`
   - XML parse for `gameinfo.xml`
   - package layout listing
7. On hardware or matching firmware, test:
   - launch from PortMaster
   - resource discovery
   - video/context creation
   - controller input
   - audio playback
   - suspend/resume and exit behavior

## Risks

- Desktop OpenGL 4.1 may not be supported on many SBC handhelds.
- Native SDL3 availability may differ from PortMaster's common runtimes; this
  port currently depends on the bmdhacks SDL3-to-SDL2 shim and the device's
  system `libSDL2-2.0.so.0`.
- FFmpeg/OpenAL shared library versions may need bundling.
- Resource paths may currently require files beside the executable.
- Native gamepad support and `gptokeyb` may conflict if both feed gameplay
  input simultaneously.

## Done Criteria

- A reproducible PortMaster package can be generated.
- Package metadata validates.
- Launcher follows PortMaster conventions.
- Original resource installation path is documented.
- The binary starts on at least one target handheld or equivalent firmware image.
- Controls, audio, rendering, and clean exit are verified.
