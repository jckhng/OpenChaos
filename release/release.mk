RELEASE_DIR := release
DIST_DIR    := $(RELEASE_DIR)/dist
PORTMASTER_ASSETS := $(RELEASE_DIR)/assets/portmaster
PORTMASTER_BUILD_DIR ?= $(SRC_DIR)/build-portmaster
PORTMASTER_BINARY ?= $(PORTMASTER_BUILD_DIR)/Release/OpenChaos.aarch64
PORTMASTER_TOOLCHAIN ?= $(abspath $(SRC_DIR)/cmake/gcc-aarch64-linux.cmake)
PORTMASTER_OVERLAY_TRIPLETS ?= $(abspath $(SRC_DIR)/cmake/vcpkg-triplets)
PORTMASTER_TRIPLET ?= openchaos-gcc-arm64-linux
PORTMASTER_LIB_DIR ?= $(SRC_DIR)/vcpkg_installed/$(PORTMASTER_TRIPLET)/lib
PORTMASTER_EXTRA_LIB_DIRS ?=
PORTMASTER_GAME_ASSETS ?=
PORTMASTER_EXTRA_LICENSE_FILES ?=
PORTMASTER_EXTRA_CMAKE_ARGS ?=
PORTMASTER_VCPKG_MANIFEST_NO_DEFAULT_FEATURES ?= OFF

ifeq ($(UNAME_S),Darwin)
    ifeq ($(UNAME_M),arm64)
        PLATFORM := macos-arm64
    else
        PLATFORM := macos-x64
    endif
    RELEASE_ASSETS := $(RELEASE_DIR)/assets/macos-arm64
else ifeq ($(UNAME_S),Linux)
    PLATFORM := linux-x64
    RELEASE_ASSETS := $(RELEASE_DIR)/assets/linux-x64
else
    PLATFORM := windows-x64
    RELEASE_ASSETS := $(RELEASE_DIR)/assets/windows-x64
endif

# Windows builds use the x64-windows-static vcpkg triplet, so all libraries are
# linked into OpenChaos.exe — there are no DLLs to ship alongside it.

# Usage: make release-package VERSION=0.1.0
# Output: release/dist/OpenChaos-v<VERSION>-<platform>.zip
# Requires: make configure && make build-release (run beforehand)
release-package:
ifndef VERSION
	$(error Usage: make release-package VERSION=0.1.0)
