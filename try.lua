-- Set up questions
print("============================================================")
print("       SCRIPT TO COMPILE & PACKAGE HYPRLAND (RPM METHOD)    ")
print("============================================================\n")

print("This script will compile all modules into a staging directory")
print("and package them into a native Fedora .rpm file.\n")

io.write("1. Do you want to compile -git [g] or release [r]? (g/r)[default: g]: ")
local ans_ver = io.read("*l"):lower()
local is_release = (ans_ver == "r")

io.write("2. Do you want to automatically install the RPM via DNF after building? (y/n)[default: y]: ")
local ans_install = io.read("*l"):lower()
local auto_install = (ans_install ~= "n")

print("\n============================================================")

-- Setup Build Root (Staging directory)
local home = os.getenv("HOME")
local build_root = home .. "/hyprland_build_root"
os.execute("rm -rf " .. build_root)
os.execute("mkdir -p " .. build_root)

local cmake_install_cmd = string.format("DESTDIR=%s cmake --install", build_root)
local meson_install_cmd = string.format("DESTDIR=%s meson install", build_root)
local checkout_cmd = ""
local version_str = "git"

-- version logic with safe fallback for repos without tags
if is_release then
    version_str = "stable"
    checkout_cmd = [[
        tag=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null)
        if[ -n "$tag" ]; then
            git checkout "$tag"
            echo "-> Checked out tag: $tag"
        else
            echo "-> No tag found, staying on main branch"
        fi
    ]]
    print("-> Target: Last release (Stable)")
else
    checkout_cmd = "echo '-> Compiling latest git commit'"
    print("-> Target: Last git commit (master/main)")
end

print("-> Build Root: " .. build_root)
print("============================================================\n")
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

-- system update
print("--> System update...")
run("sudo dnf upgrade --refresh -y")

local dnf_packages = {
  "git",
  "meson",
  "cmake",
  "ninja-build",
  "gcc-c++",
  "pkgconfig",

  "wayland-devel",
  "wayland-protocols-devel",
  "pango-devel",

  "cairo-devel",
  "file-devel",
  "libglvnd-devel",
  "libglvnd-core-devel",

  "libjpeg-turbo-devel",
  "libwebp-devel",
  "libinput-devel",

  "libxkbcommon-devel",
  "libdrm-devel",
  "mesa-libGLES-devel",

  "libseat-devel",
  "libliftoff-devel",
  "libdisplay-info-devel",

  "tomlplusplus-devel",
  "re2-devel",
  "muParser-devel",
  "libxcb-devel",

  "libX11-devel",
  "pixman-devel",
  "gdb",
  "xcb-util-devel",

  "xcb-util-keysyms-devel",
  "xcb-util-wm-devel",
  "xcb-util-errors-devel",

  "glslang-devel",
  "vulkan-devel",
  "egl-wayland-devel",
  "pugixml",

  "pugixml-devel",
  "libzip-devel",
  "librsvg2-devel",
  "mesa-libgbm-devel",

  "hwdata",
  "hwdata-devel",
  "uuid",
  "uuid-devel",
  "libuuid-devel",

  "libXcursor-devel",
  "iniparser",
  "iniparser-devel",
  "qt6-qtbase-devel",

  "qt6-qtwayland-devel",
  "pipewire-devel",
  "pipewire",
  "pipewire-libs",

  "pkgconf-pkg-config",
  "sdbus-cpp-devel",
  "systemd-devel",
  "dbus-devel",

  "pam-devel",
  "scdoc",

  -- FPM & Python requirements
  "ruby",
  "ruby-devel",
  "rpm-build",
  "python3"
}

print("--> Installing dependencies...")
run("sudo dnf install -y " .. table.concat(dnf_packages, " "))

local function build_hypr_module(repo_url, folder_name)
    print("--> Compiling: " .. folder_name)
    local cmd = string.format([[
        rm -rf %s
        git clone %s
        cd %s
        %s
        cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
        cmake --build build -j$(nproc)
        %s build
    ]], folder_name, repo_url, folder_name, checkout_cmd, cmake_install_cmd)
    run(cmd)
end

