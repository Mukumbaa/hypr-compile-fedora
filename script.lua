-- Set up questions
print("============================================================")
print("                 SCRIPT TO COMPILE HYPRLAND")
print("============================================================\n")

-- Dir Q
io.write("1. Do you want to install on system [s] or create a folder to distribute [d]? (s/d) [default: s]: ")
local ans_dest = io.read("*l"):lower()
local is_distro = (ans_dest == "d")

-- git or relese Q
io.write("\n2. Do you want to compile -git [g] or relese [r]? (g/r)[default: g]: ")
local ans_ver = io.read("*l"):lower()
local is_release = (ans_ver == "r")

print("\n============================================================")

local destdir = ""
local cmake_install_cmd = ""
local meson_install_cmd = ""
local checkout_cmd = ""

-- version logic
if is_release then
    checkout_cmd = "git checkout $(git describe --tags $(git rev-list --tags --max-count=1))"
    print("-> Version: last relese (Stable)")
else
    print("-> Version: last git commit (master/main)")
end

-- dir logic
if is_distro then
    local home = os.getenv("HOME")
    local folder_name = "hyprland_git"
    if is_release then
        folder_name = "hyprland_stable"
    end
    destdir = home .. "/" .. folder_name

    -- use DESTDIR without sudo
    os.execute("mkdir -p " .. destdir)
    cmake_install_cmd = string.format("DESTDIR=%s cmake --install", destdir)
    meson_install_cmd = string.format("DESTDIR=%s meson install", destdir)
    print("-> Dir: (" .. destdir .. ")")
else
    cmake_install_cmd = "sudo cmake --install"
    meson_install_cmd = "sudo meson install"
    print("-> Install on system (sudo required)")
end

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
    "scdoc"
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
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -B build
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
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
    cmake --build ./build --config Release --target hyprlock -j$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)
    %s ./build
]], checkout_cmd, cmake_install_cmd))

print("--> Compiling: uwsm")
run(string.format([[
    rm -rf uwsm
    git clone https://github.com/Vladimir-csp/uwsm.git
    cd uwsm
    %s
    meson setup --prefix=/usr/local -Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled -Dttyautolock=enabled build
    %s -C build
]], checkout_cmd, meson_install_cmd))

print("\n============================================================")
print("COMPLETED")
if is_distro then
    print("Files are ready in: " .. destdir)
end
print("============================================================\n")
