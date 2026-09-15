#!/usr/bin/env bash
# Fase 4 · Empaquetado Linux: PyInstaller onefile → AppImage con linuxdeploy.
# Uso: ./empaquetar.sh [build|appimage]   (por defecto: build)
# Requisitos: binutils (objdump), pyinstaller, linuxdeploy (binario de GitHub).

set -euo pipefail

NOMBRE="ConversorEpub"
if [ -z "${PYTHON:-}" ]; then
    if [ -n "${VIRTUAL_ENV:-}" ] && [ -x "$VIRTUAL_ENV/bin/python" ]; then
        PYTHON="$VIRTUAL_ENV/bin/python"
    elif [ -x ".venv/bin/python" ]; then
        PYTHON="$(pwd)/.venv/bin/python"
    elif [ -x "venv/bin/python" ]; then
        PYTHON="$(pwd)/venv/bin/python"
    else
        PYTHON="python3"
    fi
fi

# En NixOS, PyInstaller requiere un entorno FHS para que los hooks de PySide6
# puedan cargar libstdc++ y empaquetar los plugins de plataforma de Qt (libqxcb.so).
if [ -e /etc/NIXOS ] && [ ! -d /usr/lib ]; then
    if command -v steam-run >/dev/null 2>&1; then
        echo "ℹ️  Detectado NixOS: relanzando dentro de steam-run para resolver dependencias de Qt..."
        exec steam-run env PYTHON="$PYTHON" "$0" "$@"
    else
        echo "⚠️  Detectado NixOS sin steam-run en el PATH. Podrían faltar plugins de Qt en el ejecutable."
    fi
fi

DIST="dist/$NOMBRE"
DESKTOP="assets/$NOMBRE.desktop"

preflight() {
    command -v objdump >/dev/null 2>&1 \
        || { echo "❌ Falta binutils (objdump). Instala: sudo apt install binutils"; exit 1; }
    command -v linuxdeploy >/dev/null 2>&1 \
        || { echo "⚠️  linuxdeploy no está en el PATH (solo lo necesita 'appimage')."; }
}

build() {
    preflight
    echo "=== PyInstaller (onefile) ==="
    "$PYTHON" -m PyInstaller --noconfirm --clean --onefile --windowed \
        --name "$NOMBRE" \
        --add-data "assets/Conv_Xhtml/template.xhtml:assets/Conv_Xhtml" \
        --add-data "assets/Plantillas:assets/Plantillas" \
        app/app.py
    echo "✅ Binario: $DIST"
}

appimage() {
    [ -x "$DIST" ] || build
    command -v linuxdeploy >/dev/null 2>&1 || {
        echo "❌ Descarga linuxdeploy-x86_64.AppImage de"
        echo "   https://github.com/linuxdeploy/linuxdeploy/releases"
        echo "   chmod +x y ponlo en el PATH. Luego repite el comando."
        exit 1
    }
    echo "=== AppImage (linuxdeploy) ==="
    rm -rf AppDir
    mkdir -p AppDir/usr/share/applications
    cp "$DESKTOP" AppDir/usr/share/applications/
    cp "assets/$NOMBRE.png" AppDir/
    linuxdeploy --appdir AppDir -e "$DIST" \
        -d "$DESKTOP" --output appimage
    echo "✅ AppImage: ConversorEpub-x86_64.AppImage"
}

case "${1:-build}" in
    build) build ;;
    appimage) appimage ;;
    *) echo "Uso: $0 [build|appimage]" ;;
esac