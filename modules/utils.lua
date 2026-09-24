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

function M.resolve_dep_version(dep_dir)
  if compiled_versions[dep_dir] then
    return compiled_versions[dep_dir]
  end

  local rpm_path = ""
  local cmd = string.format("ls %s/%s-*.rpm 2>/dev/null | head -n 1", config.RESULTS_DIR, dep_dir:lower())
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

function M.install_pkg_and_deps(dir_name, visited)
  visited = visited or {}
  if visited[dir_name] then return end
  visited[dir_name] = true

  local mod = M.find_module_by_dir(dir_name)
  if not mod then return end

  if mod.core_deps and #mod.core_deps > 0 then
    for _, dep in ipairs(mod.core_deps) do
      M.install_pkg_and_deps(dep, visited)
    end
  end

  local rpm_name = dir_name:lower()
  print(string.format("\n%s 📦 [Dep-Tree] Resolving dependency: %s%s", C.blue, dir_name, C.reset))
  M.run(string.format("find %s -maxdepth 1 -name '%s-*.rpm' ! -name '*-devel-*.rpm' -exec dnf install -y --allowerasing {} + 2>/dev/null || true", config.RESULTS_DIR, rpm_name))
  M.run(string.format("find %s -maxdepth 1 -name '%s-devel-*.rpm' -exec dnf install -y --allowerasing {} + 2>/dev/null || true", config.RESULTS_DIR, rpm_name))
end

return M
