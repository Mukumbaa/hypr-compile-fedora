#!/usr/bin/env lua
-- ============================================================
--   HYPRLAND NATIVE VM BUILD & INSTALL PIPELINE
-- ============================================================

local WORK_DIR = "/tmp/hypr_build_workspace"
local RESULTS_DIR = "/output"
local RPMBUILD_DIR = "/root/rpmbuild"

local function run(cmd)
  print("\n------------------------------------------------------------")
  print("Executing: " .. cmd:match("([^\n]+)"))
  print("------------------------------------------------------------")

  local success, reason, status = os.execute(cmd)
  local failed = false
  if type(success) == "number" and success ~= 0 then failed = true end
  if success == nil or success == false then failed = true end

  if failed then
    print("\n[!] FATAL ERROR executing command:\n" .. cmd)
    os.exit(1)
  end
end

-- 1. Pulizia cartelle e creazione alberi di directory
run(string.format("rm -rf %s && mkdir -p %s %s", WORK_DIR, WORK_DIR, RESULTS_DIR))
run(string.format("mkdir -p %s/{BUILD,RPMS,SOURCES,SPECS,SRPMS}", RPMBUILD_DIR))

print("============================================================")
print("     HYPRLAND NATIVE VM PIPELINE (FAST & DIRECT)           ")
print("============================================================\n")

-- 2. Installazione strumenti di build di base sulla VM
print("--> Assicurazione tool di sviluppo di base installati...")
run("dnf install -y gcc-c++ cmake meson ninja-build git tar rpm-build pkgconf-pkg-config")

print("\nSelect version strategy:")
print("  1) Last release tag (default)")
print("  2) Last git commit")
io.write("Chose [1]: ")
local ver_choice = io.read("*l")

-- Se premi solo Invio o scrivi "1", imposta 1 (Release tag) di default
if ver_choice == nil or ver_choice == "" or ver_choice == "1" then
  ver_choice = "1"
else
  ver_choice = "2"
end

-- 3. Lista dei moduli in sequenza logica
local all_modules = {
  { url = "https://github.com/hyprwm/hyprwayland-scanner.git",         dir = "hyprwayland-scanner",         build_reqs = "pugixml-devel" },
  { url = "https://github.com/hyprwm/hyprland-protocols.git",          dir = "hyprland-protocols",          build_reqs = "" },
  { url = "https://github.com/hyprwm/hyprutils.git",                   dir = "hyprutils",                   build_reqs = "pixman-devel" },
  { url = "https://github.com/hyprwm/hyprlang.git",                    dir = "hyprlang",                    build_reqs = "" },
  { url = "https://github.com/hyprwm/hyprgraphics.git",                dir = "hyprgraphics",                build_reqs = "cairo-devel pango-devel librsvg2-devel libjpeg-turbo-devel libwebp-devel pixman-devel mesa-libGLES-devel mesa-libGL-devel libspng-devel file-devel libjxl-devel" },
  { url = "https://github.com/hyprwm/hyprcursor.git",                  dir = "hyprcursor",                  build_reqs = "cairo-devel librsvg2-devel libzip-devel tomlplusplus-devel" },
  { url = "https://github.com/hyprwm/aquamarine.git",                  dir = "aquamarine",                  build_reqs = "pixman-devel wayland-devel wayland-protocols-devel libinput-devel libdrm-devel mesa-libgbm-devel libdisplay-info-devel libseat-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel hwdata-devel" },
  { url = "https://github.com/hyprwm/hyprwire.git",                    dir = "hyprwire",                    build_reqs = "libffi-devel pugixml-devel" },
  { url = "https://github.com/hyprwm/hyprtoolkit.git",                 dir = "hyprtoolkit",                 build_reqs = "iniparser-devel libxkbcommon-devel wayland-devel wayland-protocols-devel cairo-devel pango-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel libdrm-devel pixman-devel" },
  { url = "https://github.com/hyprwm/hyprland-guiutils.git",           dir = "hyprland-guiutils",           build_reqs = "cairo-devel libxkbcommon-devel libdrm-devel pixman-devel" },
  { url = "https://github.com/hyprwm/xdg-desktop-portal-hyprland.git", dir = "xdg-desktop-portal-hyprland", build_reqs = "libuuid-devel sdbus-cpp-devel pipewire-devel qt6-qtbase-devel qt6-qtwayland-devel wayland-devel wayland-protocols-devel libdrm-devel mesa-libgbm-devel mesa-libGL-devel" },
  { url = "https://github.com/hyprwm/Hyprland.git",                    dir = "Hyprland",                    build_reqs = "readline-devel cairo-devel pango-devel libdrm-devel libinput-devel libxkbcommon-devel libuuid-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel xcb-util-wm-devel xcb-util-renderutil-devel xcb-util-errors-devel xcb-util-keysyms-devel libxcb-devel tomlplusplus-devel re2-devel lcms2-devel libdisplay-info-devel hwdata-devel glslang-devel muParser-devel libeis-devel libcanberra-devel libXcursor-devel glib2-devel" },
  { url = "https://github.com/hyprwm/hyprpaper.git",                   dir = "hyprpaper",                   build_reqs = "wayland-devel wayland-protocols-devel cairo-devel pango-devel libjpeg-turbo-devel libwebp-devel mesa-libGLES-devel file-devel systemd-rpm-macros" },
  { url = "https://github.com/hyprwm/hyprlock.git",                    dir = "hyprlock",                    build_reqs = "pam-devel wayland-devel wayland-protocols-devel cairo-devel pango-devel libdrm-devel libxkbcommon-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel sdbus-cpp-devel systemd-devel" },
  { url = "https://github.com/hyprwm/hyprpicker.git",                  dir = "hyprpicker",                  build_reqs = "wayland-devel wayland-protocols-devel cairo-devel pango-devel libxkbcommon-devel mesa-libGLES-devel mesa-libGL-devel" },
  { url = "https://github.com/Vladimir-csp/uwsm.git",                  dir = "uwsm",                        extra_args = "-Duuctl=enabled -Dfumon=enabled", build_reqs = "scdoc pam-devel systemd-devel systemd-rpm-macros" },
  { 
    url = "https://github.com/outfoxxed/quickshell.git",               
    dir = "quickshell",                  
    extra_args = "-DVENDOR_CPPTRACE=ON",
    build_reqs = "qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtshadertools-devel qt6-qtsvg-devel cli11-devel jemalloc-devel pipewire-devel libdrm-devel mesa-libGL-devel vulkan-headers polkit-devel libxcb-devel libunwind-devel libdwarf-devel" 
  }
}

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
if ans_pkgs == "" or ans_pkgs:match("0") or ans_pkgs:lower():match("all") then
  modules_to_compile = all_modules
