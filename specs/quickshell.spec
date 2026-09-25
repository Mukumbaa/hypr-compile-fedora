%bcond_with         asan

Name:               quickshell
Version:            %{?module_version}%{!?module_version:0.3.1}
Release:            %{?module_release}%{!?module_release:1}%{?dist}
Summary:            Flexible QtQuick based desktop shell toolkit

License:            LGPL-3.0-only AND GPL-3.0-only
URL:                https://github.com/quickshell-mirror/quickshell
Source0:            %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

BuildRequires:      breakpad-static
BuildRequires:      cmake
BuildRequires:      cmake(Qt6Core)
BuildRequires:      cmake(Qt6Qml)
BuildRequires:      cmake(Qt6ShaderTools)
BuildRequires:      cmake(Qt6WaylandClient)
BuildRequires:      gcc-c++
BuildRequires:      git
BuildRequires:      ninja-build
BuildRequires:      pkgconfig(breakpad)
BuildRequires:      pkgconfig(CLI11)
BuildRequires:      pkgconfig(gbm)
BuildRequires:      pkgconfig(glib-2.0)
BuildRequires:      pkgconfig(jemalloc)
BuildRequires:      pkgconfig(libdrm)
BuildRequires:      pkgconfig(libpipewire-0.3)
BuildRequires:      pkgconfig(libunwind-generic)
BuildRequires:      pkgconfig(pam)
BuildRequires:      pkgconfig(polkit-agent-1)
BuildRequires:      pkgconfig(wayland-client)
BuildRequires:      pkgconfig(wayland-protocols)
BuildRequires:      qt6-qtbase-private-devel
BuildRequires:      spirv-tools

%if %{with asan}
BuildRequires:      libasan
%endif

Provides:           desktop-notification-daemon
Provides:           bundled(cpptrace) = 1.0.4
Conflicts:          noctalia-qs

%description
Flexible toolkit for making desktop shells with QtQuick, targeting
Wayland and X11.

%prep
%autosetup -c -n %{name}-%{version} -p1

%build
%cmake -GNinja \
%if %{with asan}
        -DASAN=ON \
%endif
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DDISTRIBUTOR="Fedora Native Build" \
        -DDISTRIBUTOR_DEBUGINFO_AVAILABLE=YES \
        -DINSTALL_QML_PREFIX=%{_lib}/qt6/qml \
        -DVENDOR_CPPTRACE=ON
%cmake_build

%install
%cmake_install

# Rimuove in modo robusto tutte le librerie statiche e file di sviluppo terze parti vendored
rm -f %{buildroot}%{_libdir}/*.a
rm -rf %{buildroot}%{_includedir}/*
rm -rf %{buildroot}%{_libdir}/cmake/{cpptrace,libdwarf,zstd} 2>/dev/null || true
rm -rf %{buildroot}%{_libdir}/pkgconfig/{libdwarf,libzstd}*.pc 2>/dev/null || true
rm -rf %{buildroot}%{_datadir}/cpptrace 2>/dev/null || true

%files
%license LICENSE
%license LICENSE-GPL
%doc BUILD.md CONTRIBUTING.md README.md
%{_bindir}/qs
%{_bindir}/quickshell
%{_datadir}/applications/org.quickshell.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.quickshell.svg
%{_libdir}/qt6/qml/Quickshell

%changelog
* Mon Sep 21 2026 builder <builder@localhost> - %{version}-%{release}
- Native build for Fedora
