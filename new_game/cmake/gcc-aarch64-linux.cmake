# Toolchain: GNU cross compiler targeting aarch64 Linux.
# Intended for container builds with g++-aarch64-linux-gnu installed.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

set(VCPKG_TARGET_TRIPLET "openchaos-gcc-arm64-linux" CACHE STRING "")

# DBus cannot infer this path while cross-compiling. SDL3's Linux feature graph
# can pull DBus in through vcpkg, so provide the conventional runtime location.
set(DBUS_SESSION_SOCKET_DIR "/tmp" CACHE STRING "")
