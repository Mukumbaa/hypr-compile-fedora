-- Forza la localizzazione temporale in formato standard inglese per evitare errori di data in RPM
os.setlocale("C", "time")
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

  -- Avvia la catena ricorsiva: se una dipendenza manca, viene compilata e installata automaticamente qui dentro
  if module.core_deps and #module.core_deps > 0 then
    print(string.format("%s--> 🔄 Starting recursive dependency chain for %s...%s", C.yellow, module.dir, C.reset))
    local visited_chain = {}
    for _, dep in ipairs(module.core_deps) do
      utils.install_pkg_and_deps(dep, visited_chain, rpmbuild_jobs_flag, changelog_date)
    end
  end

  -- Compila il modulo corrente tramite la funzione centralizzata
  utils.build_module(module, rpmbuild_jobs_flag, changelog_date)
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
Requires:       starship

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