local hypr_modules = {
    {url="https://github.com/hyprwm/hyprwayland-scanner.git", dir="hyprwayland-scanner"},
    {url="https://github.com/hyprwm/hyprutils.git", dir="hyprutils"},
    {url="https://github.com/hyprwm/hyprlang.git", dir="hyprlang"},
    {url="https://github.com/hyprwm/hyprcursor.git", dir="hyprcursor"},
    {url="https://github.com/hyprwm/hyprgraphics.git", dir="hyprgraphics"},
    {url="https://github.com/hyprwm/aquamarine.git", dir="aquamarine"},
    {url="https://github.com/hyprwm/hyprwire.git", dir="hyprwire"},
    {url="https://github.com/hyprwm/hyprtoolkit.git", dir="hyprtoolkit"},
    {url="https://github.com/hyprwm/hyprland-guiutils.git", dir="hyprland-guiutils"},
    {url="https://github.com/hyprwm/hyprland-protocols", dir="hyprland-protocols"},
    {url="https://github.com/hyprwm/xdg-desktop-portal-hyprland.git", dir="xdg-desktop-portal-hyprland"}
}

for _, module in ipairs(hypr_modules) do
    build_hypr_module(module.url, module.dir)
end


print("--> Compiling: Hyprland")
run(string.format([[
    rm -rf Hyprland
    git clone --recursive https://github.com/hyprwm/Hyprland
    cd Hyprland
    %s
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -B build
    cmake --build ./build --config Release --target all -j$(nproc)
    %s ./build
]], checkout_cmd, cmake_install_cmd))

print("--> Compiling: hyprpaper")
run(string.format([[
    rm -rf hyprpaper
    git clone https://github.com/hyprwm/hyprpaper.git
    cd hyprpaper
    %s
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
    cmake --build ./build --config Release --target hyprpaper -j$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)
    %s ./build
]], checkout_cmd, cmake_install_cmd))

print("--> Compiling: hyprlock")
run(string.format([[
    rm -rf hyprlock
    git clone https://github.com/hyprwm/hyprlock.git
    cd hyprlock
    %s
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
    cmake --build ./build --config Release --target hyprlock -j$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)
    %s ./build
]], checkout_cmd, cmake_install_cmd))

print("--> Compiling: uwsm")
run(string.format([[
    rm -rf uwsm
    git clone https://github.com/Vladimir-csp/uwsm.git
    cd uwsm
    %s
    meson setup --prefix=/usr -Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled -Dttyautolock=enabled build
    %s -C build
]], checkout_cmd, meson_install_cmd))


-- RPM PACKAGING PHASE
print("\n============================================================")
print("--> PREPARING RPM PACKAGE")
print("============================================================")

print("--> Installing FPM (RubyGem for Packaging)...")
run("sudo gem install fpm --no-document")

local rpm_name = "hyprland-custom"
local rpm_file_pattern = string.format("%s-%s-*.rpm", rpm_name, version_str)

-- Clean up any old RPMs in the current directory to know exactly which one were just built
os.execute("rm -f " .. rpm_file_pattern)

print("--> Running FPM to build the RPM...")
local fpm_cmd = string.format([[
    fpm -s dir -t rpm -n %s -v %s \
    --description "Custom compiled Hyprland Ecosystem" \
    --provides hyprland \
    --conflicts hyprland \
    -C %s \
    --force \
    .
]], rpm_name, version_str, build_root)
run(fpm_cmd)

print("\n============================================================")
print("RPM GENERATION COMPLETED")
print("============================================================")

if auto_install then
    print("--> Installing the generated RPM via DNF...")
    -- Standard DNF local install
    run("sudo dnf install -y ./" .. rpm_file_pattern)
    print("\n[SUCCESS] Hyprland was successfully installed via DNF")
    print("To uninstall in the future, simply run: sudo dnf remove " .. rpm_name)
else
    print("\n[SUCCESS] RPM created successfully in your current directory")
    print("You can distribute it or install it later by running:")
    print("sudo dnf install ./" .. rpm_name .. "-" .. version_str .. "-1.x86_64.rpm")
end

-- Optional cleanup of the staging root
os.execute("rm -rf " .. build_root)