endif
	@if [ ! -f "$(BUILD_DIR)/Release/$(EXE_NAME)" ]; then \
	  echo "ERROR: Release build not found. Run 'make build-release' first." >&2; \
	  exit 1; \
	fi
	@rm -rf "$(DIST_DIR)"
	@ARCHIVE="OpenChaos-v$(VERSION)-$(PLATFORM)"; \
	STAGING="$(DIST_DIR)/$$ARCHIVE"; \
	mkdir -p "$$STAGING"; \
	echo "Packaging $$ARCHIVE..."; \
	cp "$(BUILD_DIR)/Release/$(EXE_NAME)" "$$STAGING/"; \
	sed 's/{{VERSION}}/$(VERSION)/g' "$(RELEASE_ASSETS)/README.txt" > "$$STAGING/OpenChaos-readme.txt"; \
	for extra in "$(RELEASE_ASSETS)"/*.command "$(RELEASE_ASSETS)"/*.sh; do \
	  [ -f "$$extra" ] && cp "$$extra" "$$STAGING/"; \
	done; \
	if [ "$(PLATFORM)" = "windows-x64" ]; then \
	  powershell -NoProfile -Command "Compress-Archive -Path '$(DIST_DIR)/$$ARCHIVE' -DestinationPath '$(DIST_DIR)/$$ARCHIVE.zip' -Force" && rm -rf "$(DIST_DIR)/$$ARCHIVE"; \
	else \
	  cd "$(DIST_DIR)" && zip -r "$$ARCHIVE.zip" "$$ARCHIVE" && rm -rf "$$ARCHIVE"; \
	fi; \
	echo ""; \
	echo "Done: $(DIST_DIR)/$$ARCHIVE.zip"

# Usage:
#   make release-package-portmaster VERSION=0.1.0 PORTMASTER_BINARY=/path/to/OpenChaos.aarch64
#
# Output:
#   release/dist/OpenChaos-v<VERSION>-portmaster-aarch64.zip
#
# The aarch64 binary must be built separately with a PortMaster-compatible
# toolchain. The package target only stages the PortMaster layout and metadata.
.PHONY: release-package-portmaster
release-package-portmaster:
ifndef VERSION
	$(error Usage: make release-package-portmaster VERSION=0.1.0 PORTMASTER_BINARY=/path/to/OpenChaos.aarch64)
endif
	@if [ ! -f "$(PORTMASTER_BINARY)" ]; then \
	  echo "ERROR: PortMaster aarch64 binary not found: $(PORTMASTER_BINARY)" >&2; \
	  echo "Usage: make release-package-portmaster VERSION=$(VERSION) PORTMASTER_BINARY=/path/to/OpenChaos.aarch64" >&2; \
	  exit 1; \
	fi
	@rm -rf "$(DIST_DIR)/OpenChaos-v$(VERSION)-portmaster-aarch64"
	@mkdir -p "$(DIST_DIR)"
	@ARCHIVE="OpenChaos-v$(VERSION)-portmaster-aarch64"; \
	STAGING="$(DIST_DIR)/$$ARCHIVE"; \
	mkdir -p "$$STAGING"; \
	echo "Packaging $$ARCHIVE..."; \
	cp -R "$(PORTMASTER_ASSETS)/." "$$STAGING/"; \
	mkdir -p "$$STAGING/openchaos/licenses"; \
	if [ -f "LICENSE" ]; then \
	  cp "LICENSE" "$$STAGING/openchaos/licenses/OpenChaos-LICENSE.txt"; \
	fi; \
	if [ -d "$(SRC_DIR)/vcpkg_installed/$(PORTMASTER_TRIPLET)/share" ]; then \
	  for copyright in "$(SRC_DIR)/vcpkg_installed/$(PORTMASTER_TRIPLET)/share"/*/copyright; do \
	    [ -f "$$copyright" ] || continue; \
	    package="$$(basename "$$(dirname "$$copyright")")"; \
	    cp "$$copyright" "$$STAGING/openchaos/licenses/$$package-copyright.txt"; \
	  done; \
	fi; \
	for license_file in $(PORTMASTER_EXTRA_LICENSE_FILES); do \
	  if [ -f "$$license_file" ]; then \
	    license_dir="$$(basename "$$(dirname "$$license_file")")"; \
	    cp "$$license_file" "$$STAGING/openchaos/licenses/$$license_dir-$$(basename "$$license_file")"; \
	  fi; \
	done; \
	cp "$(PORTMASTER_BINARY)" "$$STAGING/openchaos/OpenChaos.aarch64"; \
		if [ -d "$(PORTMASTER_LIB_DIR)" ]; then \
		  find "$(PORTMASTER_LIB_DIR)" -maxdepth 1 \( -type f -o -type l \) -name "*.so*" -exec cp -P {} "$$STAGING/openchaos/libs.aarch64/" \; ; \
		fi; \
		for libdir in $(PORTMASTER_EXTRA_LIB_DIRS); do \
		  if [ -d "$$libdir" ]; then \
		    find "$$libdir" -maxdepth 1 \( -type f -o -type l \) -name "*.so*" -exec cp -P {} "$$STAGING/openchaos/libs.aarch64/" \; ; \
		  fi; \
		done; \
		if [ -n "$(PORTMASTER_GAME_ASSETS)" ]; then \
		  if [ ! -d "$(PORTMASTER_GAME_ASSETS)" ]; then \
	    echo "ERROR: PORTMASTER_GAME_ASSETS directory not found: $(PORTMASTER_GAME_ASSETS)" >&2; \
	    exit 1; \
	  fi; \
	  cp -R "$(PORTMASTER_GAME_ASSETS)/." "$$STAGING/openchaos/assets/"; \
	fi; \
		chmod +x "$$STAGING/openchaos.sh" "$$STAGING/openchaos/OpenChaos.aarch64"; \
		rm -f "$(DIST_DIR)/$$ARCHIVE.zip"; \
		cd "$$STAGING" && zip -r "../$$ARCHIVE.zip" openchaos.sh openchaos && rm -rf "../$$ARCHIVE"; \
	echo ""; \
	echo "Done: $(DIST_DIR)/$$ARCHIVE.zip"

# Configure/build helper for the PortMaster aarch64 binary. This still depends
# on a working vcpkg install and target-compatible dependencies.
.PHONY: configure-portmaster build-portmaster
configure-portmaster:
	$(CMAKE) -S $(SRC_DIR) -B $(PORTMASTER_BUILD_DIR) -G "Ninja Multi-Config" \
	  "-DCMAKE_TOOLCHAIN_FILE=$(VCPKG_CMAKE)" \
	  "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$(PORTMASTER_TOOLCHAIN)" \
	  "-DVCPKG_TARGET_TRIPLET=$(PORTMASTER_TRIPLET)" \
	  "-DVCPKG_OVERLAY_TRIPLETS=$(PORTMASTER_OVERLAY_TRIPLETS)" \
	  "-DVCPKG_INSTALLED_DIR=$(abspath $(SRC_DIR)/vcpkg_installed)" \
	  "-DVCPKG_MANIFEST_NO_DEFAULT_FEATURES=$(PORTMASTER_VCPKG_MANIFEST_NO_DEFAULT_FEATURES)" \
	  "-DCMAKE_MAKE_PROGRAM=$(shell which ninja)" \
	  "-DENABLE_ASAN=OFF" \
	  "-DDEAD_CODE_REPORT=OFF" \
	  $(PORTMASTER_EXTRA_CMAKE_ARGS)

build-portmaster:
	@if [ ! -d "$(PORTMASTER_BUILD_DIR)" ]; then \
	  echo "ERROR: PortMaster build directory not found. Run 'make configure-portmaster' first." >&2; \
	  exit 1; \
	fi
	$(CMAKE) --build $(PORTMASTER_BUILD_DIR) --config Release --target OpenChaos
	@cp "$(PORTMASTER_BUILD_DIR)/Release/OpenChaos" "$(PORTMASTER_BUILD_DIR)/Release/OpenChaos.aarch64"
