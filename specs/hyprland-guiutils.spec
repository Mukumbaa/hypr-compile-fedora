Name:           hyprland-guiutils
Version:        %{?module_version}%{!?module_version:0.2.2}
Release:        %{?module_release}%{!?module_release:1}%{?dist}
Summary:        Hyprland Qt/qml utility apps
License:        BSD-3-Clause
URL:            https://github.com/hyprwm/hyprland-guiutils
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

Provides:       %{name} = %{version}-%{release}

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  git
BuildRequires:  pkgconfig(hyprlang)
BuildRequires:  pkgconfig(hyprtoolkit)
BuildRequires:  pkgconfig(pixman-1)
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  pkgconfig(hyprutils)
BuildRequires:  pkgconfig(xkbcommon)

Obsoletes:      hyprland-qtutils <= 0.1.5

%description
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
%{_bindir}/hyprland-dialog
%{_bindir}/hyprland-donate-screen
%{_bindir}/hyprland-run
%{_bindir}/hyprland-update-screen
%{_bindir}/hyprland-welcome

%changelog
* Mon Sep 21 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
