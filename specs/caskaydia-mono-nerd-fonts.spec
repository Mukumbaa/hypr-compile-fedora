Name:           caskaydia-mono-nerd-fonts
Version:        3.3.0
Release:        %{?module_version}%{!?module_version:1%{?dist}}
Summary:        CaskaydiaMono Nerd Font (Cascadia Mono with patched glyphs)

License:        MIT
URL:            https://github.com/ryanoasis/nerd-fonts
# Prende direttamente lo zip scaricato in SOURCES
Source0:        CascadiaMono.zip

BuildArch:      noarch
BuildRequires:  unzip

Provides:       %{name} = %{version}-%{release}

# https://fedoraproject.org/wiki/Changes/EncourageI686LeafRemoval
ExcludeArch:    %{ix86}

%description
CaskaydiaMono Nerd Font is the patched version of Microsoft's Cascadia Mono font, 
containing a high number of glyphs (icons) for developer tools.

%prep
# Crea la cartella ed estrae lo zip direttamente qui dentro
%setup -c

%build
# I font non richiedono compilazione

%install
rm -rf %{buildroot}
install -m 0755 -d %{buildroot}%{_datadir}/fonts/caskaydia-mono
# Copia tutti i file ttf e otf trovati nella cartella estratta
find . -name "*.ttf" -exec cp -f {} %{buildroot}%{_datadir}/fonts/caskaydia-mono/ \;
find . -name "*.otf" -exec cp -f {} %{buildroot}%{_datadir}/fonts/caskaydia-mono/ \;

%files
%{_datadir}/fonts/caskaydia-mono/

%changelog
* Tue Sep 22 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build
