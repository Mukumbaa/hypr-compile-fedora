#!/usr/bin/env lua

local WORK_DIR = "/tmp/hypr_build_workspace"
local RESULTS_DIR = "/output"
local RPMBUILD_DIR = "/root/rpmbuild"
local SPECS_DIR = "specs"

local function run(cmd)
  print("\n------------------------------------------------------------")
  print("Executing: " .. cmd:match("([^\n]+)"))
  print("------------------------------------------------------------")

  local success, _, code = os.execute(cmd)
  local failed = false
  if type(success) == "number" and success ~= 0 then failed = true end
  if success == nil or success == false then failed = true end

  if failed then
    print("\n[!] FATAL ERROR executing command:\n" .. cmd)
    os.exit(1)
  end
end

local compiled_versions = {}

-- Recupera la versione reale da memoria o dagli RPM salvati in /output
local function resolve_dep_version(dep_dir)
  if compiled_versions[dep_dir] then
    return compiled_versions[dep_dir]
  end

  local h = io.popen(string.format("ls %s/%s-*.rpm 2>/dev/null | head -n 1", RESULTS_DIR, dep_dir:lower()))
  local rpm_path = h:read("*a"):gsub("%s+", "")
  h:close()

  if rpm_path ~= "" then
    local ver = rpm_path:match(dep_dir:lower() .. "%-(%d+[%d%.]*)%-")
    if ver then return ver end
  end

  return "0"
end

-- Calcola l'hash MD5 basato sulle versioni effettivamente usate/installate
local function get_deps_hash(deps_list)
  if not deps_list or #deps_list == 0 then return "base" end
  local str = ""
  for _, dep_dir in ipairs(deps_list) do
    str = str .. dep_dir .. "=" .. resolve_dep_version(dep_dir) .. ";"
  end
  local h = io.popen(string.format("echo -n '%s' | md5sum | cut -c1-7", str))
  local hash = h:read("*a"):gsub("%s+", "")
  h:close()
  return hash
end

-- Pulizia e creazione directory
run(string.format("rm -rf %s && mkdir -p %s %s", WORK_DIR, WORK_DIR, RESULTS_DIR))
run(string.format("mkdir -p %s/{BUILD,RPMS,SOURCES,SPECS,SRPMS}", RPMBUILD_DIR))

print("--> Installing base tools...")
run("dnf install -y gcc-c++ cmake meson ninja-build git tar rpm-build pkgconf-pkg-config")

--------------------------------------------------------------------------------
-- CONFIGURAZIONE JOB PARALLELI
--------------------------------------------------------------------------------
print("\n============================================================")
print("COMPILATION THREADS / RAM MANAGEMENT")
print("============================================================")
print("  1) Limit to 2 jobs (<8GB RAM) [Default]")
print("  2) Limit to 4 jobs (8-16GB RAM)")
print("  3) Custom number of jobs")
print("  0) Unlimited / System Default")
io.write("Choose option [1]: ")
local job_choice = io.read("*l")

local num_jobs = "2"
if job_choice == "2" then
  num_jobs = "4"
elseif job_choice == "3" then
  io.write("Enter exact number of jobs (e.g. 1, 2, 6): ")
  num_jobs = tostring(tonumber(io.read("*l")) or 2)
elseif job_choice == "0" then
  num_jobs = nil
end

local rpmbuild_jobs_flag = ""
local env_jobs_macro = ""

if num_jobs then
  rpmbuild_jobs_flag = string.format("--define '_smp_mflags -j%s'", num_jobs)
  env_jobs_macro = string.format("export NINJA_JOBS=%s\nexport MAKEFLAGS='-j%s'\nexport CARGO_BUILD_JOBS=%s", num_jobs, num_jobs, num_jobs)
else
  print("--> Warning: Using default system threads.")
end

