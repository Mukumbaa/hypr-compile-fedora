-- modules/utils.lua
local C = require("modules.colors")
local config = require("modules.config")
local M = {}

local compiled_versions = {}

function M.run(cmd)
  print(string.format("\n%s------------------------------------------------------------%s", C.gray, C.reset))
  print(C.cyan .. "Executing: " .. C.reset .. cmd:match("([^\n]+)"))
  print(string.format("%s------------------------------------------------------------%s", C.gray, C.reset))

  local success, _, _ = os.execute(cmd)
  local failed = false
  if type(success) == "number" and success ~= 0 then failed = true end
  if success == nil or success == false then failed = true end

  if failed then
    print(string.format("\n%s[!] FATAL ERROR executing command:%s\n%s", C.red, C.reset, cmd))
    os.exit(1)
  end
end

-- function M.resolve_dep_version(dep_dir)
--   if compiled_versions[dep_dir] then
--     return compiled_versions[dep_dir]
--   end
--
--   local rpm_path = ""
--   local cmd = string.format("ls %s/%s-*.rpm 2>/dev/null | head -n 1", config.RESULTS_DIR, dep_dir:lower())
--   local h = io.popen(cmd)
--
--   if h then
--       local content = h:read("*a")
--       h:close()
--       if content then rpm_path = content:gsub("%s+", "") end
--   end
--
--   if rpm_path ~= "" then
--     local ver = rpm_path:match(dep_dir:lower() .. "%-(%d+[%d%.]*)%-")
--     if ver then return ver end
--   end
--
--   return "0"
-- end
function M.resolve_dep_version(dep_dir)
  if compiled_versions[dep_dir] then
    return compiled_versions[dep_dir]
  end

  local rpm_path = ""
  -- [0-9] intercetta solo la versione: isola hyprland ed esclude hyprland-guiutils, hyprland-devel, ecc.
  local cmd = string.format("ls %s/%s-[0-9]*.rpm 2>/dev/null | head -n 1", config.RESULTS_DIR, dep_dir:lower())
  local h = io.popen(cmd)

  if h then
      local content = h:read("*a")
      h:close()
      if content then rpm_path = content:gsub("%s+", "") end
  end

  if rpm_path ~= "" then
    local ver = rpm_path:match(dep_dir:lower() .. "%-(%d+[%d%.]*)%-")
    if ver then return ver end
  end

  return "0"
end


function M.get_deps_hash(deps_list)
  if not deps_list or #deps_list == 0 then return "base" end
  local str = ""
  for _, dep_dir in ipairs(deps_list) do
    str = str .. dep_dir .. "=" .. M.resolve_dep_version(dep_dir) .. ";"
  end
  
  local hash = ""
  local cmd = string.format("echo -n '%s' | md5sum | cut -c1-7", str)
  local h = io.popen(cmd)

  if h then
      local content = h:read("*a")
      h:close()
      if content then hash = content:gsub("%s+", "") end
  end

  return hash
end

function M.get_pkg_version(repo_dir)
  local cmd = string.format("cd %s && (git tag -l 'v[0-9]*' --sort=-v:refname | head -n 1 || git tag -l | sort -V | tail -n 1 || echo '0.0.0')", repo_dir)
  local h = io.popen(cmd)
  local ver = ""

  if h then
    local content = h:read("*a")
    h:close()
    if content then ver = content:gsub("%s+", "") end
  end

  ver = ver:gsub("^v", ""):gsub("-", ".")
  return (ver ~= "" and ver) or "0.0.0"
end

function M.set_compiled_version(dir, ver)
  compiled_versions[dir] = ver
end

function M.find_module_by_dir(dir_name)
  if not config.all_modules then return nil end
  for _, mod in ipairs(config.all_modules) do
    if mod.dir and mod.dir:lower() == dir_name:lower() then
      return mod
    end
  end
  return nil
end

