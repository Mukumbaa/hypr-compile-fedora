#!/usr/bin/env lua

package.path = package.path .. ";./?.lua"

local C = require("modules.colors")
local config = require("modules.config")
local utils = require("modules.utils")

-- Pulizia e creazione directory
utils.run(string.format("rm -rf %s && mkdir -p %s %s", config.WORK_DIR, config.WORK_DIR, config.RESULTS_DIR))
utils.run(string.format("mkdir -p %s/{BUILD,RPMS,SOURCES,SPECS,SRPMS}", config.RPMBUILD_DIR))

print(C.yellow .. "--> Installing base tools..." .. C.reset)
utils.run("dnf install -y gcc-c++ cmake meson ninja-build git tar rpm-build pkgconf-pkg-config")

--------------------------------------------------------------------------------
-- CONFIGURAZIONE JOB PARALLELI
--------------------------------------------------------------------------------
print(string.format("\n%s============================================================%s", C.magenta, C.reset))
print(C.bold .. "COMPILATION THREADS / RAM MANAGEMENT" .. C.reset)
print(string.format("%s============================================================%s", C.magenta, C.reset))
print("  1) Limit to 2 jobs (<8GB RAM) [Default]")
print("  2) Limit to 4 jobs (8-16GB RAM)")
print("  3) Custom number of jobs")
print("  0) Unlimited / System Default")
io.write(C.cyan .. "Choose option [1]: " .. C.reset)
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

if num_jobs then
  rpmbuild_jobs_flag = string.format("--define '_smp_mflags -j%s'", num_jobs)
else
  print(C.yellow .. "--> Warning: Using default system threads." .. C.reset)
end

print(string.format("\n%s============================================================%s", C.magenta, C.reset))
print(C.bold .. "PACKAGE SELECTION MENU" .. C.reset)
print(string.format("%s============================================================%s", C.magenta, C.reset))
for i, mod in ipairs(config.all_modules) do
  print(string.format(" %s%2d)%s %s", C.yellow, i, C.reset, mod.dir))
end
print(C.green .. "  0) ALL PACKAGES (Default)" .. C.reset)
print(string.format("%s============================================================%s", C.magenta, C.reset))

io.write(C.cyan .. "Enter numbers or 0 for ALL [0]: " .. C.reset)
local ans_pkgs = io.read("*l")

local modules_to_compile = {}
if ans_pkgs == "" or ans_pkgs:match("^%s*0%s*$") or ans_pkgs:lower():match("all") then
  modules_to_compile = config.all_modules
else
  local single_idx = tonumber(ans_pkgs)
  if single_idx and config.all_modules[single_idx] then
    table.insert(modules_to_compile, config.all_modules[single_idx])
  else
    for num_str in ans_pkgs:gmatch("%d+") do
      local idx = tonumber(num_str)
      if idx and config.all_modules[idx] then table.insert(modules_to_compile, config.all_modules[idx]) end
    end
  end
  if #modules_to_compile == 0 then modules_to_compile = config.all_modules end
end

local changelog_date = os.date("%a %b %d %Y")
local total_modules = #modules_to_compile