local all_modules = {
  { url = "https://github.com/hyprwm/hyprwayland-scanner.git",        dir = "hyprwayland-scanner",         build_reqs = "pugixml-devel", core_deps = {} },
  { url = "https://github.com/hyprwm/hyprland-protocols.git",         dir = "hyprland-protocols",          build_reqs = "", core_deps = {} },
  { url = "https://github.com/hyprwm/hyprutils.git",                   dir = "hyprutils",                   build_reqs = "pixman-devel", core_deps = {} },
  { url = "https://github.com/hyprwm/hyprlang.git",                    dir = "hyprlang",                    build_reqs = "", core_deps = { "hyprutils" } },
  { url = "https://github.com/hyprwm/hyprgraphics.git",               dir = "hyprgraphics",                build_reqs = "cairo-devel pango-devel librsvg2-devel libjpeg-turbo-devel libwebp-devel pixman-devel mesa-libGLES-devel mesa-libGL-devel libspng-devel file-devel libjxl-devel", core_deps = { "hyprutils" } },
  { url = "https://github.com/hyprwm/hyprcursor.git",                  dir = "hyprcursor",                  build_reqs = "cairo-devel librsvg2-devel libzip-devel tomlplusplus-devel", core_deps = { "hyprlang" } },
  { url = "https://github.com/hyprwm/aquamarine.git",                  dir = "aquamarine",                  build_reqs = "pixman-devel wayland-devel wayland-protocols-devel libinput-devel libdrm-devel mesa-libgbm-devel libdisplay-info-devel libseat-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel hwdata-devel", core_deps = { "hyprutils", "hyprwayland-scanner" } },
  { url = "https://github.com/hyprwm/hyprwire.git",                    dir = "hyprwire",                    build_reqs = "libffi-devel pugixml-devel", core_deps = { "hyprutils" } },
  { url = "https://github.com/hyprwm/hyprtoolkit.git",                 dir = "hyprtoolkit",                 build_reqs = "iniparser-devel libxkbcommon-devel wayland-devel wayland-protocols-devel cairo-devel pango-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel libdrm-devel pixman-devel", core_deps = { "hyprwayland-scanner", "aquamarine", "hyprgraphics", "hyprutils", "hyprlang" } },
  { url = "https://github.com/hyprwm/hyprland-guiutils.git",           dir = "hyprland-guiutils",           build_reqs = "cairo-devel libxkbcommon-devel libdrm-devel pixman-devel", core_deps = { "hyprlang", "hyprutils", "hyprtoolkit" } },
  { url = "https://github.com/Vladimir-csp/uwsm.git",                  dir = "uwsm",                        extra_args = "-Duuctl=enabled -Dfumon=enabled", build_reqs = "scdoc pam-devel systemd-devel systemd-rpm-macros python3-dbus python3-pyxdg desktop-file-utils", core_deps = {} },
  { url = "https://github.com/hyprwm/xdg-desktop-portal-hyprland.git", dir = "xdg-desktop-portal-hyprland", build_reqs = "libuuid-devel sdbus-cpp-devel pipewire-devel qt6-qtbase-devel qt6-qtwayland-devel wayland-devel wayland-protocols-devel libdrm-devel mesa-libgbm-devel mesa-libGL-devel", core_deps = { "hyprlang", "hyprutils", "hyprwayland-scanner", "hyprland-protocols" } },
  { url = "https://github.com/hyprwm/Hyprland.git",                   dir = "Hyprland",                    build_reqs = "readline-devel cairo-devel pango-devel libdrm-devel libinput-devel libxkbcommon-devel libuuid-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel xcb-util-wm-devel xcb-util-renderutil-devel xcb-util-errors-devel xcb-util-keysyms-devel libxcb-devel tomlplusplus-devel re2-devel lcms2-devel libdisplay-info-devel hwdata-devel glslang-devel muParser-devel libeis-devel libcanberra-devel libXcursor-devel glib2-devel", core_deps = { "hyprutils", "hyprlang", "hyprcursor", "hyprgraphics", "aquamarine", "hyprwayland-scanner", "hyprland-protocols" } },
  { url = "https://github.com/hyprwm/hyprpaper.git",                   dir = "hyprpaper",                   build_reqs = "wayland-devel wayland-protocols-devel cairo-devel pango-devel libjpeg-turbo-devel libwebp-devel mesa-libGLES-devel file-devel systemd-rpm-macros", core_deps = { "hyprwayland-scanner", "hyprlang", "hyprutils", "hyprtoolkit", "hyprwire" } },
  { url = "https://github.com/hyprwm/hyprlock.git",                    dir = "hyprlock",                    build_reqs = "pam-devel wayland-devel wayland-protocols-devel cairo-devel pango-devel libdrm-devel libxkbcommon-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel sdbus-cpp-devel systemd-devel", core_deps = { "hyprwayland-scanner", "hyprlang", "hyprutils", "hyprgraphics" } },
  { url = "https://github.com/hyprwm/hyprpicker.git",                  dir = "hyprpicker",                  build_reqs = "wayland-devel wayland-protocols-devel cairo-devel pango-devel libxkbcommon-devel mesa-libGLES-devel mesa-libGL-devel", core_deps = { "hyprutils", "hyprwayland-scanner" } },
  { url = "https://github.com/outfoxxed/quickshell.git",               dir = "quickshell",                  extra_args = "-DVENDOR_CPPTRACE=ON -DINSTALL_QML_PREFIX=lib64/qt6/qml", build_reqs = "qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtshadertools-devel qt6-qtsvg-devel cli11-devel jemalloc-devel pipewire-devel libdrm-devel mesa-libGL-devel vulkan-headers polkit-devel libxcb-devel libunwind-devel libdwarf-devel", core_deps = {} },
  { url = "https://github.com/sxyazi/yazi.git",                        dir = "yazi",                        build_reqs = "cargo rustc", core_deps = {} },
  { url = "https://github.com/kovidgoyal/kitty.git",                   dir = "kitty",                       build_reqs = "golang python3-devel ncurses libX11-devel libXrandr-devel libXinerama-devel libXcursor-devel libxkbcommon-devel dbus-devel fontconfig harfbuzz-devel zlib-devel slang slang-devel xxhash-devel openssl-devel libxkbcommon-x11-devel simde-devel vulkan-headers vulkan-loader-devel python3-sphinx python3-sphinx-copybutton python3-sphinx-inline-tabs python3-sphinxext-opengraph python3-sphinx-design python3-sphinx-theme-furo", core_deps = {} },
{ url = "https://github.com/yorukot/superfile.git", dir = "superfile", build_reqs = "", core_deps = {} },
}


