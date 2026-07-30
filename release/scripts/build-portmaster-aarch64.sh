#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK_FILE="$ROOT_DIR/release/portmaster-dependencies.lock"

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "ERROR: Dependency lock not found: $LOCK_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$LOCK_FILE"

: "${BMDHACKS_SDL_REPOSITORY_URL:?Missing shim repository URL}"
: "${BMDHACKS_SDL_BRANCH:?Missing shim branch}"
: "${BMDHACKS_SDL_COMMIT:?Missing shim commit}"
: "${VCPKG_ROOT:?Set VCPKG_ROOT to the pinned vcpkg checkout}"
: "${VCPKG_REPOSITORY_URL:?Missing vcpkg repository URL}"
: "${VCPKG_COMMIT:?Missing vcpkg commit}"

VERSION="${VERSION:-dev}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/new_game/build-portmaster-focal-reproducible}"
DEPS_DIR="${DEPS_DIR:-$ROOT_DIR/new_game/build-portmaster-deps}"
SHIM_DIR="$DEPS_DIR/bmdhacks-SDL"
CLEAN_BUILD="${CLEAN_BUILD:-1}"

for command in git; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $command" >&2
    exit 1
  fi
done

mkdir -p "$DEPS_DIR"

if [[ ! -d "$SHIM_DIR/.git" ]]; then
  mkdir -p "$SHIM_DIR"
  git -C "$SHIM_DIR" init -q
  git -C "$SHIM_DIR" remote add origin "$BMDHACKS_SDL_REPOSITORY_URL"
fi

actual_remote="$(git -C "$SHIM_DIR" remote get-url origin)"
if [[ "$actual_remote" != "$BMDHACKS_SDL_REPOSITORY_URL" ]]; then
  echo "ERROR: Unexpected shim origin: $actual_remote" >&2
  exit 1
fi

if ! git -C "$SHIM_DIR" cat-file -e "$BMDHACKS_SDL_COMMIT^{commit}" 2>/dev/null; then
  git -C "$SHIM_DIR" fetch --depth=1 origin "$BMDHACKS_SDL_COMMIT"
fi

git -C "$SHIM_DIR" checkout --detach "$BMDHACKS_SDL_COMMIT"

actual_commit="$(git -C "$SHIM_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$BMDHACKS_SDL_COMMIT" ]]; then
  echo "ERROR: Shim checkout mismatch: $actual_commit" >&2
  exit 1
fi

if [[ -n "$(git -C "$SHIM_DIR" status --porcelain)" ]]; then
  echo "ERROR: Shim checkout is dirty: $SHIM_DIR" >&2
  exit 1
fi

printf '%s\n' \
  "SDL3 shim repository: $BMDHACKS_SDL_REPOSITORY_URL" \
  "SDL3 shim branch: $BMDHACKS_SDL_BRANCH" \
  "SDL3 shim commit: $actual_commit"

if [[ "${CHECKOUT_ONLY:-0}" == "1" ]]; then
  exit 0
fi

if [[ ! -d "$VCPKG_ROOT/.git" ]]; then
  echo "ERROR: VCPKG_ROOT is not a Git checkout: $VCPKG_ROOT" >&2
  exit 1
fi

actual_vcpkg_remote="$(git -C "$VCPKG_ROOT" remote get-url origin)"
actual_vcpkg_commit="$(git -C "$VCPKG_ROOT" rev-parse HEAD)"

if [[ "$actual_vcpkg_remote" != "$VCPKG_REPOSITORY_URL" ]]; then
  echo "ERROR: Unexpected vcpkg origin: $actual_vcpkg_remote" >&2
  exit 1
fi

if [[ "$actual_vcpkg_commit" != "$VCPKG_COMMIT" ]]; then
  echo "ERROR: vcpkg checkout mismatch: $actual_vcpkg_commit" >&2
  exit 1
fi

for command in cmake ninja aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ readelf file; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $command" >&2
    exit 1
  fi
done

if [[ "$CLEAN_BUILD" == "1" ]]; then
  cmake -E remove_directory "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
export VCPKG_DOWNLOADS="${VCPKG_DOWNLOADS:-$ROOT_DIR/new_game/build-portmaster-vcpkg-downloads}"
mkdir -p "$VCPKG_DOWNLOADS"

cmake \
  -S "$ROOT_DIR/new_game" \
  -B "$BUILD_DIR" \
  -G "Ninja Multi-Config" \
  "-DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$ROOT_DIR/new_game/cmake/gcc-aarch64-linux.cmake" \
  "-DVCPKG_TARGET_TRIPLET=openchaos-gcc-arm64-linux" \
  "-DVCPKG_OVERLAY_TRIPLETS=$ROOT_DIR/new_game/cmake/vcpkg-triplets" \
  "-DVCPKG_INSTALLED_DIR=$BUILD_DIR/vcpkg_installed" \
  -DVCPKG_MANIFEST_NO_DEFAULT_FEATURES=ON \
  -DOPENCHAOS_GLES=ON \
  "-DOPENCHAOS_SDL3_SOURCE_DIR=$SHIM_DIR" \
  -DSDL_SDL2_BACKEND=ON \
  -DSDL_UNIX_CONSOLE_BUILD=ON \
  -DSDL_GPU=OFF \
  -DSDL_KMSDRM=OFF \
  -DSDL_WAYLAND=OFF \
  -DSDL_X11=OFF \
  -DSDL_ALSA=OFF \
  -DSDL_PIPEWIRE=OFF \
  -DSDL_PULSEAUDIO=OFF \
  -DSDL_OSS=OFF \
  -DSDL_JACK=OFF \
  -DSDL_HIDAPI_JOYSTICK=OFF \
  -DENABLE_ASAN=OFF \
  -DDEAD_CODE_REPORT=OFF

