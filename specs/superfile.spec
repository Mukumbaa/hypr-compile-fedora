%global debug_package %{nil}
%global binary_name spf

Name:           superfile
Version:        %{?module_version}%{!?module_version:1.6.0}
Release:        %{?module_release}%{!?module_release:1%{?dist}}
Summary:        Pretty fancy and modern terminal file manager

License:        MIT
URL:            https://github.com/yorukot/superfile
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

Provides:       %{name} = %{version}-%{release}

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

BuildRequires:  golang
BuildRequires:  git

%description
%{summary}

%prep
%autosetup -c

%build
# Compilazione tramite Go
go build -o %{binary_name}

%install
install -p -D %{binary_name} %{buildroot}%{_bindir}/%{binary_name}

%files
%license LICENSE
%{_bindir}/%{binary_name}

%changelog
* Mon Sep 21 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
