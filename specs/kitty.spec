Name:           kitty
Version:        %{?module_version}%{!?module_version:0.0.0}
Release:        %{?module_release}%{!?module_release:1%{?dist}}
Summary:        Cross-platform, fast, feature full, GPU based terminal emulator
License:        GPL-3.0-only AND LGPL-2.1-or-later AND Zlib AND (MIT AND CC0-1.0) AND BSD-2-Clause AND CC0-1.0
URL:            https://github.com/kovidgoyal/kitty
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc golang >= 1.22.0 python3-devel lcms2-devel ncurses
BuildRequires:  wayland-devel simde-static dbus-devel fontconfig-devel
BuildRequires:  harfbuzz-devel libcanberra-devel libpng-devel wayland-protocols-devel
BuildRequires:  libXcursor-devel libXi-devel libXinerama-devel libxkbcommon-x11-devel
BuildRequires:  libXrandr-devel zlib-devel openssl-devel xxhash-devel
BuildRequires:  python3-sphinx python3-sphinx-design python3-sphinx-copybutton
BuildRequires:  python3-sphinx-inline-tabs python3-sphinxext-opengraph python3-sphinx-theme-furo

Requires:       python3%{?_isa}
Requires:       hicolor-icon-theme
Requires:       %{name}-terminfo = %{version}-%{release}
Requires:       %{name}-shell-integration = %{version}-%{release}
Requires:       %{name}-kitten%{?_isa} = %{version}-%{release}

Recommends:     ripgrep
Suggests:       ImageMagick%{?_isa}

%description
Cross-platform, fast, feature full, GPU based terminal emulator.
Offloads rendering to the GPU for lower system load and smooth scrolling.

%package        terminfo
Summary:        The terminfo file for Kitty Terminal
License:        GPL-3.0-only
BuildArch:      noarch
Requires:       ncurses-base

%description    terminfo
The terminfo file for Kitty Terminal. Install this on remote machines for SSH support.

%package        shell-integration
Summary:        Shell integration scripts for %{name}
License:        GPL-3.0-only AND MIT
BuildArch:      noarch

%description    shell-integration
Shell integration scripts for Bash, Zsh, and Fish.

%package        kitten
Summary:        The kitten executable
License:        GPL-3.0-only AND MIT AND BSD-3-Clause

%description    kitten
The kitten executable used for standalone helper applications in Kitty.

%package        doc
Summary:        Documentation for %{name}
License:        GPL-3.0-only AND MIT
BuildArch:      noarch

%description    doc
Documentation files for %{name}.

%prep
%autosetup -c -n %{name}-%{version} -p1

# Imposta il tema classic per Sphinx se necessario
sed -i "s/html_theme = 'furo'/html_theme = 'classic'/" docs/conf.py
sed -i 's/-j auto/-j 1/g' docs/Makefile

# Sostituzione shebang python per compatibilità Fedora
find -type f -name "*.py" -exec sed -e 's|/usr/bin/env python3|%{python3}|g' \
                                    -e 's|/usr/bin/env python|%{python3}|g' \
                                    -e 's|/usr/bin/env -S kitty|/usr/bin/kitty|g' \
                                    -i "{}" \;

%build
# Scarica slangc per la compilazione degli shader se non presente nel container
if [ ! -f "/tmp/slang/bin/slangc" ]; then
  mkdir -p /tmp/slang
  curl -L -o /tmp/slang.tar.gz https://github.com/shader-slang/slang/releases/download/v2026.18/slang-2026.18-linux-x86_64-glibc-2.27.tar.gz
  tar -xf /tmp/slang.tar.gz -C /tmp/slang
fi

export PATH="/tmp/slang/bin:$PATH"
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 1. Compilazione pacchetto principale Kitty
%{python3} setup.py linux-package \
    --libdir-name=%{_lib} \
    --update-check-interval=0 \
    --skip-building-kitten \
    --verbose \
    --ignore-compiler-warnings

# 2. Compilazione eseguibile Go kitten
mkdir -p _build/bin
go build -o _build/bin/kitten ./tools/cmd

# 3. FIX PER SPHINX: Crea i collegamenti che docs/conf.py si aspetta per generare le manpage
mkdir -p kitty/launcher/kitty.app/Contents/MacOS
ln -sr _build/bin/kitten kitty/launcher/
ln -sr _build/bin/kitten kitty/launcher/kitty.app/Contents/MacOS/
export PATH="$(pwd)/_build/bin:$PATH"

# 4. Compilazione documentazione
make docs

%install
# Pulizia shebang non eseguibili
find linux-package -type f ! -executable -name "*.py" -exec sed -i '1{\@^#!%{python3}@d}' "{}" \;
find linux-package/%{_lib}/%{name}/shell-integration -type f ! -executable -exec sed -r -i '1{\@^#!/bin/(fish|zsh|sh|bash)@d}' "{}" \;

mkdir -p %{buildroot}%{_prefix}
cp -r linux-package/* %{buildroot}%{_prefix}/

# Installazione Manpages e Docs HTML
install -m 0755 -vd %{buildroot}%{_mandir}/man{1,5}
install -m 0644 -p docs/_build/man/*.1 %{buildroot}%{_mandir}/man1/ 2>/dev/null || true
install -m 0644 -p docs/_build/man/*.5 %{buildroot}%{_mandir}/man5/ 2>/dev/null || true
install -m 0755 -vd %{buildroot}%{_docdir}/%{name}
cp -r docs/_build/html %{buildroot}%{_docdir}/%{name}/ 2>/dev/null || true

# Pulizia file temporanei della doc
rm -f %{buildroot}%{_docdir}/%{name}/html/.buildinfo \
      %{buildroot}%{_docdir}/%{name}/html/.nojekyll

%files
%license LICENSE
%{_bindir}/%{name}
%{_datadir}/applications/*.desktop
%{_datadir}/icons/hicolor/*/*/*.{png,svg}
%{_libdir}/%{name}/
%exclude %{_libdir}/%{name}/shell-integration
%{_mandir}/man{1,5}/*.{1,5}*

%files kitten
%license LICENSE
%{_bindir}/kitten

%files terminfo
%license LICENSE
%{_datadir}/terminfo/x/xterm-%{name}

%files shell-integration
%license LICENSE
%{_libdir}/%{name}/shell-integration/

%files doc
%license LICENSE
%dir %{_docdir}/%{name}
%{_docdir}/%{name}/html