-- Funzione per trovare la definizione di un modulo dato il suo nome di directory
local function find_module_by_dir(dir_name)
  if not all_modules then return nil end
  for _, mod in ipairs(all_modules) do
    if mod.dir and mod.dir:lower() == dir_name:lower() then
      return mod
    end
  end
  return nil
end

-- Funzione ricorsiva semplice per installare un pacchetto e le sue dipendenze a catena
local function install_pkg_and_deps(dir_name)
  local mod = find_module_by_dir(dir_name)
  if not mod then return end

  -- Se ha dipendenze core, le chiama ricorsivamente PRIMA di installare se stesso
  if mod.core_deps and #mod.core_deps > 0 then
    for _, dep in ipairs(mod.core_deps) do
      install_pkg_and_deps(dep)
    end
  end

  -- Nessuna dipendenza (o dipendenze già installate/risolite): installa il pacchetto corrente
  local rpm_name = dir_name:lower()
  print(string.format("--> [Ricursione] Installazione di %s e relativi pacchetti da /output...", dir_name))
  run(string.format("dnf install -y --allowerasing %s/%s-*.rpm %s/%s-devel-*.rpm 2>/dev/null || true", RESULTS_DIR, rpm_name, RESULTS_DIR, rpm_name))
end


print("\n============================================================")
print("PACKAGE SELECTION MENU")
print("============================================================")
for i, mod in ipairs(all_modules) do
  print(string.format(" %2d) %s", i, mod.dir))
end
print("  0) ALL PACKAGES (Default)")
print("============================================================")

io.write("Enter numbers or 0 for ALL [0]: ")
local ans_pkgs = io.read("*l")

local modules_to_compile = {}
if ans_pkgs == "" or ans_pkgs:match("^%s*0%s*$") or ans_pkgs:lower():match("all") then
  modules_to_compile = all_modules
else
  -- Controlla se è stato inserito un numero singolo esatto (es. 20)
  local single_idx = tonumber(ans_pkgs)
  if single_idx and all_modules[single_idx] then
    table.insert(modules_to_compile, all_modules[single_idx])
  else
    -- Altrimenti gestisce eventuali liste separate da spazi (es. "1 3 5")
    for num_str in ans_pkgs:gmatch("%d+") do
      local idx = tonumber(num_str)
      if idx and all_modules[idx] then table.insert(modules_to_compile, all_modules[idx]) end
    end
  end
  if #modules_to_compile == 0 then modules_to_compile = all_modules end
end

local function get_pkg_version(repo_dir)
  local cmd = string.format("cd %s && (git tag -l 'v[0-9]*' --sort=-v:refname | head -n 1 || git tag -l | sort -V | tail -n 1 || echo '0.0.0')", repo_dir)
  local h = io.popen(cmd)
  local ver = h:read("*a"):gsub("%s+", "")
  h:close()

  ver = ver:gsub("^v", ""):gsub("-", ".")
  return (ver ~= "" and ver) or "0.0.0"
end

local changelog_date = os.date("%a %b %d %Y")

