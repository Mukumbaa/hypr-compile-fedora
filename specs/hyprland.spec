Name:           hyprland
Version:        %{?module_version}%{!?module_version:0.56.2}
Release:        %{?module_release}%{!?module_release:1}%{?dist}
Summary:        Dynamic tiling Wayland compositor that doesn't sacrifice on its looks

License:        BSD-3-Clause AND BSD-2-Clause AND HPND-sell-variant AND LGPL-2.1-or-later
URL:            https://github.com/hyprwm/Hyprland
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

BuildRequires:  cmake gcc-c++ meson ninja-build
BuildRequires:  muParser-devel glaze-static
BuildRequires:  pkgconfig(aquamarine) pkgconfig(cairo) pkgconfig(egl) pkgconfig(gbm)
BuildRequires:  pkgconfig(gio-2.0) pkgconfig(glesv2) pkgconfig(glslang) pkgconfig(hwdata)
BuildRequires:  pkgconfig(hyprcursor) pkgconfig(hyprgraphics) pkgconfig(hyprlang)
BuildRequires:  pkgconfig(hyprutils) pkgconfig(hyprwayland-scanner) pkgconfig(hyprwire)
BuildRequires:  pkgconfig(lcms2) pkgconfig(libcanberra) pkgconfig(libdisplay-info)
BuildRequires:  pkgconfig(libdrm) pkgconfig(libeis-1.0) pkgconfig(libinput) >= 1.28
BuildRequires:  pkgconfig(libliftoff) pkgconfig(libseat) pkgconfig(libudev)
BuildRequires:  pkgconfig(lua) pkgconfig(pango) pkgconfig(pangocairo) pkgconfig(pixman-1)
BuildRequires:  pkgconfig(re2) pkgconfig(readline) pkgconfig(sdbus-c++) pkgconfig(systemd)
BuildRequires:  pkgconfig(tomlplusplus) pkgconfig(uuid) pkgconfig(wayland-client)
BuildRequires:  pkgconfig(wayland-protocols) >= 1.45 pkgconfig(wayland-scanner)
BuildRequires:  pkgconfig(wayland-server) pkgconfig(xcb-composite) pkgconfig(xcb-dri3)
BuildRequires:  pkgconfig(xcb-errors) pkgconfig(xcb-ewmh) pkgconfig(xcb-icccm)
BuildRequires:  pkgconfig(xcb-present) pkgconfig(xcb-render) pkgconfig(xcb-renderutil)
BuildRequires:  pkgconfig(xcb-res) pkgconfig(xcb-shm) pkgconfig(xcb-util)
BuildRequires:  pkgconfig(xcb-xfixes) pkgconfig(xcb-xinput) pkgconfig(xcb)
BuildRequires:  pkgconfig(xcursor) pkgconfig(xkbcommon) pkgconfig(xwayland)

Requires:       xorg-x11-server-Xwayland%{?_isa}
Requires:       aquamarine%{?_isa} >= 0.9.2
Requires:       hyprcursor%{?_isa} >= 0.1.13
Requires:       hyprgraphics%{?_isa} >= 0.1.6
Requires:       hyprlang%{?_isa} >= 0.6.3
Requires:       hyprutils%{?_isa} >= 0.8.4

Recommends:     kitty
Recommends:     wofi
Recommends:     polkit
Recommends:     %{name}-uwsm

Provides:       bundled(udis86) = 1.7.2

%description
Hyprland is a dynamic tiling Wayland compositor that doesn't sacrifice
on its looks. It supports multiple layouts, fancy effects, has a
very flexible IPC model allowing for a lot of customization, a powerful
plugin system and more.

%package        uwsm
Summary:        Files for a uwsm-managed session
Requires:       uwsm
BuildArch:      noarch

%description    uwsm
Files for a uwsm-managed session.

%package        devel
Summary:        Header and protocol files for %{name}
License:        BSD-3-Clause
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       cpio git-core pkgconfig(xkbcommon)

%description    devel
Header files and development files for building Hyprland plugins.

%prep
%autosetup -c -n %{name}-%{version} -p1

# Crea i collegamenti di pkg-config per rendere Lua 5.5 visibile a CMake
mkdir -p /usr/share/pkgconfig
cp /usr/share/pkgconfig/lua55.pc /usr/share/pkgconfig/lua.pc 2>/dev/null || true
cp /usr/share/pkgconfig/lua55.pc /usr/share/pkgconfig/lua-5.5.pc 2>/dev/null || true
cp /usr/share/pkgconfig/lua55.pc /usr/share/pkgconfig/lua5.5.pc 2>/dev/null || true

%build
%cmake \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DNO_TESTS=TRUE \
    -DBUILD_TESTING=FALSE
%cmake_build

%install
%cmake_install

# Creazione automatica dell'unità systemd target per la sessione utente se non generata da cmake
mkdir -p %{buildroot}%{_userunitdir}
if [ ! -f "%{buildroot}%{_userunitdir}/hyprland-session.target" ]; then
    cat <<'EOF' > %{buildroot}%{_userunitdir}/hyprland-session.target
[Unit]
Description=Hyprland compositor session
Documentation=man:Hyprland(1)
BindsTo=graphical-session.target
Wants=graphical-session-pre.target
After=graphical-session-pre.target
EOF
fi

%files
%license LICENSE
%{_bindir}/Hyprland
%{_bindir}/hyprland
%{_bindir}/hyprctl
%{_bindir}/hyprpm
%{_bindir}/start-hyprland
%{_datadir}/hypr/
%{_datadir}/wayland-sessions/hyprland.desktop
%{_datadir}/xdg-desktop-portal/hyprland-portals.conf
%{_userunitdir}/hyprland-session.target
%{_mandir}/man1/hyprctl.1*
%{_mandir}/man1/Hyprland.1*
%{_datadir}/bash-completion/completions/hypr*
%{_datadir}/fish/vendor_completions.d/hypr*.fish
%{_datadir}/zsh/site-functions/_hypr*

%files uwsm
%{_datadir}/wayland-sessions/hyprland-uwsm.desktop

%files devel
%{_datadir}/pkgconfig/hyprland.pc
%{_includedir}/hyprland/

%changelog
* Mon Sep 21 2026 builder <builder@localhost> - %{version}-%{release}
- Native build for Fedora
