%global debug_package %{nil}

Name:           glaze
Version:        %{?module_version}%{!?module_version:8.4.0}
Release:        %{?module_release}%{!?module_release:1}%{?dist}
Summary:        Extremely fast, in memory, JSON and interface library

License:        MIT
URL:            https://github.com/stephenberry/glaze
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

BuildRequires:  cmake
BuildRequires:  gcc-c++

%description
%{summary}.

%package        devel
Summary:        Development files for %{name}
BuildArch:      noarch
Provides:       %{name}-static = %{version}-%{release}

%description    devel
Development files for %{name}.

%prep
# Usiamo -c perché il tarball viene generato al volo dal clone git dello script Lua
%autosetup -c -p1

%build
%cmake \
    -Dglaze_INSTALL_CMAKEDIR=%{_libdir}/cmake/%{name} \
    -Dglaze_DISABLE_SIMD_WHEN_SUPPORTED:BOOL=ON \
    -Dglaze_DEVELOPER_MODE:BOOL=OFF \
    -Dglaze_ENABLE_FUZZING:BOOL=OFF
%cmake_build

%install
%cmake_install

%files devel
%license LICENSE
%doc README.md
%{_libdir}/cmake/%{name}/
%{_includedir}/%{name}/

%changelog
* Wed Sep 24 2026 builder  - %{version}-%{release}
- Native Build for Fedora
