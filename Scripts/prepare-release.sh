#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: Scripts/prepare-release.sh <version>" >&2
  exit 64
fi

release_version="$1"
repository_root="${0:A:h:h}"
latest_archive="$(ls -td ~/Library/Developer/Xcode/Archives/*/Cellar*.xcarchive | head -1)"
archived_app="$latest_archive/Products/Applications/Cellar.app"
archived_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$archived_app/Contents/Info.plist")"

if [[ "$archived_version" != "$release_version" ]]; then
  echo "The latest archive is Cellar $archived_version, not $release_version. Archive it in Xcode first." >&2
  exit 1
fi

sparkle_tools="$(find ~/Library/Developer/Xcode/DerivedData -path '*/artifacts/sparkle/Sparkle/bin' -type d -print -quit)"
if [[ -z "$sparkle_tools" ]]; then
  echo "Sparkle's tools were not found. Open Cellar.xcodeproj in Xcode so it downloads the Sparkle package." >&2
  exit 1
fi

release_directory="$repository_root/build/release-$release_version"
rm -rf "$release_directory"
mkdir -p "$release_directory"
ditto -c -k --keepParent "$archived_app" "$release_directory/Cellar-$release_version.zip"
"$sparkle_tools/generate_appcast" \
  --download-url-prefix "https://github.com/Arclyne/cellar/releases/download/v$release_version/" \
  "$release_directory"

echo "Upload these files to the v$release_version release:"
ls -1 "$release_directory"/Cellar-*.zip "$release_directory"/appcast.xml
