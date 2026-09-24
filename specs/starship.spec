%global debug_package %{nil}

Name:           starship
Version:        %{?module_version}%{!?module_version:1.26.0}
Release:        %{?module_release}%{!?module_release:1}%{?dist}
Summary:        The minimal, blazing-fast, and infinitely customizable prompt for any shell

License:        ISC
URL:            https://github.com/starship/starship
# Evitiamo di dipendere dal tarball generato da lua, scarichiamo direttamente l'archivio ufficiale di starship
Source0:        https://github.com/starship/starship/releases/download/v%{version}/starship-x86_64-unknown-linux-gnu.tar.gz
Source1:        https://raw.githubusercontent.com/starship/starship/v%{version}/docs/config/README.md

Provides:       %{name} = %{version}-%{release}

BuildRequires:  curl

%description
The minimal, blazing-fast, and infinitely customizable prompt for any shell!

%prep
# Estrae l'archivio binario ufficiale direttamente nella cartella di build
%setup -q -c -n %{name}-%{version}
cp %{SOURCE1} CONFIGURATION.md

%build
# Ora l'eseguibile 'starship' è presente nella cartella estratta
./starship completions bash > starship.bash
./starship completions zsh > _starship

%install
install -p -D starship %{buildroot}%{_bindir}/starship

# Shell completions
install -pvD -m 0644 starship.bash %{buildroot}%{bash_completions_dir}/starship
install -pvD -m 0644 _starship %{buildroot}%{zsh_completions_dir}/_starship

%files
%doc CONFIGURATION.md
%{_bindir}/starship
%{bash_completions_dir}/starship
%{zsh_completions_dir}/_starship

%check
%{buildroot}%{_bindir}/starship --version

%changelog
* Wed Sep 24 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build for Fedora
