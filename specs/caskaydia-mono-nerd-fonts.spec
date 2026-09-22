%global debug_package %{nil}

Name:           caskaydia-mono-nerd-fonts
Version:        3.3.0
Release:        %{?module_release}%{!?module_release:1%{?dist}}
Summary:        CaskaydiaMono Nerd Font (Cascadia Mono with patched glyphs)

License:        MIT
URL:            https://github.com/ryanoasis/nerd-fonts
Source0:        %{?source_tarball}%{!?source_tarball:CascadiaMono.zip}

BuildArch:      noarch
BuildRequires:  unzip

Provides:       %{name} = %{version}-%{release}

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

%description
CaskaydiaMono Nerd Font is the patched version of Microsoft's Cascadia Mono font, 
containing a high number of glyphs (icons) for developer tools.

%prep
%autosetup -c

%build
# I font non richiedono compilazione

%install
install -m 0755 -d %{buildroot}%{_datadir}/fonts/caskaydia-mono
install -m 0644 *.ttf %{buildroot}%{_datadir}/fonts/caskaydia-mono/ 2>/dev/null || true
install -m 0644 *.otf %{buildroot}%{_datadir}/fonts/caskaydia-mono/ 2>/dev/null || true

%files
%{_datadir}/fonts/caskaydia-mono/

%changelog
* Tue Sep 22 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
