#!/usr/bin/env bash
# Fase 4 · Empaquetado Linux: PyInstaller onefile → AppImage con linuxdeploy.
# Uso: ./empaquetar.sh [build|appimage]   (por defecto: build)
# Requisitos: binutils (objdump), pyinstaller, linuxdeploy (binario de GitHub).

set -euo pipefail

NOMBRE="ConversorEpub"
PYTHON="${PYTHON:-python3}"
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