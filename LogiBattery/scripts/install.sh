#!/usr/bin/env bash
# Install the built LogiBattery.app into /Applications and register its widget.
set -eu

readonly APP_ID="com.nmccready.LogiBattery"
readonly DEST="/Applications/LogiBattery.app"
readonly LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

usage() {
  echo "usage: install.sh [-h]"
  echo "Copies build/Build/Products/Release/LogiBattery.app to $DEST, registers it, and opens it once."
}

project_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

bundle_id() {
  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$1/Contents/Info.plist" 2>/dev/null || true
}

replace_installed_app() {
  local src=$1
  if [[ -e "$DEST" && "$(bundle_id "$DEST")" != "$APP_ID" ]]; then
    echo "install.sh: $DEST exists and is not $APP_ID, refusing to replace it" >&2
    return 1
  fi
  osascript -e "tell application id \"$APP_ID\" to quit" >/dev/null 2>&1 || true
  rm -rf "$DEST"
  ditto "$src" "$DEST"
}

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help) usage; return 0 ;;
      *) echo "install.sh: unknown option $1" >&2; usage >&2; return 2 ;;
    esac
  done

  local src
  src="$(project_dir)/build/Build/Products/Release/LogiBattery.app"
  if [[ ! -d "$src" ]]; then
    echo "install.sh: $src not found, run scripts/build.sh first" >&2
    return 1
  fi

  replace_installed_app "$src"
  "$LSREGISTER" -f "$DEST"
  pluginkit -a "$DEST/Contents/PlugIns/LogiBatteryWidget.appex"
  open "$DEST"
  echo "installed: $DEST"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
