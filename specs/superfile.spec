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

%description
%{summary}

%prep
%autosetup -c

%build

%install
# Adatta il percorso di installazione in base a come viene estratto il tarball nel workspace
if [ -d "dist" ]; then
  install -p -D dist/*/%{binary_name} %{buildroot}%{_bindir}/%{binary_name}
else
  install -p -D %{binary_name} %{buildroot}%{_bindir}/%{binary_name}
fi

%files
%license LICENSE
%{_bindir}/%{binary_name}

%changelog
* Mon Sep 21 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
