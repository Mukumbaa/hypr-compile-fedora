Name:           yazi
Version:        %{?module_version}%{!?module_version:26.9.1}
Release:        %{?module_release}%{!?module_release:1}%{?dist}
Summary:        Yazi file manager written in Rust, based on async I/O

License:        MIT
URL:            https://yazi-rs.github.io 
Source0:        %{?source_tarball}%{!?source_tarball:%{name}-%{version}.tar.gz}

Provides:       %{name} = %{version}-%{release}

# Dipendenze a runtime raccomandate da Yazi
Recommends:     ffmpeg
Recommends:     p7zip
Recommends:     p7zip-plugins
Recommends:     jq
Recommends:     poppler-utils
Recommends:     fd-find
Recommends:     ripgrep
Recommends:     fzf
Recommends:     zoxide
Recommends:     resvg
Recommends:     ImageMagick
Recommends:     git

BuildRequires:  cargo
BuildRequires:  rustc
BuildRequires:  make
BuildRequires:  gcc
BuildRequires:  git

%description
Blazing fast terminal file manager written in Rust, based on async I/O.

%prep
%autosetup -c -n %{name}-%{version} -p1

# Vendorizzazione delle dipendenze Cargo (necessaria per gestire eventuali fork git interni)
if [ ! -d ".cargo" ]; then
  mkdir -p .cargo
  cargo vendor > cargo-vendor-config.toml
  awk '/^\[/ { keep = /^\[source\."git\+/ } keep' cargo-vendor-config.toml >> .cargo/config.toml
fi

%build
export YAZI_GEN_COMPLETIONS=1 
export JEMALLOC_SYS_WITH_LG_PAGE=14

# Compilazione tramite Cargo sfruttando i job paralleli definiti dallo script
cargo build --release --locked ${CARGO_BUILD_JOBS:+-j $CARGO_BUILD_JOBS}

%install
install -Dpm 0755 -t %{buildroot}%{_bindir} target/release/yazi target/release/ya 

# Installazione dei file di completamento se presenti nella struttura sorgente
install -Dpm 0644 yazi-boot/completions/%{name}.bash yazi-cli/completions/ya.bash -t %{buildroot}%{bash_completions_dir} 2>/dev/null || true
install -Dpm 0644 yazi-boot/completions/%{name}.fish yazi-cli/completions/ya.fish -t %{buildroot}%{fish_completions_dir} 2>/dev/null || true
install -Dpm 0644 yazi-boot/completions/_%{name}     yazi-cli/completions/_ya     -t %{buildroot}%{zsh_completions_dir} 2>/dev/null || true

%files
%license LICENSE
%doc README.md
%{_bindir}/ya
%{_bindir}/yazi
%{bash_completions_dir}/%{name}.bash
%{bash_completions_dir}/ya.bash
%{zsh_completions_dir}/_%{name}
%{zsh_completions_dir}/_ya
%{fish_completions_dir}/%{name}.fish
%{fish_completions_dir}/ya.fish

%changelog
* Wed Sep 23 2026 builder <builder@localhost> - %{version}-%{release}
- Native Build for Fedora
