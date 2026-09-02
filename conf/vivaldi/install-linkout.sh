#!/usr/bin/env bash
# Wire the PWA Link-Out extension into the vivaldi-apps instance:
#  - native messaging host manifest (points at linkout-host in this repo)
#  - load the unpacked extension via --load-extension in the PWA launchers
#    (which also means dropping --disable-extensions; the instance has no
#    other extensions, and this one is ours)
# Idempotent: safe to re-run.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
EXT_DIR="$ROOT_DIR/conf/vivaldi/linkout-extension"
EXT_ID="pmcekldpamgcambbbllhmkjdfhdfdkbf"  # pinned via "key" in manifest.json
NM_DIR="$HOME/.config/vivaldi-apps/NativeMessagingHosts"

mkdir -p "$NM_DIR"
cat > "$NM_DIR/com.penguino.linkout.json" <<EOF
{
  "name": "com.penguino.linkout",
  "description": "Open URL in main Vivaldi instance",
  "path": "$ROOT_DIR/conf/vivaldi/linkout-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
EOF
echo "installed $NM_DIR/com.penguino.linkout.json"

for f in "$HOME"/.local/share/applications/vivaldi-*.desktop; do
    grep -q 'user-data-dir=.*vivaldi-apps' "$f" || continue
    if grep -q -- '--load-extension=' "$f"; then
        sed -i "s|--load-extension=[^ ]*|--load-extension=$EXT_DIR|" "$f"
    else
        sed -i "s|--disable-extensions|--load-extension=$EXT_DIR|" "$f"
    fi
    # COSMIC reports --app windows with a "vivaldi-" prefixed app id;
    # StartupWMClass must match it for dock icons to resolve
    sed -i 's|^StartupWMClass=\([^v]\)|StartupWMClass=vivaldi-\1|' "$f"
    echo "patched $(basename "$f")"
done

echo "done -- restart the vivaldi-apps instance to load the extension"
