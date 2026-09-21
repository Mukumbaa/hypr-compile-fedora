Name:           hyprland-protocols
Version:        %{?module_version}%{!?module_version:0.7.0}
Release:        %{?module_release}%{!?module_release:1%{?dist}}
Summary:        Wayland protocol extensions for Hyprland
BuildArch:      noarch

License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-protocols
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

Provides:       %{name} = %{version}-%{release}

BuildRequires:  cmake
BuildRequires:  gcc-c++

%description
%{summary}.

%package        devel
Summary:        Development files for %{name}
Requires:       %{name} = %{version}-%{release}
Provides:       %{name}-devel = %{version}-%{release}

%description    devel
%{summary}.

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

%files devel
%{_datadir}/pkgconfig/%{name}.pc
%{_datadir}/%{name}/

%changelog
* Mon Sep 21 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