else
  for num_str in ans_pkgs:gmatch("%d+") do
    local idx = tonumber(num_str)
    if idx and all_modules[idx] then table.insert(modules_to_compile, all_modules[idx]) end
  end
  if #modules_to_compile == 0 then modules_to_compile = all_modules end
end

-- 4. Funzione calcolo versione
local function get_pkg_version(repo_dir, strategy)
  if strategy == "1" then
    -- Strategia 1: Ultimo release tag stabile (es. v0.56.2 -> 0.56.2)
    local h = io.popen(string.format("cd %s && (git tag -l 'v[0-9]*' --sort=-v:refname | head -n 1 || git tag -l | sort -V | tail -n 1 || echo '0.0.0')", repo_dir))
    local ver = h:read("*a"):gsub("\n", ""):gsub("^v", ""):gsub("-", ".")
    h:close()
    return (ver ~= "" and ver) or "0.0.0"
  else
    -- Strategia 2: Ultimo git commit
    local h_desc = io.popen(string.format("cd %s && git describe --tags --long 2>/dev/null", repo_dir))
    local desc = h_desc:read("*a"):gsub("\n", "")
    h_desc:close()

    if desc ~= "" then
      return desc:gsub("^v", ""):gsub("-g", ".git"):gsub("-", ".")
    else
      local h_cnt = io.popen(string.format("cd %s && git rev-list --count HEAD 2>/dev/null || echo 1", repo_dir))
      local cnt = h_cnt:read("*a"):gsub("\n", "")
      h_cnt:close()
      local h_hash = io.popen(string.format("cd %s && git rev-parse --short HEAD 2>/dev/null || echo unknown", repo_dir))
      local hash = h_hash:read("*a"):gsub("\n", "")
      h_hash:close()
      return string.format("0.0.0.%s.git%s", cnt, hash)
    end
  end
end

-- ============================================================
-- 5. CICLO DI COMPILAZIONE ED INSTALLAZIONE NATIVA
-- ============================================================
local changelog_date = os.date("%a %b %d %Y")

-- Installa in 3 secondi tutti gli RPM già compilati e presenti nella cartella /output
print("\n--> Ripristino pacchetti già compilati da /output...")
run("ls /output/*.rpm >/dev/null 2>&1 && dnf install -y --allowerasing /output/*.rpm || true")

