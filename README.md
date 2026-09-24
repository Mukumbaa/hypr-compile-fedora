# Compile Hyprland on Fedora with Docker

This repository contains a script to automate the compilation of Hyprland on Fedora with Docker.
Run:
```
docker build -t hypr-builder .
```
and
```
docker run --rm -it -v ~/Hyprland-RPM:/output hypr-builder
```

## List of packages
- hyprwayland-scanner
- hyprland-protocols
- hyprutils
- hyprlang
- hyprgraphics
- hyprcursor
- aquamarine
- hyprwire
- hyprtoolkit
- hyprland-guiutils
- xdg-desktop-portal-hyprland
- hyprland
- hyprpaper
- hyprlock
- hyprpicker
- uwsm
- quickshell
- yazi
- superfile
- caskaydia-mono-nerd-fonts


.rpm in [this repo](https://github.com/Mukumbaa/Hyprland-RPM)
