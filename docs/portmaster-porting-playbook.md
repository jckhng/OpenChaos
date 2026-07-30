# PortMaster Porting, Debugging, and Submission Playbook

This document records the OpenChaos handheld-port work completed through
2026-07-23 and extracts a reusable process for other native PortMaster ports.

Current upstream references:

- [PortMaster-New contribution README](https://github.com/PortsMaster/PortMaster-New#submitting-a-pr)
- [PortMaster packaging documentation](https://portmaster.games/packaging.html)
- [PortMaster-New agent and reviewer rules](https://github.com/PortsMaster/PortMaster-New/blob/main/AGENTS.md)
- [OpenChaos explosion crash fix PR](https://github.com/UltimaBeaR/OpenChaos/pull/7)

## OpenChaos Progress Record

### Initial handheld port

The desktop OpenChaos renderer requested OpenGL 4.1 and used SDL3 directly.
Typical SBC firmware exposed OpenGL ES and a firmware-patched SDL2 instead.
The handheld port therefore added:

- an OpenGL ES build path and ES-compatible shaders;
- bmdhacks' SDL3-to-SDL2 backend shim;
- a PortMaster launcher using the firmware SDL2 controller mapping;
- gptokeyb only for the PortMaster Start+Select exit combination;
- native handheld and configurable gamepad layouts;
- resource lookup from `openchaos/assets/` without filesystem symlinks;
- 4:3 rendering with pillarboxing or letterboxing on other display ratios.

The port was tested during development on a 640x480 handheld and on Knulli.
Broader distribution and resolution testing remains necessary for an upstream
PortMaster submission.

### Arms Breaker explosion crash

A tester, elieder on Discord, reported a hard crash when an explosive detonated
near the player in the Arms Breaker mission. Moving far enough away to avoid
rendering the explosion effect avoided the crash. This isolated the failure to
the visible effect path rather than mission progression, audio, or rumble.

The reproduction process was:

1. Preserve the tester's exact scenario and logs.
2. Create a small save that unlocked the mission directly.
3. Record the save filename and SHA-256 in the bug report.
4. Produce an unchanged binary and a candidate fixed binary from the same
   build environment.
5. Confirm that the unchanged binary crashed at the expected point.
6. Move the active crash from one particle path to another while narrowing the
   fault, proving that both paths needed the same boundary fix.
7. Keep invulnerability and other test aids out of the production commit.

The root cause was undefined behavior in explosion particle rendering.
`SIN(a)` and `COS(a)` are raw lookups into 2048-entry tables. Random values in
`pyro->radii[]` were shifted and then used as indexes without wrapping. The fix
masks derived direction values with `& 2047` before the table lookups in both
`PYRO_draw_twanger` and `PYRO_draw_streambit`.

The production fix deliberately did not include:

- hardcoded invulnerability;
- experimental POW guards;
- device logs, test saves, or diagnostic binaries;
- changes to rumble, which was not the cause.

The minimized upstream report includes the root cause, reproduction procedure,
save hash, before/after validation, and reporter credit. That format is useful
for any bug that is difficult to reach through normal gameplay.

### Progressive slowdown observation

Performance appeared to worsen during longer sessions, but no memory leak was
demonstrated. This observation was kept separate from the deterministic
explosion crash. Do not combine unproven performance theories with a confirmed
memory-safety fix. Revisit it with frame-time, allocation, and resident-memory
measurements before changing code.

### Older ArkOS compatibility failure

An R36S ArkOS tester exposed that existing PortMaster releases required newer
runtime symbols than the device supplied:

- old package: up to `GLIBC_2.38` and `GLIBCXX_3.4.31`;
- rebuilt package: up to `GLIBC_2.29` and `GLIBCXX_3.4.26`.

Historical package inspection showed that this was not introduced by the
explosion fix. Earlier releases had also been built on Ubuntu 24.04 with GCC 13.
The build environment, not recent source changes, set the incompatible ABI
floor.

The corrected build used an Ubuntu 20.04 Focal baseline with GCC 10 and rebuilt
the executable and every bundled shared library. OpenAL Soft 1.25 required C++
`<format>`, which this compiler did not provide, so OpenAL Soft was pinned to
1.24.3. The build also added explicit pthread linkage and an
`$ORIGIN/libs.aarch64` runtime search path.

Important conclusions:

- Container age determines the minimum userspace ABI unless an older sysroot is
  selected explicitly.
- A successful cross-compile does not prove compatibility with the target OS.
- Rebuilding only the executable is insufficient if bundled libraries retain a
  newer GLIBC requirement.
- Compare symbol versions in historical packages before calling a problem a
  regression.
- Validate the final staged package, not an intermediate build directory.

### PortMaster metadata and package layout

On 2026-07-23, the local package template was aligned with
`PortsMaster/PortMaster-New` and the existing `ports/openchaos/` entry:

```text
openchaos/
  Open Chaos.sh
  README.md
  gameinfo.xml
  port.json
  screenshot.png
  openchaos/
    OpenChaos.aarch64
    controls/gamepad.json
    licenses/
    libs.aarch64/
    openchaos.gptk
```

The canonical version-4 `port.json`, descriptions, user README, game XML, and
screenshot are reused. The package generator now produces both:

```text
release/dist/ports/openchaos/
release/dist/OpenChaos-v<VERSION>-portmaster-aarch64.zip
```

The first path can be synchronized directly into a PortMaster-New checkout.
The second path is for direct package testing.

## Reusable Native-Port Workflow

### 1. Establish target constraints

Record these before choosing a build image:

- oldest supported distribution and its GLIBC version;
- CPU architectures;
- graphics stack and supported OpenGL/OpenGL ES versions;
- SDL version supplied by each firmware;
- display resolutions and aspect ratios;
- controller mapping path;
- writable save and configuration directories.

Build against the oldest intended userspace baseline. Newer systems normally
run older binaries; older systems cannot satisfy newer symbol versions.

### 2. Capture a deterministic reproduction

For gameplay crashes, collect:

- exact mission, map, and action sequence;
- whether distance, camera direction, audio, rumble, or particle visibility
  changes the result;
- stdout/stderr and any core dump;
- a minimal save near the fault;
- SHA-256 for every reproduction artifact;
- one known-bad binary and one candidate binary built identically.

Avoid asking testers to replay hours of the game. A minimal save or debug-only
level unlock produces faster and more reliable validation.

### 3. Separate diagnosis from the production patch

Temporary diagnostics may include assertions, logging, invulnerability, or
effect suppression. Before committing:

1. Revert all test-only behavior.
2. Rebuild from the cleaned source tree.
3. Reproduce the original failure with the known-bad build.
4. Confirm the cleaned fixed build passes the same reproduction.
5. Audit the final diff for unrelated guards and local paths.

When an index feeds a table or fixed array, validate the legal domain at the
final lookup boundary. Do not rely on assumptions about random-number width,
signed shifts, or values inherited from legacy platforms.

### 4. Select and record the build baseline

Record all of the following in release notes or build documentation:

- base image and immutable digest;
- compiler and linker versions;
- target triplet and sysroot;
- dependency lockfile or manifest baseline;
- source revision of external shims;
- CMake options that select embedded graphics or input paths.

Do not use a rolling `latest` image without recording its digest. A familiar
image name can silently change its GLIBC and compiler floor.

### 5. Build every shipped ELF against that baseline

This includes:

- the game executable;
- SDL compatibility shims;
- audio libraries;
- codec libraries;
- C++ support libraries that are intentionally bundled.

Do not bundle firmware-owned SDL2, GL/EGL drivers, `libc`, `libstdc++`,
`libpthread`, `librt`, or other core system libraries. PortMaster firmware often
patches these for its display and input stack.

### 6. Audit the ELF ABI

Inspect dynamic dependencies and runtime paths:

```sh
readelf -d OpenChaos.aarch64
readelf --version-info OpenChaos.aarch64
file OpenChaos.aarch64
```

Find the maximum requested GLIBC and GLIBCXX symbols:

```sh
readelf --version-info OpenChaos.aarch64 \
  | grep -oE 'GLIBC(X{2})?_[0-9.]+' \
  | sort -Vu
```

Repeat the symbol check for every `.so` in the package. Then run `ldd` inside
an ARM64 container matching the oldest supported PortMaster baseline:

```sh
LD_LIBRARY_PATH=/bundle/openchaos/libs.aarch64 \
  ldd /bundle/openchaos/OpenChaos.aarch64
```

The check fails if any dependency prints `not found`. If WSL directory mounts
are unavailable, stream a tar archive through container stdin instead of
mounting the directory.

### 7. Package from one canonical tree

Keep metadata in source control and inject only build artifacts during package
generation. The preferred OpenChaos path builds the pinned Focal image, checks
out the locked SDL shim and vcpkg commits, verifies both, builds, and packages:

```sh
docker build \
  -f release/docker/portmaster-aarch64-focal.Dockerfile \
  -t openchaos-portmaster-aarch64-focal .

docker run --rm \
  -e VERSION=0.1.4 \
  -v "$PWD:/workspace" \
  openchaos-portmaster-aarch64-focal
```

The generator must start from a clean staging directory. This removes obsolete
sonames such as an older OpenAL version rather than leaving both versions in the
submission.

Package rules:

- do not include proprietary game data;
- include a license for every bundled component;
- ship only the regular ELF file whose name matches each required `DT_NEEDED`
  SONAME; omit unversioned linker aliases and fully versioned duplicate files;
- never ship library symlinks, because PortMaster extraction on some firmware
  can turn a symlink into a short text file containing only its target name;
- use LF line endings for `.sh` and `.gptk` files;
- commit launcher scripts as mode `0644`;
- let the launcher run `chmod +x` on the game binary;
- do not submit `.gitkeep` files;
- keep screenshots at 640x480;
- keep `port.json`, `gameinfo.xml`, and filenames synchronized.

### 8. Test the staged package

Minimum PortMaster review matrix:

- ArkOS;
- AmberELEC;
- ROCKNIX;
- muOS;
- Knulli;
- 640x480;
- 720x720 where available;
- at least one higher-resolution widescreen display.

Also vary CPU/GPU families where possible. Record device, firmware version,
resolution, launch result, controls, audio, suspend/resume, and exit behavior.
Do not mark a platform as tested based only on container `ldd` output.

### 9. Audit before committing

Check the candidate tree for:

- credentials, tokens, IP addresses, and home-directory paths;
- logs, saves, core dumps, debug binaries, and test cheats;
- proprietary game assets;
- obsolete libraries and duplicate sonames;
- files larger than 90 MB;
- changes outside the intended port directory.

Useful commands:

```sh
git status --short
git diff --check
git diff --stat
find ports/openchaos -type f -size +90M -print
find ports/openchaos -name .gitkeep -print
```

## OpenChaos PortMaster-New Pull Request Procedure

### Prepare the fork

1. Fork `PortsMaster/PortMaster-New` to `jckhng/PortMaster-New` if it is not
   already forked.
2. In the fork, open **Settings > Actions > General** and disable Actions.
3. Use a new feature branch. Never submit from the fork's `main` branch.

For a fresh sparse checkout:

```sh
git clone --filter=blob:none --no-checkout \
  --depth 1 \
  https://github.com/jckhng/PortMaster-New.git \
  PortMaster-New-Fork
cd PortMaster-New-Fork
git config core.sparseCheckout true
printf '%s\n' \
  '/*' \
  '!/*/' \
  '/ports/openchaos/' \
  '/tools/' \
  '/releases/' \
  '/runtimes/.gitignore' \
  '/runtimes/runtimes.json' \
  > .git/info/sparse-checkout
git checkout main
git remote add upstream https://github.com/PortsMaster/PortMaster-New.git
git fetch upstream
git merge --ff-only upstream/main
git push origin main
tools/prepare_repo.sh
git switch -c update-openchaos-focal-build
```

For an existing clean checkout, start at `git fetch upstream`, fast-forward
`main`, run `tools/prepare_repo.sh`, and create a new branch.

If WSL Git 2.25 exits with `fetch-pack died of signal 11`, the fetch did not
create `upstream/main`; a following rebase will report `invalid upstream`.
Do not reclone. Use a newer Git client to fetch the upstream tip and enough
history to expose the merge base. When using Git for Windows against a WSL
checkout, disable its line-ending and file-mode conversion for every command:

```sh
WIN_GIT='/mnt/c/Program Files/Git/cmd/git.exe'
REPO='//wsl.localhost/Ubuntu/home/USER/PortMaster-New-Fork'

"$WIN_GIT" \
  -c safe.directory="$REPO" \
  -c core.autocrlf=false \
  -c core.filemode=false \
  -C "$REPO" \
  fetch --filter=blob:none --depth=1 --no-tags \
  upstream main:refs/remotes/upstream/main

"$WIN_GIT" \
  -c safe.directory="$REPO" \
  -c core.autocrlf=false \
  -c core.filemode=false \
  -C "$REPO" \
  fetch --filter=blob:none --deepen=100 --no-tags upstream main

"$WIN_GIT" \
  -c safe.directory="$REPO" \
  -c core.autocrlf=false \
  -c core.filemode=false \
  -C "$REPO" \
  rebase upstream/main
```

Before rebasing, `git merge-base main upstream/main` must print a commit. If it
does not, deepen the upstream fetch again. Replace `Ubuntu` with the actual WSL
distribution name and `USER` with the WSL username.

### Update the compiled payload and provenance

Use this path when `ports/openchaos/` already exists and the PR updates a newly
compiled executable, its bundled libraries, and the source provenance requested
for those binaries. Do not synchronize the complete generated tree because that
creates unrelated metadata, launcher, screenshot, control, and placeholder
changes.

Set paths for the two repositories:

```sh
OPENCHAOS_REPO=/path/to/OpenChaos
PORTMASTER_REPO=/path/to/PortMaster-New

cd "$PORTMASTER_REPO"
install -m 0755 \
  "$OPENCHAOS_REPO/release/dist/ports/openchaos/openchaos/OpenChaos.aarch64" \
  ports/openchaos/openchaos/OpenChaos.aarch64

rsync -a --delete \
  "$OPENCHAOS_REPO/release/dist/ports/openchaos/openchaos/libs.aarch64/" \
  ports/openchaos/openchaos/libs.aarch64/

install -m 0644 \
  "$OPENCHAOS_REPO/release/dist/ports/openchaos/README.md" \
  ports/openchaos/README.md

install -m 0644 \
  "$OPENCHAOS_REPO/release/dist/ports/openchaos/openchaos/licenses/THIRD-PARTY-NOTICES.txt" \
  ports/openchaos/openchaos/licenses/THIRD-PARTY-NOTICES.txt

install -m 0644 \
  "$OPENCHAOS_REPO/release/dist/ports/openchaos/openchaos/licenses/SDL3-SHIM-PROVENANCE.txt" \
  ports/openchaos/openchaos/licenses/SDL3-SHIM-PROVENANCE.txt

git rm --ignore-unmatch \
  ports/openchaos/openchaos/licenses/alsa-copyright.txt
```

`--delete` removes the old unversioned aliases, fully versioned duplicate files,
and OpenAL Soft 1.25.1 payload. The replacement `libopenal.so.1` contains the
1.24.3 build. The deletion is scoped only to `libs.aarch64/`; do not use it
against the complete port for a binary-only update.

Verify that no packaged library is a symbolic link:

```sh
find ports/openchaos/openchaos/libs.aarch64 -type l -print
```

The command must print nothing. A symlink can be extracted on some firmware as
a tiny regular file containing a target filename, which causes the dynamic
loader to report `file too short`.

Confirm that every changed path is one of these:

```text
ports/openchaos/README.md
ports/openchaos/openchaos/OpenChaos.aarch64
ports/openchaos/openchaos/libs.aarch64/*
ports/openchaos/openchaos/licenses/THIRD-PARTY-NOTICES.txt
ports/openchaos/openchaos/licenses/SDL3-SHIM-PROVENANCE.txt
ports/openchaos/openchaos/licenses/alsa-copyright.txt (removed)
```

Then validate and stage only those paths:

```sh
git status --short
git diff --check
python3 tools/build_release.py --do-check
python3 tools/build_release.py

git add \
  ports/openchaos/README.md \
  ports/openchaos/openchaos/OpenChaos.aarch64 \
  ports/openchaos/openchaos/libs.aarch64 \
  ports/openchaos/openchaos/licenses
git diff --cached --check
git diff --cached --stat
git diff --cached --name-only
```

If metadata, launcher, screenshot, controls, or other port files appear in the
staged list, unstage them and investigate before committing.

Commit and push the binary-only update:

```sh
git commit -m "Update Open Chaos aarch64 build and provenance"
git push -u origin update-openchaos-focal-build
```

### Synchronize the complete generated port

Do not use this path for the current binary-only PR. Use it only when the PR is
intentionally changing the PortMaster metadata or package layout.

Set paths for the two repositories, then synchronize the complete generated
tree. The trailing slashes are significant:

```sh
OPENCHAOS_REPO=/path/to/OpenChaos
PORTMASTER_REPO=/path/to/PortMaster-New

cd "$PORTMASTER_REPO"
rsync -a --delete \
  "$OPENCHAOS_REPO/release/dist/ports/openchaos/" \
  ports/openchaos/
```

This intentionally removes obsolete libraries, including the previous OpenAL
1.25.1 file. Review the deletion list before committing.

### Validate the PortMaster repository

```sh
git status --short
git diff --check
git diff --stat
find ports/openchaos -name .gitkeep -print
find ports/openchaos -type f -size +90M -print
python3 tools/build_release.py --do-check
python3 tools/build_release.py
```

The two `find` commands should print nothing. Test the generated
`releases/openchaos.zip`. If a required file exceeds 90 MB, run
`python3 tools/build_data.py` and review its generated chunks before staging.

Confirm that the final Git diff changes only `ports/openchaos/`:

```sh
git diff --name-only
git diff -- ports/openchaos/port.json \
  ports/openchaos/gameinfo.xml \
  'ports/openchaos/Open Chaos.sh'
```

### Commit and push

```sh
git add ports/openchaos
git diff --cached --check
git diff --cached --stat
git commit -m "Update Open Chaos aarch64 build"
git push -u origin update-openchaos-focal-build
```

Open the pull request against:

- base repository: `PortsMaster/PortMaster-New`;
- base branch: `main`;
- head repository: `jckhng/PortMaster-New`;
- head branch: `update-openchaos-focal-build`.

With GitHub CLI:

```sh
gh pr create \
  --repo PortsMaster/PortMaster-New \
  --base main \
  --head jckhng:update-openchaos-focal-build \
  --title "Update Open Chaos aarch64 build"
```

Use a draft PR until the required firmware and resolution tests are complete.
Do not check an untested platform in the PR template.

Suggested change summary:

```markdown
## Changes

- Replace the Open Chaos aarch64 executable and bundled libraries with the
  Ubuntu 20.04/Focal-compatible build.
- Lower runtime requirements from GLIBC 2.38 / GLIBCXX 3.4.31 to GLIBC 2.29 /
  GLIBCXX 3.4.26.
- Include the explosion particle bounds fix from UltimaBeaR/OpenChaos#7.
- Replace OpenAL Soft 1.25.1 with the GCC 10-compatible 1.24.3 build.
- Update the port to canonical version-4 metadata and current package layout.

Original Urban Chaos data is not included.
```

List every tested firmware, device, and resolution separately. Credit elieder
for reporting the explosion crash. State clearly which results are hardware
tests and which are ABI checks performed in a container.

## Reusable Completion Checklist

- [ ] Reproduction save or minimal test case recorded with SHA-256.
- [ ] Known-bad and fixed builds produced from comparable environments.
- [ ] Root cause demonstrated, not inferred only from symptom disappearance.
- [ ] Test-only cheats, logs, and abandoned fixes removed.
- [ ] Full package rebuilt against the oldest supported userspace baseline.
- [ ] GLIBC and GLIBCXX requirements checked for every shipped ELF.
- [ ] Final package passes ARM64 `ldd` without missing libraries.
- [ ] Firmware-owned SDL2, graphics drivers, and core libraries are excluded.
- [ ] Metadata uses the current PortMaster schema and canonical filenames.
- [ ] Every bundled component has a license.
- [ ] No proprietary game assets are present.
- [ ] PortMaster test matrix is recorded honestly.
- [ ] `tools/build_release.py --do-check` passes.
- [ ] Final commit changes only the intended port directory.