-- Funzione centralizzata per compilare un modulo
function M.build_module(module, rpmbuild_jobs_flag, changelog_date)
  changelog_date = changelog_date or os.date("%a %b %d %Y")
  local module_src = config.WORK_DIR .. "/" .. module.dir
  local rpm_name = module.dir:lower()
  local specific_reqs = module.build_reqs or ""

  if specific_reqs ~= "" then
    print(string.format("%s--> 📥 Installation build requirements for %s...%s", C.yellow, module.dir, C.reset))
    M.run(string.format("dnf install -y --skip-unavailable %s", specific_reqs))
  end

  local is_git = module.url:match("%.git$")
  local module_version = "0.0.0"
  local tarball_name = ""

  if is_git then
    M.run(string.format("git clone --recursive %s %s", module.url, module_src))

    local checkout_cmd = string.format([[
      cd %s &&
      LATEST_TAG=$(git tag -l 'v[0-9]*' --sort=-v:refname | head -n 1)
      [ -z "$LATEST_TAG" ] && LATEST_TAG=$(git tag -l | sort -V | tail -n 1)
      if [ -n "$LATEST_TAG" ]; then
        git checkout "$LATEST_TAG" 2>/dev/null
        git submodule update --init --recursive
      fi
    ]], module_src)
    M.run(checkout_cmd)

    module_version = M.get_pkg_version(module_src)
    tarball_name = string.format("%s-%s.tar.gz", rpm_name, module_version)
    M.run(string.format("tar --exclude='.git' -czf %s/SOURCES/%s -C %s .", config.RPMBUILD_DIR, tarball_name, module_src))
  else
    M.run(string.format("mkdir -p %s", module_src))

    if module.dir == "caskaydia-mono-nerd-fonts" then
      module_version = "3.3.0"
      tarball_name = "CascadiaMono.zip"
    elseif module.dir == "starship" then
      module_version = "1.26.0" -- Puoi aggiornare la versione o estrarla dall'URL
      tarball_name = "starship-1.26.0.tar.gz"
    else
      module_version = "1.0.0"
      tarball_name = rpm_name .. "-" .. module_version .. ".tar.gz"
    end

    print(string.format("%s--> Download diretto di %s in SOURCES...%s", C.yellow, module.url, C.reset))
    M.run(string.format("curl -L -fLo %s/SOURCES/%s %s", config.RPMBUILD_DIR, tarball_name, module.url))
  end

  M.set_compiled_version(module.dir, module_version)
  print(string.format("%s--> Calculated Version: %s%s", C.green, module_version, C.reset))

  local deps_hash = M.get_deps_hash(module.core_deps)
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
    -- M.run(string.format("dnf install -y --allowerasing %s/%s*.rpm", config.RESULTS_DIR, rpm_name))
    M.run(string.format("find %s -maxdepth 1 -name '%s-[0-9]*.rpm' -exec dnf install -y --allowerasing {} +", config.RESULTS_DIR, rpm_name))
  else
    print(string.format("\n%s[+] No valid RPM found for %s (version or dependencies changed).%s", C.yellow, rpm_name, C.reset))

    local build_time = os.date("%Y%m%d%H%M")
    local rpm_release = string.format("1.%s_%s", build_time, deps_hash)
    print(string.format("%s--> Generating new build Release: %s%s", C.yellow, rpm_release, C.reset))

    if module.dir ~= "caskaydia-mono-nerd-fonts" and module.dir ~= "starship" then
      tarball_name = string.format("%s-%s.tar.gz", rpm_name, module_version)
      M.run(string.format("tar --exclude='.git' -czf %s/SOURCES/%s -C %s .", config.RPMBUILD_DIR, tarball_name, module_src))
    end

    local target_spec_file = config.RPMBUILD_DIR .. "/SPECS/" .. rpm_name .. ".spec"
    local custom_spec_path = config.SPECS_DIR .. "/" .. rpm_name .. ".spec"

    local custom_spec_file = io.open(custom_spec_path, "r")
    if custom_spec_file then
      custom_spec_file:close()
      print(string.format("%s--> Found .spec file: %s%s", C.magenta, custom_spec_path, C.reset))
      M.run(string.format("cp -f %s %s", custom_spec_path, target_spec_file))
    else
      print(string.format("\n%s[!] FATAL ERROR: Missing .spec file for %s in '%s/'%s", C.red, rpm_name, config.SPECS_DIR, C.reset))
      os.exit(1)
    end

--     print(string.format("%s--> RPM compilation in progress...%s", C.yellow, C.reset))
--     M.run(string.format("rpmbuild %s --define 'module_version %s' --define 'module_release %s' --define 'source_tarball %s' -bb --nodeps %s", rpmbuild_jobs_flag or "", module_version, rpm_release, tarball_name, target_spec_file))
--
--     M.run(string.format("rm -f %s/%s-*.rpm", config.RESULTS_DIR, rpm_name))
--     M.run(string.format("find %s/RPMS -name '%s-*.rpm' -exec cp -f {} %s/ \\;", config.RPMBUILD_DIR, rpm_name, config.RESULTS_DIR))
--
--     print(string.format("%s--> System package installation test...%s", C.yellow, C.reset))
--     M.run(string.format("dnf install -y --allowerasing %s/%s*.rpm", config.RESULTS_DIR, rpm_name))
--   end
-- end
    print(string.format("%s--> RPM compilation in progress...%s", C.yellow, C.reset))

    -- 1. Svuota la cartella RPMS temporanea prima della compilazione
    M.run(string.format("rm -rf %s/RPMS/*", config.RPMBUILD_DIR))

    -- 2. Compila il pacchetto
    M.run(string.format("rpmbuild %s --define 'module_version %s' --define 'module_release %s' --define 'source_tarball %s' -bb --nodeps %s", rpmbuild_jobs_flag or "", module_version, rpm_release, tarball_name, target_spec_file))

    -- 3. Rimuove in /output SOLO le versioni precedenti di questo modulo e dei suoi subpacchetti, interrogando gli RPM appena generati
    M.run(string.format([[
      for rpm in $(find %s/RPMS -name "*.rpm"); do
        pkg_name=$(rpm -qp --qf '%%{NAME}' "$rpm")
        rm -f %s/${pkg_name}-[0-9]*.rpm
      done
    ]], config.RPMBUILD_DIR, config.RESULTS_DIR))

    -- 4. Copia tutti i pacchetti generati (principali e sub-package) in /output
    M.run(string.format("find %s/RPMS -name '*.rpm' -exec cp -f {} %s/ \\;", config.RPMBUILD_DIR, config.RESULTS_DIR))

    -- 5. Testa l'installazione installando ESCLUSIVAMENTE gli RPM appena prodotti
    print(string.format("%s--> System package installation test...%s", C.yellow, C.reset))
    M.run(string.format("find %s/RPMS -name '*.rpm' -exec dnf install -y --allowerasing {} +", config.RPMBUILD_DIR))
  end