for index, module in ipairs(modules_to_compile) do
  print("\n")
  print(C.cyan .. "==============================================================" .. C.reset)
  print(string.format("%s PROGRESS: [%2d / %2d]  ──>  Processing: %-18s %s", C.cyan, index, total_modules, module.dir, C.reset))
  print(C.cyan .. "==============================================================" .. C.reset)

  if module.core_deps and #module.core_deps > 0 then
    print(string.format("%s--> 🔄 Starting recursive dependency chain for %s...%s", C.yellow, module.dir, C.reset))
    local visited_chain = {}
    for _, dep in ipairs(module.core_deps) do
      utils.install_pkg_and_deps(dep, visited_chain)
    end
  end

  local module_src = config.WORK_DIR .. "/" .. module.dir
  local rpm_name = module.dir:lower()
  local specific_reqs = module.build_reqs or ""

  if specific_reqs ~= "" then
    print(string.format("%s--> 📥 Installation build requirements for %s...%s", C.yellow, module.dir, C.reset))
    utils.run(string.format("dnf install -y --skip-unavailable %s", specific_reqs))
  end

  local is_git = module.url:match("%.git$")
  local module_version = "0.0.0"
  local tarball_name = ""

  if is_git then
    utils.run(string.format("git clone --recursive %s %s", module.url, module_src))

    local checkout_cmd = string.format([[
      cd %s &&
      LATEST_TAG=$(git tag -l 'v[0-9]*' --sort=-v:refname | head -n 1)
      [ -z "$LATEST_TAG" ] && LATEST_TAG=$(git tag -l | sort -V | tail -n 1)
      if [ -n "$LATEST_TAG" ]; then
        git checkout "$LATEST_TAG" 2>/dev/null
        git submodule update --init --recursive
      fi
    ]], module_src)
    utils.run(checkout_cmd)

    module_version = utils.get_pkg_version(module_src)
    tarball_name = string.format("%s-%s.tar.gz", rpm_name, module_version)
    utils.run(string.format("tar --exclude='.git' -czf %s/SOURCES/%s -C %s .", config.RPMBUILD_DIR, tarball_name, module_src))
  else
    utils.run(string.format("mkdir -p %s", module_src))
    module_version = "3.3.0"
    tarball_name = "CascadiaMono.zip"
    print(string.format("%s--> Download diretto di %s in SOURCES...%s", C.yellow, module.url, C.reset))
    utils.run(string.format("curl -L -fLo %s/SOURCES/%s %s", config.RPMBUILD_DIR, tarball_name, module.url))
  end

  utils.set_compiled_version(module.dir, module_version)
  print(string.format("%s--> Calculated Version: %s%s", C.green, module_version, C.reset))

  local deps_hash = utils.get_deps_hash(module.core_deps)

  local search_pattern = string.format("%s-%s-1.*.rpm", rpm_name, module_version)
  local cmd = string.format("ls %s/%s 2>/dev/null | grep '_%s' | head -n 1", config.RESULTS_DIR, search_pattern, deps_hash)
  local h_check = io.popen(cmd)
  local existing_rpm = ""

  if h_check then
      local content = h_check:read("*a")
      h_check:close()
      if content then existing_rpm = content:gsub("%s+", "") end
  end

  if existing_rpm ~= "" then
    print(string.format("\n%s[=] MATCH: Existing RPM with the same version and identical dependencies%s", C.green, C.reset))
    print(string.format("%s--> Skip compilation and install: %s%s", C.green, existing_rpm, C.reset))
    utils.run(string.format("dnf install -y --allowerasing %s/%s*.rpm", config.RESULTS_DIR, rpm_name))
  else
    print(string.format("\n%s[+] No valid RPM found for %s (version or dependencies changed).%s", C.yellow, rpm_name, C.reset))

    local build_time = os.date("%Y%m%d%H%M")
    local rpm_release = string.format("1.%s_%s", build_time, deps_hash)
    print(string.format("%s--> Generating new build Release: %s%s", C.yellow, rpm_release, C.reset))

    tarball_name = ""
    if module.dir == "caskaydia-mono-nerd-fonts" then
      tarball_name = "CascadiaMono.zip"
    else
      tarball_name = string.format("%s-%s.tar.gz", rpm_name, module_version)
      utils.run(string.format("tar --exclude='.git' -czf %s/SOURCES/%s -C %s .", config.RPMBUILD_DIR, tarball_name, module_src))
    end

    local target_spec_file = config.RPMBUILD_DIR .. "/SPECS/" .. rpm_name .. ".spec"
    local custom_spec_path = config.SPECS_DIR .. "/" .. rpm_name .. ".spec"

    -- Gestione spec personalizzato obbligatorio
    local custom_spec_file = io.open(custom_spec_path, "r")
    if custom_spec_file then
      custom_spec_file:close()
      print(string.format("%s--> Found .spec file: %s%s", C.magenta, custom_spec_path, C.reset))
      utils.run(string.format("cp -f %s %s", custom_spec_path, target_spec_file))
    else
      print(string.format("\n%s[!] FATAL ERROR: Missing .spec file for %s in '%s/'%s", C.red, rpm_name, config.SPECS_DIR, C.reset))
      os.exit(1)
    end

    print(string.format("%s--> RPM compilation in progress...%s", C.yellow, C.reset))
    utils.run(string.format("rpmbuild %s --define 'module_version %s' --define 'module_release %s' --define 'source_tarball %s' -bb --nodeps %s", rpmbuild_jobs_flag, module_version, rpm_release, tarball_name, target_spec_file))

    utils.run(string.format("rm -f %s/%s-*.rpm", config.RESULTS_DIR, rpm_name))
    utils.run(string.format("find %s/RPMS -name '%s-*.rpm' -exec cp -f {} %s/ \\;", config.RPMBUILD_DIR, rpm_name, config.RESULTS_DIR))

    print(string.format("%s--> System package installation test...%s", C.yellow, C.reset))
    utils.run(string.format("dnf install -y --allowerasing %s/%s*.rpm", config.RESULTS_DIR, rpm_name))
  end
end

print(string.format("\n%s============================================================%s", C.green, C.reset))
print(C.bold .. C.green .. "SUCCESS" .. C.reset)
print(string.format("%s============================================================%s", C.green, C.reset))
print("RPM saved in: " .. config.RESULTS_DIR)

--------------------------------------------------------------------------------
-- GENERAZIONE METAPACCHETTO hyprland-desktop
--------------------------------------------------------------------------------
print(string.format("\n%s============================================================%s", C.magenta, C.reset))
print(C.bold .. "--> Generation of the all-hyprland-desktop metapackage..." .. C.reset)
print(string.format("%s============================================================%s", C.magenta, C.reset))

local meta_spec = config.RPMBUILD_DIR .. "/SPECS/all-hyprland-desktop.spec"
local meta_f = io.open(meta_spec, "w")

if meta_f then
    meta_f:write(string.format([[
Name:           all-hyprland-desktop
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
Requires:       superfile

%%description
Meta-package to install the complete Hyprland desktop environment suite.

%%files

%%changelog
* %s builder <builder@localhost> - 1.0-1
- Initial meta-package release
]], changelog_date))

    meta_f:close()
else
    error("Unable to open the file for writing: " .. tostring(meta_spec))
end

utils.run("rpmbuild -bb " .. meta_spec)
utils.run("cp -f " .. config.RPMBUILD_DIR .. "/RPMS/noarch/all-hyprland-desktop-*.rpm " .. config.RESULTS_DIR .. "/")