for _, module in ipairs(modules_to_compile) do
  print("\n============================================================")
  print("--> Processing: " .. module.dir)
  print("============================================================")

  local module_src = WORK_DIR .. "/" .. module.dir
  local rpm_name = module.dir:lower()
  local args = module.extra_args or ""
  local specific_reqs = module.build_reqs or ""

  -- A. Installa subito le dipendenze di sistema Fedora necessarie
  if specific_reqs ~= "" then
    print("--> Installazione dipendenze di sistema per " .. module.dir .. "...")
    run(string.format("dnf install -y --skip-unavailable %s", specific_reqs))
  end

  -- B. Clone e checkout Git
  run(string.format("git clone --recursive %s %s", module.url, module_src))

  if ver_choice == "1" then
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
  else
    run(string.format("cd %s && git submodule update --init --recursive", module_src))
  end

  local module_version = get_pkg_version(module_src, ver_choice)
  print("--> Calculated Version: " .. module_version)

  -- C. Creazione tarball sorgente
  local tarball_name = string.format("%s-%s.tar.gz", rpm_name, module_version)
  run(string.format("tar --exclude='.git' -czf %s/SOURCES/%s -C %s .", RPMBUILD_DIR, tarball_name, module_src))

  -- D. Generazione file .spec
  local spec_file = RPMBUILD_DIR .. "/SPECS/" .. rpm_name .. ".spec"
  local spec_content = string.format([[
%%global debug_package %%{nil}

Name:           %s
Version:        %s
Release:        1%%{?dist}
Summary:        Native build for %s
License:        GPL/MIT/BSD
Source0:        %s
Provides:       %s = %%{version}-%%{release}
Provides:       %s-devel = %%{version}-%%{release}

%%description
Native RPM build of %s.

%%prep
%%autosetup -c
# Allinea il file VERSION con la versione reale del tag Git (per hyprctl)
[ -f "VERSION" ] && echo "%%{version}" > VERSION || true

%%build
if [ -f "CMakeLists.txt" ]; then
  %%cmake %s
  %%cmake_build
elif [ -f "meson.build" ]; then
  %%meson %s
  %%meson_build
fi

%%install
if [ -f "CMakeLists.txt" ]; then
  %%cmake_install
elif [ -f "meson.build" ]; then
  %%meson_install
fi

find %%{buildroot} -not -type d | sed "s|%%{buildroot}||g" > %%{_builddir}/filelist.txt
find %%{buildroot}%%{_datadir}/hypr* %%{buildroot}%%{_includedir}/hypr* -type d 2>/dev/null | sed "s|%%{buildroot}|%%dir |g" >> %%{_builddir}/filelist.txt || true

# Risolve la compressione automatica (.gz) delle man page di rpmbuild
sed -i -e 's|\(/share/man/.*\)|\1*|' %%{_builddir}/filelist.txt

%%files -f %%{_builddir}/filelist.txt
%%defattr(-,root,root,-)

%%changelog
* %s builder <builder@localhost> - %s-1
- Native Build
]], rpm_name, module_version, rpm_name, tarball_name, rpm_name, rpm_name, rpm_name, args, args, changelog_date, module_version)

  spec_content = spec_content:gsub("\n%s+(%%)", "\n%%"):gsub("^%s+(%%)", "%%")

  local f = io.open(spec_file, "w")
  f:write(spec_content)
  f:close()

  -- E. Compilazione RPM nativa con rpmbuild
  print("--> Compilazione RPM in corso...")
  run(string.format("rpmbuild -bb --nodeps %s", spec_file))

  -- F. Sposta gli RPM generati nella cartella dei risultati
  run(string.format("find %s/RPMS -name '%s-*.rpm' -exec cp -f {} %s/ \\;", RPMBUILD_DIR, rpm_name, RESULTS_DIR))

  -- G. Installa subito il pacchetto generato nel sistema VM!
  print("--> Installazione pacchetto nel sistema per renderlo disponibile ai successivi...")
  run(string.format("dnf install -y --allowerasing %s/%s-%s-*.rpm", RESULTS_DIR, rpm_name, module_version))
end

print("\n============================================================")
print("TUTTI I PACCHETTI SONO STATI COMPILATI ED INSTALLATI CON SUCCESSO!")
print("============================================================")
print("Copie di tutti gli RPM generati salvate in: " .. RESULTS_DIR)
