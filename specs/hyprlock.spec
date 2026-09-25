%global sdbus_version 2.3.1

Name:           hyprlock
Version:        %{?module_version}%{!?module_version:0.9.6}
Release:        %{?module_release}%{!?module_release:1}%{?dist}
Summary:        Hyprland's GPU-accelerated screen locking utility
License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprlock
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

Provides:       %{name} = %{version}-%{release}

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  curl

BuildRequires:  cmake(hyprwayland-scanner)
BuildRequires:  pkgconfig(cairo)
BuildRequires:  pkgconfig(egl)
BuildRequires:  pkgconfig(gbm)
BuildRequires:  pkgconfig(hyprgraphics)
BuildRequires:  pkgconfig(hyprlang)
BuildRequires:  pkgconfig(hyprutils)
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  pkgconfig(libsystemd)
BuildRequires:  pkgconfig(opengl)
BuildRequires:  pkgconfig(pam)
BuildRequires:  pkgconfig(pangocairo)
BuildRequires:  pkgconfig(systemd)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  pkgconfig(wayland-egl)
BuildRequires:  pkgconfig(wayland-protocols)
BuildRequires:  pkgconfig(xkbcommon)
BuildRequires:  pkgconfig(sdbus-cpp-devel)

Provides:       bundled(sdbus-cpp) = %{sdbus_version}

%description
%{summary}.

%prep
%autosetup -c -p1
# mkdir -p subprojects/sdbus-cpp
# curl -L https://github.com/Kistler-Group/sdbus-cpp/archive/v%{sdbus_version}/sdbus-%{sdbus_version}.tar.gz -o /tmp/sdbus.tar.gz
# tar -xf /tmp/sdbus.tar.gz -C subprojects/sdbus-cpp --strip=1
# rm -f /tmp/sdbus.tar.gz

# %build
# pushd subprojects/sdbus-cpp
# %cmake \
#     -DCMAKE_INSTALL_PREFIX=%{_builddir}/sdbus \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DSDBUSCPP_BUILD_DOCS=OFF \
#     -DBUILD_SHARED_LIBS=OFF
# %cmake_build
# cmake --install %{_vpath_builddir}
# popd
# export PKG_CONFIG_PATH=%{_builddir}/sdbus/%{_lib}/pkgconfig
#
# %cmake -DCMAKE_BUILD_TYPE=Release
# %cmake_build
%build
%cmake -DCMAKE_BUILD_TYPE=Release
%cmake_build
%install
%cmake_install
[ -f %{buildroot}%{_datadir}/hypr/%{name}.conf ] && rm %{buildroot}%{_datadir}/hypr/%{name}.conf || true

%files
%license LICENSE
%doc README.md assets/example.conf
%{_bindir}/%{name}
%config(noreplace) %{_sysconfdir}/pam.d/%{name}

%changelog
* Tue Sep 22 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
