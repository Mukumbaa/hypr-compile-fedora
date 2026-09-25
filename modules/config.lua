-- modules/config.lua
local M = {}

M.WORK_DIR = "/tmp/hypr_build_workspace"
M.RESULTS_DIR = "/output"
M.RPMBUILD_DIR = "/root/rpmbuild"
M.SPECS_DIR = "specs"

M.all_modules = {
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
{ url = "https://github.com/stephenberry/glaze.git", dir = "glaze", build_reqs = "cmake gcc-c++", core_deps = {} },
  { url = "https://github.com/hyprwm/xdg-desktop-portal-hyprland.git", dir = "xdg-desktop-portal-hyprland", build_reqs = "libuuid-devel sdbus-cpp-devel pipewire-devel qt6-qtbase-devel qt6-qtwayland-devel wayland-devel wayland-protocols-devel libdrm-devel mesa-libgbm-devel mesa-libGL-devel", core_deps = { "hyprlang", "hyprutils", "hyprwayland-scanner", "hyprland-protocols" } },
  { url = "https://github.com/hyprwm/Hyprland.git",                   dir = "Hyprland",                    build_reqs = "readline-devel cairo-devel pango-devel libdrm-devel libinput-devel libxkbcommon-devel libuuid-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel xcb-util-wm-devel xcb-util-renderutil-devel xcb-util-errors-devel xcb-util-keysyms-devel libxcb-devel tomlplusplus-devel re2-devel lcms2-devel libdisplay-info-devel hwdata-devel glslang-devel muParser-devel libeis-devel libcanberra-devel libXcursor-devel glib2-devel", core_deps = {"uwsm", "glaze", "hyprutils", "hyprlang", "hyprcursor", "hyprgraphics", "aquamarine", "hyprwayland-scanner", "hyprland-protocols", "hyprwire"} },
  { url = "https://github.com/hyprwm/hyprpaper.git",                   dir = "hyprpaper",                   build_reqs = "wayland-devel wayland-protocols-devel cairo-devel pango-devel libjpeg-turbo-devel libwebp-devel mesa-libGLES-devel file-devel systemd-rpm-macros", core_deps = { "hyprwayland-scanner", "hyprlang", "hyprutils", "hyprtoolkit", "hyprwire" } },
  { url = "https://github.com/hyprwm/hyprlock.git",                    dir = "hyprlock",                    build_reqs = "pam-devel wayland-devel wayland-protocols-devel cairo-devel pango-devel libdrm-devel libxkbcommon-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel mesa-libgbm-devel sdbus-cpp-devel systemd-devel", core_deps = { "hyprwayland-scanner", "hyprlang", "hyprutils", "hyprgraphics" } },
  { url = "https://github.com/hyprwm/hyprpicker.git",                  dir = "hyprpicker",                  build_reqs = "wayland-devel wayland-protocols-devel cairo-devel pango-devel libxkbcommon-devel mesa-libGLES-devel mesa-libGL-devel", core_deps = { "hyprutils", "hyprwayland-scanner" } },
  { url = "https://github.com/outfoxxed/quickshell.git",               dir = "quickshell",                  extra_args = "-DVENDOR_CPPTRACE=ON -DINSTALL_QML_PREFIX=lib64/qt6/qml", build_reqs = "qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtshadertools-devel qt6-qtsvg-devel cli11-devel jemalloc-devel pipewire-devel libdrm-devel mesa-libGL-devel vulkan-headers polkit-devel libxcb-devel libunwind-devel libdwarf-devel", core_deps = {} },
  { url = "https://github.com/sxyazi/yazi.git",                        dir = "yazi",                        build_reqs = "cargo rustc", core_deps = {} },
  { url = "https://github.com/kovidgoyal/kitty.git",                   dir = "kitty",                       build_reqs = "golang python3-devel ncurses libX11-devel libXrandr-devel libXinerama-devel libXcursor-devel libxkbcommon-devel dbus-devel fontconfig harfbuzz-devel zlib-devel slang slang-devel xxhash-devel openssl-devel libxkbcommon-x11-devel simde-devel vulkan-headers vulkan-loader-devel python3-sphinx python3-sphinx-copybutton python3-sphinx-inline-tabs python3-sphinxext-opengraph python3-sphinx-design python3-sphinx-theme-furo", core_deps = {} },
  { url = "https://github.com/yorukot/superfile.git",                  dir = "superfile",                   build_reqs = "", core_deps = {} },
  { url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.zip", dir = "caskaydia-mono-nerd-fonts", build_reqs = "unzip", core_deps = {} },
  { url = "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz", dir = "starship", build_reqs = "", core_deps = {} },
}

return M
