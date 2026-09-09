#!/bin/bash
set -e

REPO_URL="${REPO_URL:-https://github.com/Mukumbaa/hypr-compile-fedora.git}"

if [ -n "$REPO_URL" ]; then
    echo "============================================================"
    echo "--> Repo GitHub: $REPO_URL"
    echo "============================================================"
    rm -rf /workspace/repo
    git clone --depth 1 "$REPO_URL" /workspace/repo
    cd /workspace/repo

    SCRIPT="${SCRIPT_NAME:-script.lua}"
    if [ ! -f "$SCRIPT" ] && [ -f "build.lua" ]; then
        SCRIPT="build.lua"
    fi

    echo "--> Exec: $SCRIPT"
    lua "$SCRIPT"

    if [ -d "/output" ]; then
        echo "============================================================"
        echo "--> METADATA for repository RPM in /output..."
        echo "============================================================"
        createrepo_c /output
        echo "--> Repository generated in /output!"
    else
        echo "[!] WARNING: no /output folder found."
    fi
else
    echo "[!] ERROR: No REPO_URL specified."
    echo "    Usage ex: docker run -e REPO_URL=\"https://github.com/tuo-utente/tua-repo.git\" ..."
    exit 1
fi
