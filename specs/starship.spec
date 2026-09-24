%global debug_package %{nil}

Name:           starship
Version:        %{?module_version}%{!?module_version:1.26.0}
Release:        %{?module_release}%{!?module_release:1}%{?dist}
Summary:        The minimal, blazing-fast, and infinitely customizable prompt for any shell

License:        ISC
URL:            https://github.com/starship/starship
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

Provides:       %{name} = %{version}-%{release}

BuildRequires:  curl

%description
The minimal, blazing-fast, and infinitely customizable prompt for any shell!

%prep
%setup -q -c -n %{name}-%{version}

# Scarica direttamente il README di configurazione da GitHub durante la preparazione
curl -sL https://raw.githubusercontent.com/starship/starship/v%{version}/docs/config/README.md -o CONFIGURATION.md

%build
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
