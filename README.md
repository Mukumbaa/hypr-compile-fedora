# Compile Hyprland on Fedora

This repository contains a script to automate the compilation of Hyprland on Fedora.

## Requirements

Before starting the script, you must remove the existing installation of Lua from your system and build it from source, because Hyprland 0.50+ requires Lua 5.5.

To do so, follow these steps:
```
sudo dnf install make gcc
curl -L -R -O https://www.lua.org/ftp/lua-5.5.0.tar.gz
tar zxf lua-5.5.0.tar.gz
cd lua-5.5.0
make linux MYCFLAGS="-fPIC"
sudo make INSTALL_TOP=/usr/local install
sudo mkdir -p /usr/local/lib/pkgconfig
    
sudo bash -c 'cat << "EOF" > /usr/local/lib/pkgconfig/lua55.pc
prefix=/usr/local
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Lua
Description: Lua programming language
Version: 5.5.0
Libs: -L${libdir} -llua
Cflags: -I${includedir}
EOF'
```

Then add the following line at the bottom of ```~/.bashrc```:

```export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"```

Now you can start the script with ```lua script.lua```

## Script description
The script will ask whether you want to compile the Git version or the latest release.

It will also ask whether you want to install Hyprland on the system, or create a folder where all the files will be saved so you can install it later on another machine. If you chose the Git version, the folder name will be ```hyprland_git```; otherwise, it will be ```hyprland_release```.
