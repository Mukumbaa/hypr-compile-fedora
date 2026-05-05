-- Set up questions
print("============================================================")
print("       SCRIPT TO COMPILE & PACKAGE HYPRLAND (RPM)    ")
print("============================================================\n")

print("This script will compile selected modules into individual staging directories")
print("and package them into native Fedora .rpm files sequentially.\n")

local checkout_cmd = "echo '-> Compiling latest git commit'"
print("-> Target: Last git commit (master/main)")

-- Unified table containing EVERY package in the correct dependency order
local all_modules = {
    {url="https://github.com/hyprwm/hyprwayland-scanner.git", dir="hyprwayland-scanner"},
    {url="https://github.com/hyprwm/hyprutils.git", dir="hyprutils"},
    {url="https://github.com/hyprwm/hyprlang.git", dir="hyprlang"},
    {url="https://github.com/hyprwm/hyprcursor.git", dir="hyprcursor"},
    {url="https://github.com/hyprwm/hyprgraphics.git", dir="hyprgraphics"},
    {url="https://github.com/hyprwm/aquamarine.git", dir="aquamarine"},
    {url="https://github.com/hyprwm/hyprwire.git", dir="hyprwire"},
    {url="https://github.com/hyprwm/hyprtoolkit.git", dir="hyprtoolkit"},
    {url="https://github.com/hyprwm/hyprland-guiutils.git", dir="hyprland-guiutils"},
    {url="https://github.com/hyprwm/hyprland-protocols.git", dir="hyprland-protocols"},
    {url="https://github.com/hyprwm/xdg-desktop-portal-hyprland.git", dir="xdg-desktop-portal-hyprland"},
    {url="https://github.com/hyprwm/Hyprland.git", dir="Hyprland"},
    {url="https://github.com/hyprwm/hyprpaper.git", dir="hyprpaper"},
    {url="https://github.com/hyprwm/hyprlock.git", dir="hyprlock"},
    {
        url="https://github.com/Vladimir-csp/uwsm.git", 
        dir="uwsm", 
        extra_args="-Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled -Dttyautolock=enabled"
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

io.write("Enter numbers separated by commas (e.g., 12,13,14) or 0 for ALL [0]: ")
local ans_pkgs = io.read("*l")

local modules_to_compile = {}

-- Parse user input
if ans_pkgs == "" or ans_pkgs:match("0") or ans_pkgs:lower():match("all") then
    modules_to_compile = all_modules
    print("\n-> Selected: ALL PACKAGES")
else
    print("\n-> Selected:")
    -- Extract all numbers from the input string
    for num_str in ans_pkgs:gmatch("%d+") do
        local idx = tonumber(num_str)
        if idx and all_modules[idx] then
            table.insert(modules_to_compile, all_modules[idx])
            print("   - " .. all_modules[idx].dir)
        end
    end
    
    -- Fallback if they typed something invalid
    if #modules_to_compile == 0 then
        print("[!] No valid numbers detected. Defaulting to ALL PACKAGES.")
        modules_to_compile = all_modules
    end
end

print("\n============================================================")
os.execute("sleep 2")

local function run(cmd)
    print("\n------------------------------------------------------------")
    print("Executing: " .. cmd:match("([^\n]+)"))
    print("------------------------------------------------------------")

    local success, reason, status = os.execute(cmd)

    local failed = false
    if type(success) == "number" and success ~= 0 then failed = true end
    if success == nil or success == false then failed = true end

    if failed then
        print("\n[!] FATAL ERROR:")
        print("Command: \n" .. cmd)
        os.exit(1)
    end
end

-- Function to dynamically get the exact version from Git for the RPM
local function get_pkg_version(folder)
    local handle = io.popen(string.format("cd %s && git describe --tags --always 2>/dev/null", folder))
    local ver = handle:read("*a")
    handle:close()
    
    -- Clean up string
    ver = ver:gsub("\n", "")
    ver = ver:gsub("^v", "") -- Remove leading 'v' (v0.41.0 -> 0.41.0)
    ver = ver:gsub("-", ".") -- RPM versions CANNOT contain hyphens
    
    if ver == "" then ver = "0.0.0.unknown" end
    
    -- RPM versions must ideally start with a number. If it's just a raw hash, prepend 0.0.0.
    if not ver:match("^%d") then
        ver = "0.0.0." .. ver
    end
    
    return ver
end

-- system update
print("--> System update...")
run("sudo dnf upgrade --refresh -y")

local dnf_packages = {
  "git", "meson", "cmake", "ninja-build", "gcc-c++", "pkgconfig",
  "wayland-devel", "wayland-protocols-devel", "pango-devel",
  "cairo-devel", "file-devel", "libglvnd-devel", "libglvnd-core-devel",
  "libjpeg-turbo-devel", "libwebp-devel", "libinput-devel",
  "libxkbcommon-devel", "libdrm-devel", "mesa-libGLES-devel",
  "libseat-devel", "libliftoff-devel", "libdisplay-info-devel",
  "tomlplusplus-devel", "re2-devel", "muParser-devel", "libxcb-devel",
  "libX11-devel", "pixman-devel", "gdb", "xcb-util-devel",
  "xcb-util-keysyms-devel", "xcb-util-wm-devel", "xcb-util-errors-devel",
  "glslang-devel", "vulkan-devel", "egl-wayland-devel", "pugixml",
  "pugixml-devel", "libzip-devel", "librsvg2-devel", "mesa-libgbm-devel",
  "hwdata", "hwdata-devel", "uuid", "uuid-devel", "libuuid-devel",
  "libXcursor-devel", "iniparser", "iniparser-devel", "qt6-qtbase-devel",
  "qt6-qtwayland-devel", "pipewire-devel", "pipewire", "pipewire-libs",
  "pkgconf-pkg-config", "sdbus-cpp-devel", "systemd-devel", "dbus-devel",
  "pam-devel", "scdoc",

  -- FPM & Python requirements
  "ruby", "ruby-devel", "rpm-build", "python3"
}

print("--> Installing dependencies...")
run("sudo dnf install -y " .. table.concat(dnf_packages, " "))

print("--> Installing FPM (RubyGem for Packaging)...")
run("sudo gem install fpm --no-document")

-- We keep a table to track all the RPMs we generate
local generated_rpms = {}

local function build_and_package_module(repo_url, folder_name, extra_args)
    print("\n============================================================")
    print("--> Compiling & Packaging: " .. folder_name)
    print("============================================================")
    
    local module_build_root = os.getenv("HOME") .. "/build_root_" .. folder_name
    local args = extra_args or ""
    os.execute("rm -rf " .. module_build_root)
    os.execute("mkdir -p " .. module_build_root)

    -- 1. Clone & Checkout
    local clone_cmd = string.format([[
        rm -rf %s
        git clone --recursive %s
        cd %s
        %s
    ]], folder_name, repo_url, folder_name, checkout_cmd)
    run(clone_cmd)

    -- 2. Get dynamic version of the cloned repo
    local module_version = get_pkg_version(folder_name)
    print("--> Detected Package Version: " .. module_version)

    -- 3. SMART Auto-Detect Compile & Install to Staging Root
    local build_cmd = string.format([[
        cd %s
        if [ -f "CMakeLists.txt" ]; then
            echo "-> CMake build system detected"
            cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release %s -B build
            cmake --build build -j$(nproc)
            DESTDIR=%s cmake --install build
        elif [ -f "meson.build" ]; then
            echo "-> Meson build system detected"
            meson setup --prefix=/usr %s build
            DESTDIR=%s meson install -C build
        else
            echo "Error: Neither CMakeLists.txt nor meson.build found in %s!"
            exit 1
        fi
    ]], folder_name, args, module_build_root, args, module_build_root, folder_name)
    run(build_cmd)

    -- 4. Package into RPM using FPM and the dynamic version
    local rpm_name = folder_name:lower()
    local fpm_cmd = string.format([[
        fpm -s dir -t rpm -n %s -v %s \
        --provides %s \
        --conflicts %s \
        -C %s \
        --force \
        .
    ]], rpm_name, module_version, rpm_name, rpm_name, module_build_root)
    run(fpm_cmd)
    
    -- RPMs generated by FPM end with -1.x86_64.rpm
    local rpm_file = string.format("%s-%s-1.x86_64.rpm", rpm_name, module_version)
    table.insert(generated_rpms, rpm_file)

    -- 5. Install the newly created RPM immediately so the next modules can use it as a dependency
    print("--> Installing " .. rpm_name .. " via DNF to satisfy future dependencies...")
    run("sudo dnf install -y ./" .. rpm_file)

    -- 6. Cleanup staging root
    os.execute("rm -rf " .. module_build_root)
end

-- Execute the build loop ONLY for the selected modules
for _, module in ipairs(modules_to_compile) do
    build_and_package_module(module.url, module.dir, module.extra_args)
end

print("\n============================================================")
print("SUCCESS! ALL REQUESTED RPMS GENERATED AND INSTALLED.")
print("============================================================")
print("The following RPM files are now in your current directory:")
for _, rpm in ipairs(generated_rpms) do
    print(" - " .. rpm)
end
print("\nYou can back these up or move them to a dedicated folder.")
print("To uninstall them in the future, just run:")
print("sudo dnf remove hyprland hyprutils aquamarine ...etc")
