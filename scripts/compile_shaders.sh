#!/bin/sh
# Rebuilds the shaders in assets/shaders after editing their sources. Needs Qt's qsb (qt6-shadertools,
# or pyside6-qsb from pip install PySide6-Essentials). The .qsb files are committed, so building the
# app doesn't need it
set -e
cd "$(dirname "$0")/../assets/shaders"
QSB=${QSB:-$(command -v qsb || command -v pyside6-qsb)}
for src in *.frag *.vert; do
    [ -e "$src" ] || continue
    "$QSB" --qt6 --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$src.qsb" "$src"
    echo "$src.qsb"
done