-- print("\n--> Ripristino pacchetti già compilati da /output (escluso metapacchetto)...")
-- run("find /output -maxdepth 1 -name '*.rpm' ! -name 'hyprland-desktop*' | grep -q . && dnf install -y --allowerasing $(find /output -maxdepth 1 -name '*.rpm' ! -name 'hyprland-desktop*') || true")

for _, module in ipairs(modules_to_compile) do
  print("\n============================================================")
  print("--> Processing: " .. module.dir)
  print("============================================================")

  -- INSTALLAZIONE RICORSIVA DELLE DIPENDENZE
  if module.core_deps and #module.core_deps > 0 then
    print("--> Avvio risoluzione ricorsiva delle dipendenze per " .. module.dir .. "...")
    for _, dep in ipairs(module.core_deps) do
      install_pkg_and_deps(dep)
    end
  end

  local module_src = WORK_DIR .. "/" .. module.dir
  local rpm_name = module.dir:lower()
  local args = module.extra_args or ""
  local specific_reqs = module.build_reqs or ""

  if specific_reqs ~= "" then
    run(string.format("dnf install -y --skip-unavailable %s", specific_reqs))
  end

  run(string.format("git clone --recursive %s %s", module.url, module_src))

  local checkout_cmd = string.format([[
    cd %s &&
    LATEST_TAG=$(git tag -l 'v[0-9]*' --sort=-v:refname | head -n 1)
    [ -z "$LATEST_TAG" ] && LATEST_TAG=$(git tag -l | sort -V | tail -n 1)
    if [ -n "$LATEST_TAG" ]; then
      git checkout "$LATEST_TAG" 2>/dev/null
      git submodule update --init --recursive
    fi
  ]], module_src)
  run(checkout_cmd)

  local module_version = get_pkg_version(module_src)
  compiled_versions[module.dir] = module_version
  print("--> Calculated Version: " .. module_version)

  local deps_hash = get_deps_hash(module.core_deps)

  -- Controllo RPM con supporto agli hash dinamici e preesistenti
  local search_pattern = string.format("%s-%s-1.*.rpm", rpm_name, module_version)
  local h_check = io.popen(string.format("ls %s/%s 2>/dev/null | grep '_%s' | head -n 1", RESULTS_DIR, search_pattern, deps_hash))
  local existing_rpm = h_check:read("*a"):gsub("%s+", "")
  h_check:close()

  if existing_rpm ~= "" then
    print("\n[=] MATCH PERFETTO: RPM già esistente con la stessa versione e dipendenze identiche!")
    print("--> Salto compilazione e installo: " .. existing_rpm)
    run(string.format("dnf install -y --allowerasing %s/%s*.rpm", RESULTS_DIR, rpm_name))
  else
    print("\n[+] Nessun RPM valido trovato per " .. rpm_name .. " (versione o dipendenze cambiate).")

    local build_time = os.date("%Y%m%d%H%M")
    local rpm_release = string.format("1.%s_%s", build_time, deps_hash)
    print("--> Generating new build Release: " .. rpm_release)

    local tarball_name = string.format("%s-%s.tar.gz", rpm_name, module_version)
    run(string.format("tar --exclude='.git' -czf %s/SOURCES/%s -C %s .", RPMBUILD_DIR, tarball_name, module_src))

    local target_spec_file = RPMBUILD_DIR .. "/SPECS/" .. rpm_name .. ".spec"
    local custom_spec_path = SPECS_DIR .. "/" .. rpm_name .. ".spec"

    local custom_spec_file = io.open(custom_spec_path, "r")
    if custom_spec_file then
      custom_spec_file:close()
      print("--> [!] Trovato .spec personalizzato in: " .. custom_spec_path)
      run(string.format("cp -f %s %s", custom_spec_path, target_spec_file))
    else
      print("--> Generazione .spec generico in corso...")
      local spec_content = string.format([[
%%global debug_package %%{nil}

Name:           %s
Version:        %%{?module_version}%%{!?module_version:%s}
Release:        %%{?module_release}%%{!?module_release:%s%%{?dist}}
Summary:        Native build for %s
License:        GPL/MIT/BSD
Source0:        %s
Provides:       %s = %%{version}-%%{release}
Provides:       %s-devel = %%{version}-%%{release}

%%description
Native RPM build of %s.

%%prep
%%autosetup -c
[ -f "VERSION" ] && echo "%%{version}" > VERSION || true

%%build
%s
if [ -f "CMakeLists.txt" ]; then
  %%cmake %s
  %%cmake_build
elif [ -f "meson.build" ]; then
  %%meson %s
  %%meson_build
elif [ -f "Cargo.toml" ]; then
  cargo build --release --locked ${CARGO_BUILD_JOBS:+-j $CARGO_BUILD_JOBS}
elif [ -f "setup.py" ]; then
  python3 setup.py linux-package --vcs-rev "" --update-check-interval=0 --ignore-compiler-warnings
fi
    
%%install
if [ -f "CMakeLists.txt" ]; then
  %%cmake_install
elif [ -f "meson.build" ]; then
  %%meson_install
elif [ -f "Cargo.toml" ]; then
  install -Dm755 target/release/yazi %%{buildroot}%%{_bindir}/yazi
  install -Dm755 target/release/ya %%{buildroot}%%{_bindir}/ya
elif [ -f "setup.py" ]; then
  mkdir -p %%{buildroot}%%{_prefix}
  cp -r linux-package/* %%{buildroot}%%{_prefix}/
fi

rm -rf %%{buildroot}%%{_libdir}/cmake/zstd %%{buildroot}%%{_libdir}/pkgconfig/libdwarf.pc %%{buildroot}%%{_libdir}/pkgconfig/libzstd.pc

find %%{buildroot} -not -type d | sed "s|%%{buildroot}||g" > %%{_builddir}/filelist.txt
find %%{buildroot}%%{_datadir}/hypr* %%{buildroot}%%{_includedir}/hypr* -type d 2>/dev/null | sed "s|%%{buildroot}|%%dir |g" >> %%{_builddir}/filelist.txt || true
sed -i -e 's|\(/share/man/.*\)|\1*|' %%{_builddir}/filelist.txt

%%files -f %%{_builddir}/filelist.txt
%%defattr(-,root,root,-)

%%changelog
* %s builder <builder@localhost> - %s-%s
- Native Build
]], rpm_name, module_version, rpm_release, rpm_name, tarball_name, rpm_name, rpm_name, rpm_name, env_jobs_macro, args, args, changelog_date, module_version, rpm_release)

      spec_content = spec_content:gsub("\n%s+(%%)", "\n%%"):gsub("^%s+(%%)", "%%")

      local f = io.open(target_spec_file, "w")
      f:write(spec_content)
      f:close()
    end

    print("--> Compilazione RPM in corso...")
    run(string.format("rpmbuild %s --define 'module_version %s' --define 'module_release %s' --define 'source_tarball %s' -bb --nodeps %s", rpmbuild_jobs_flag, module_version, rpm_release, tarball_name, target_spec_file))

    run(string.format("rm -f %s/%s-*.rpm", RESULTS_DIR, rpm_name))
    run(string.format("find %s/RPMS -name '%s-*.rpm' -exec cp -f {} %s/ \\;", RPMBUILD_DIR, rpm_name, RESULTS_DIR))

    print("--> Test di installazione pacchetto nel sistema...")
    run(string.format("dnf install -y --allowerasing %s/%s*.rpm", RESULTS_DIR, rpm_name))
  end
end

print("\n============================================================")
print("SUCCESS")
print("============================================================")
print("RPM saved in: " .. RESULTS_DIR)

--------------------------------------------------------------------------------
-- GENERAZIONE METAPACCHETTO hyprland-desktop
--------------------------------------------------------------------------------
print("\n============================================================")
print("--> Generazione Metapacchetto hyprland-desktop...")
print("============================================================")

local meta_spec = RPMBUILD_DIR .. "/SPECS/hyprland-desktop.spec"
local meta_f = io.open(meta_spec, "w")

meta_f:write(string.format([[
Name:           hyprland-desktop
Version:        1.0
Release:        1%%{?dist}
Summary:        Complete Hyprland Desktop Environment Suite
License:        GPL/MIT
BuildArch:      noarch

Requires:       hyprland
Requires:       uwsm
Requires:       xdg-desktop-portal-hyprland
Requires:       hyprland-guiutils
Requires:       hyprpaper
Requires:       hyprlock
Requires:       hyprpicker
Requires:       quickshell
Requires:       yazi

%%description
Meta-package to install the complete Hyprland desktop environment suite.

%%files

%%changelog
* %s builder <builder@localhost> - 1.0-1
- Initial meta-package release
]], changelog_date))

meta_f:close()

run("rpmbuild -bb " .. meta_spec)
run("cp -f " .. RPMBUILD_DIR .. "/RPMS/noarch/hyprland-desktop-*.rpm " .. RESULTS_DIR .. "/")
