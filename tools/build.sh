#!/usr/bin/env bash
# Windows sürümü üretir: oyunu .pck olarak dışa aktarır, Godot çalıştırıcısını yanına
# Ciftligim3D.exe adıyla koyar (aynı adlı .pck'yi kendiliğinden açar) ve zip'ler.
# Dışa aktarma şablonu gerekmez. Inno Setup varsa kurulum exe'si de üretir. Kullanım: bash tools/build.sh
set -e
cd "$(dirname "$0")/.."
GD="${GODOT_DIR:-/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe}"
CON="$GD/Godot_v4.7.2-stable_win64_console.exe"
GUI="$GD/Godot_v4.7.2-stable_win64.exe"
VER=$(grep '^config/version=' project.godot | cut -d'"' -f2)
OUT=../surumler/Ciftligim3D
rm -rf "$OUT" && mkdir -p "$OUT"
"$CON" --headless --path . --export-pack "Windows Desktop" "$OUT/Ciftligim3D.pck"
cp "$GUI" "$OUT/Ciftligim3D.exe"
cp CHANGELOG.md "$OUT/SURUM_NOTLARI.txt"
cp LICENSES.txt "$OUT/LISANSLAR.txt" 2>/dev/null || true
python -I - "$OUT" "../surumler/Ciftligim3D-v$VER-windows.zip" <<'PY'
import sys, os, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for f in sorted(os.listdir(src)):
        z.write(os.path.join(src, f), "Ciftligim3D/" + f)
print("zip:", dst, os.path.getsize(dst) // (1024 * 1024), "MB")
PY
# Windows kurulum dosyası (Inno Setup 6 kuruluysa): ../surumler/Ciftligim3D-Kurulum-v<sürüm>.exe
ISCC="${ISCC:-$LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe}"
if [ -f "$ISCC" ]; then
  (cd installer && MSYS_NO_PATHCONV=1 "$ISCC" /Q /DAppVer="$VER" ciftlik.iss)
  echo "kurulum: ../surumler/Ciftligim3D-Kurulum-v$VER.exe"
fi
echo "BUILD OK v$VER"
