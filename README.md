# Compile Hyrpland on Fedora
This repo contains a script to automatize the compilation of Hyprland on Fedora
## Requirements
Before starting the script, it is needed to remove the actual installation of lua from the system and build it from source because Hyrpland 0.50> will require lua 5.5

To do so follow this steps:
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
Then add "export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
at the bottom of .bashrc

Now you can start the script with ``` lua script.lua```

## Script description
The script will ask if you want to compile the git version or the latest relese.
The script will ask if you want to install Hyprland on the system or create a folder were to save all the files to install it later on another machine. If you chose git before, the folder name will be ```hyprland_git```, else```hyprland_relese``` 
