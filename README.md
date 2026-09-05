# Compile Hyprland on Fedora with Docker

This repository contains a script to automate the compilation of Hyprland on Fedora with Docker.

## Requirements
Create two files:
1) Dockerfile
```
FROM registry.fedoraproject.org/fedora:44

# Update and packages
RUN dnf --refresh upgrade -y && \
    dnf install -y --setopt=install_weak_deps=False \
    gcc-c++ cmake meson ninja-build git tar rpm-build pkgconf-pkg-config \
    make gcc curl createrepo_c \
    cairo-devel pango-devel librsvg2-devel libjpeg-turbo-devel libwebp-devel pixman-devel \
    mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel libspng-devel \
    file-devel libjxl-devel tomlplusplus-devel libzip-devel wayland-devel wayland-protocols-devel \
    libinput-devel libdrm-devel libdisplay-info-devel libseat-devel hwdata-devel libffi-devel \
    pugixml-devel iniparser-devel libxkbcommon-devel libuuid-devel sdbus-cpp-devel pipewire-devel \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtshadertools-devel qt6-qtsvg-devel \
    cli11-devel jemalloc-devel xcb-util-wm-devel xcb-util-renderutil-devel xcb-util-errors-devel \
    xcb-util-keysyms-devel libxcb-devel re2-devel lcms2-devel glslang-devel muParser-devel \
    libeis-devel libcanberra-devel libXcursor-devel glib2-devel systemd-rpm-macros systemd-devel \
    pam-devel scdoc vulkan-headers polkit-devel libunwind-devel libdwarf-devel \
    && dnf clean all

# Lua 5.5 / pkg-config in /usr/share/pkgconfig
RUN curl -L -R -O https://www.lua.org/ftp/lua-5.5.0.tar.gz && \
    tar zxf lua-5.5.0.tar.gz && \
    cd lua-5.5.0 && \
    make linux MYCFLAGS="-fPIC" && \
    make INSTALL_TOP=/usr install && \
    cp /usr/lib/liblua.a /usr/lib64/liblua.a 2>/dev/null || true && \
    mkdir -p /usr/share/pkgconfig && \
    printf '%s\n' \
      'prefix=/usr' \
      'exec_prefix=${prefix}' \
      'libdir=${exec_prefix}/lib64' \
      'includedir=${prefix}/include' \
      '' \
      'Name: Lua' \
      'Description: Lua programming language' \
      'Version: 5.5.0' \
      'Libs: -L${libdir} -llua' \
      'Cflags: -I${includedir}' \
      > /usr/share/pkgconfig/lua55.pc && \
    cd .. && rm -rf lua-5.5.0*

WORKDIR /workspace
RUN mkdir -p /output /root/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

2) entrypoint.sh
```
#!/bin/bash
set -e

REPO_URL="${REPO_URL:-https://github.com/Mukumbaa/hypr-compile-fedora.git}"

if [ -n "$REPO_URL" ]; then
    echo "============================================================"
    echo "--> Repo GitHub: $REPO_URL"
    echo "============================================================"
    rm -rf /workspace/repo
    git clone --depth 1 "$REPO_URL" /workspace/repo
    cd /workspace/repo

    SCRIPT="${SCRIPT_NAME:-script.lua}"
    if [ ! -f "$SCRIPT" ] && [ -f "build.lua" ]; then
        SCRIPT="build.lua"
    fi

    echo "--> Exec: $SCRIPT"
    lua "$SCRIPT"

    if [ -d "/output" ]; then
        echo "============================================================"
        echo "--> METADATA for repository RPM in /output..."
        echo "============================================================"
        createrepo_c /output
        echo "--> Repository generated in /output!"
    else
        echo "[!] WARNING: no /output folder found."
    fi
else
    echo "[!] ERROR: No REPO_URL specified."
    echo "    Usage ex: docker run -e REPO_URL=\"https://github.com/tuo-utente/tua-repo.git\" ..."
    exit 1
fi
```

Then run:
```
docker build -t hypr-builder .
```
and
```
docker run --rm -it -v ${PWD}/hypr_rpms_built:/output hypr-builder
```
