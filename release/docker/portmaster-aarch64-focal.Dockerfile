FROM ubuntu:20.04@sha256:8feb4d8ca5354def3d8fce243717141ce31e2c428701f6682bd2fafe15388214

ARG DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture arm64 \
    && sed -i -e 's|deb http://archive.ubuntu.com/ubuntu/ focal|deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal|g' \
              -e 's|deb http://security.ubuntu.com/ubuntu/ focal|deb [arch=amd64] http://security.ubuntu.com/ubuntu/ focal|g' \
              /etc/apt/sources.list \
    && printf '%s\n' \
        'deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ focal main restricted universe multiverse' \
        'deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ focal-updates main restricted universe multiverse' \
        'deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ focal-security main restricted universe multiverse' \
        > /etc/apt/sources.list.d/arm64.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        file \
        g++ \
        gcc \
        git \
        make \
        ninja-build \
        patch \
        pkg-config \
        python3 \
        python3-pip \
        unzip \
        xz-utils \
        zip \
        g++-10-aarch64-linux-gnu \
        gcc-10-aarch64-linux-gnu \
        libc6-dev-arm64-cross \
        libasound2-dev:arm64 \
        libdbus-1-dev:arm64 \
        libdrm-dev:arm64 \
        libegl-dev:arm64 \
        libgbm-dev:arm64 \
        libgles-dev:arm64 \
        libpulse-dev:arm64 \
        libudev-dev:arm64 \
        libwayland-dev:arm64 \
        libx11-dev:arm64 \
        libxcursor-dev:arm64 \
        libxext-dev:arm64 \
        libxfixes-dev:arm64 \
        libxi-dev:arm64 \
        libxinerama-dev:arm64 \
        libxkbcommon-dev:arm64 \
        libxrandr-dev:arm64 \
        zlib1g-dev:arm64 \
    && python3 -m pip install --no-cache-dir "cmake>=3.25,<3.28" \
    && ln -sf /usr/bin/aarch64-linux-gnu-gcc-10 /usr/local/bin/aarch64-linux-gnu-gcc \
    && ln -sf /usr/bin/aarch64-linux-gnu-g++-10 /usr/local/bin/aarch64-linux-gnu-g++ \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends autoconf automake libtool \
    && rm -rf /var/lib/apt/lists/*

COPY release/portmaster-dependencies.lock /tmp/portmaster-dependencies.lock

RUN . /tmp/portmaster-dependencies.lock \
    && mkdir -p /opt/vcpkg \
    && git -C /opt/vcpkg init \
    && git -C /opt/vcpkg remote add origin "$VCPKG_REPOSITORY_URL" \
    && git -C /opt/vcpkg fetch origin "$VCPKG_COMMIT" \
    && git -C /opt/vcpkg checkout --detach "$VCPKG_COMMIT" \
    && test "$(git -C /opt/vcpkg rev-parse HEAD)" = "$VCPKG_COMMIT" \
    && /opt/vcpkg/bootstrap-vcpkg.sh -disableMetrics

ENV VCPKG_ROOT=/opt/vcpkg
ENV PATH=/usr/local/bin:/usr/bin:/bin
ENV PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
ENV PKG_CONFIG_SYSROOT_DIR=/

WORKDIR /workspace

CMD ["bash", "release/scripts/build-portmaster-aarch64.sh"]
