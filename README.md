# Compile Hyprland on Fedora with Docker

This repository contains a script to automate the compilation of Hyprland on Fedora with Docker.
Run:
```
docker build -t hypr-builder .
```
and
```
docker run --rm -it -v ${PWD}/hypr_rpms_built:/output hypr-builder
```