end




-- Gestione ricorsiva delle dipendenze con compilazione automatica al volo se mancanti
function M.install_pkg_and_deps(dir_name, visited, rpmbuild_jobs_flag, changelog_date)
  visited = visited or {}
  if visited[dir_name] then return end
  visited[dir_name] = true

  local mod = M.find_module_by_dir(dir_name)
  if not mod then return end

  -- 1. Risolve prima le dipendenze figlie ricorsivamente
  if mod.core_deps and #mod.core_deps > 0 then
    for _, dep in ipairs(mod.core_deps) do
      M.install_pkg_and_deps(dep, visited, rpmbuild_jobs_flag, changelog_date)
    end
  end

  -- local rpm_name = dir_name:lower()
  --
  -- -- 2. Verifica se l'RPM della dipendenza esiste già in /output
  -- local cmd = string.format("ls %s/%s-*.rpm 2>/dev/null | head -n 1", config.RESULTS_DIR, rpm_name)
  -- local h = io.popen(cmd)
  -- local rpm_exists = false
  -- if h then
  --   local content = h:read("*a")
  --   h:close()
  --   if content and content:gsub("%s+", "") ~= "" then
  --     rpm_exists = true
  --   end
  -- end
  --
  -- -- 3. Se esiste lo installa, altrimenti lo compila al volo!
  -- if rpm_exists then
  --   print(string.format("\n%s--> 📦 [Dep-Tree] Installing existing dependency: %s%s", C.blue, dir_name, C.reset))
  --   M.run(string.format("find %s -maxdepth 1 -name '%s-*.rpm' ! -name '*-devel-*.rpm' -exec dnf install -y --allowerasing {} + 2>/dev/null || true", config.RESULTS_DIR, rpm_name))
  --   M.run(string.format("find %s -maxdepth 1 -name '%s-devel-*.rpm' -exec dnf install -y --allowerasing {} + 2>/dev/null || true", config.RESULTS_DIR, rpm_name))
  -- else
  --   print(string.format("\n%s--> ⚠️ [Dep-Tree] Dependency package '%s' not found. Compiling on-the-fly...%s", C.yellow, dir_name, C.reset))
  --   M.build_module(mod, rpmbuild_jobs_flag, changelog_date)
  -- end
  local rpm_name = dir_name:lower()

  -- 2. Cerca SOLO il file la cui versione inizia con un numero (escludendo moduli con prefisso comune)
  local cmd = string.format("ls %s/%s-[0-9]*.rpm 2>/dev/null | head -n 1", config.RESULTS_DIR, rpm_name)
  local h = io.popen(cmd)
  local rpm_exists = false
  if h then
    local content = h:read("*a")
    h:close()
    if content and content:gsub("%s+", "") ~= "" then
      rpm_exists = true
    end
  end

  -- 3. Se esiste installa pacchetto e relativo devel in modo mirato
  if rpm_exists then
    print(string.format("\n%s--> 📦 [Dep-Tree] Installing existing dependency: %s%s", C.blue, dir_name, C.reset))
    M.run(string.format("find %s -maxdepth 1 -name '%s-[0-9]*.rpm' -exec dnf install -y --allowerasing {} + 2>/dev/null || true", config.RESULTS_DIR, rpm_name))
    M.run(string.format("find %s -maxdepth 1 -name '%s-devel-[0-9]*.rpm' -exec dnf install -y --allowerasing {} + 2>/dev/null || true", config.RESULTS_DIR, rpm_name))
  else
    print(string.format("\n%s--> ⚠️ [Dep-Tree] Dependency package '%s' not found. Compiling on-the-fly...%s", C.yellow, dir_name, C.reset))
    M.build_module(mod, rpmbuild_jobs_flag, changelog_date)
  end
end

return M
