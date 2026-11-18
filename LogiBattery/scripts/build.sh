#!/usr/bin/env bash
# Build LogiBattery.app (with its widget extension) in Release into LogiBattery/build.
set -eu

usage() {
  echo "usage: build.sh [-h]"
  echo "Derives DEVELOPMENT_TEAM from the 'Apple Development' certificate, generates the"
  echo "Xcode project with xcodegen, and runs xcodebuild Release."
}

project_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

team_id_from_cert() {
  security find-certificate -c "Apple Development" -p \
    | openssl x509 -noout -subject \
    | sed -n 's/.*OU[ ]*=[ ]*\([A-Za-z0-9]*\).*/\1/p'
}

write_local_xcconfig() {
  local dir=$1 team
  team=$(team_id_from_cert)
  if [[ -z "$team" ]]; then
    echo "build.sh: no 'Apple Development' certificate with an OU found in the keychain" >&2
    return 1
  fi
  printf 'DEVELOPMENT_TEAM = %s\n' "$team" > "$dir/Local.xcconfig"
}

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help) usage; return 0 ;;
      *) echo "build.sh: unknown option $1" >&2; usage >&2; return 2 ;;
    esac
  done

  local dir
  dir=$(project_dir)
  write_local_xcconfig "$dir"
  (cd "$dir" && xcodegen generate --quiet)
  (cd "$dir" && xcodebuild \
    -project LogiBattery.xcodeproj \
    -scheme LogiBattery \
    -configuration Release \
    -derivedDataPath build \
    build | tail -n 25)
  echo "built: $dir/build/Build/Products/Release/LogiBattery.app"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
