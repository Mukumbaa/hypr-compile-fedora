Name:           hyprutils
Version:        %{?module_version}%{!?module_version:0.14.2}
Release:        %{?module_release}%{!?module_release:1%{?dist}}
Summary:        Hyprland utilities library used across the ecosystem

License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprutils
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

Provides:       %{name} = %{version}-%{release}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  pkgconfig(pixman-1)

%description
Hyprland utilities library used across the ecosystem.

%package        devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}
Provides:       %{name}-devel = %{version}-%{release}

%description    devel
Development files for %{name}.

%prep
%autosetup -c

%build
%cmake
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_libdir}/lib%{name}.so.*

%files devel
%{_includedir}/%{name}/
%{_libdir}/lib%{name}.so
%{_libdir}/pkgconfig/%{name}.pc

%changelog
* Mon Sep 21 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