cmake --build "$BUILD_DIR" --config Release --target OpenChaos

grep -Fqx "OPENCHAOS_SDL3_SOURCE_DIR:PATH=$SHIM_DIR" "$BUILD_DIR/CMakeCache.txt"
grep -Fqx "SDL_SDL2_BACKEND:BOOL=ON" "$BUILD_DIR/CMakeCache.txt"

SDL3_LIBRARY="$BUILD_DIR/sdl3_source_build/Release/libSDL3.so.0"
OPENCHAOS_BINARY="$BUILD_DIR/Release/OpenChaos"

if [[ ! -e "$SDL3_LIBRARY" || ! -f "$OPENCHAOS_BINARY" ]]; then
  echo "ERROR: Expected build outputs were not produced." >&2
  exit 1
fi

readelf -d "$SDL3_LIBRARY" | grep -Fq "Library soname: [libSDL3.so.0]"

PROVENANCE_FILE="$BUILD_DIR/portmaster-build-provenance.txt"
openchaos_commit="$(
  git --git-dir="$ROOT_DIR/.git" rev-parse HEAD
)"
{
  printf 'SDL3 shim repository: %s\n' "$BMDHACKS_SDL_REPOSITORY_URL"
  printf 'SDL3 shim branch: %s\n' "$BMDHACKS_SDL_BRANCH"
  printf 'SDL3 shim commit: %s\n' "$actual_commit"
  printf 'SDL3 shim library SHA-256: '
  sha256sum "$SDL3_LIBRARY" | awk '{print $1}'
  printf 'vcpkg repository: %s\n' "$VCPKG_REPOSITORY_URL"
  printf 'vcpkg commit: %s\n' "$actual_vcpkg_commit"
  printf 'OpenChaos commit: %s\n' "$openchaos_commit"
  printf 'OpenChaos binary SHA-256: '
  sha256sum "$OPENCHAOS_BINARY" | awk '{print $1}'
} > "$PROVENANCE_FILE"

make -C "$ROOT_DIR" release-package-portmaster \
  "VERSION=$VERSION" \
  "PORTMASTER_BINARY=$OPENCHAOS_BINARY" \
  "PORTMASTER_LIB_DIR=$BUILD_DIR/vcpkg_installed/openchaos-gcc-arm64-linux/lib" \
  "PORTMASTER_EXTRA_LIB_DIRS=$BUILD_DIR/sdl3_source_build/Release"

STAGED_LIB_DIR="$ROOT_DIR/release/dist/ports/openchaos/openchaos/libs.aarch64"
EXPECTED_SONAMES=(
  libSDL3.so.0
  libavcodec.so.62
  libavformat.so.62
  libavutil.so.60
  libfmt.so.12
  libopenal.so.1
  libswresample.so.6
  libswscale.so.9
)

mapfile -t ACTUAL_SONAMES < <(
  find "$STAGED_LIB_DIR" -maxdepth 1 -type f -printf '%f\n' | sort
)

if [[ "${ACTUAL_SONAMES[*]}" != "${EXPECTED_SONAMES[*]}" ]]; then
  echo "ERROR: Packaged SONAME set does not match the lock." >&2
  printf 'Expected: %s\n' "${EXPECTED_SONAMES[*]}" >&2
  printf 'Actual:   %s\n' "${ACTUAL_SONAMES[*]}" >&2
  exit 1
fi

if find "$STAGED_LIB_DIR" -type l -print -quit | grep -q .; then
  echo "ERROR: Packaged library aliases must not be symlinks." >&2
  exit 1
fi

for library in "$STAGED_LIB_DIR"/*; do
  file "$library" | grep -q "ELF 64-bit"
  soname="$(
    readelf -d "$library" \
      | sed -n 's/.*Library soname: \[\(.*\)\]/\1/p'
  )"
  if [[ "$soname" != "$(basename "$library")" ]]; then
    echo "ERROR: Library filename does not match its SONAME: $library ($soname)" >&2
    exit 1
  fi
done

cmp "$SDL3_LIBRARY" "$STAGED_LIB_DIR/libSDL3.so.0"

declare -A SYSTEM_SONAMES=(
  [ld-linux-aarch64.so.1]=1
  [libc.so.6]=1
  [libdl.so.2]=1
  [libgcc_s.so.1]=1
  [libm.so.6]=1
  [libpthread.so.0]=1
  [libstdc++.so.6]=1
)

STAGED_BINARY="$ROOT_DIR/release/dist/ports/openchaos/openchaos/OpenChaos.aarch64"
for elf in "$STAGED_BINARY" "$STAGED_LIB_DIR"/*; do
  while IFS= read -r needed; do
    if [[ -f "$STAGED_LIB_DIR/$needed" || -n "${SYSTEM_SONAMES[$needed]:-}" ]]; then
      continue
    fi
    echo "ERROR: Unresolved packaged dependency: $needed (required by $elf)" >&2
    exit 1
  done < <(
    readelf -d "$elf" \
      | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'
  )
done

echo "Build provenance: $PROVENANCE_FILE"
echo "PR tree: $ROOT_DIR/release/dist/ports/openchaos"
echo "Archive: $ROOT_DIR/release/dist/OpenChaos-v$VERSION-portmaster-aarch64.zip"
