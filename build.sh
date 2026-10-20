#!/bin/sh
# Packages every plugin folder (one with a package.json) into
# dist/<name>.aseprite-extension
set -e
cd "$(dirname "$0")"
mkdir -p dist
for pkg in */package.json; do
  name=$(dirname "$pkg")
  out="dist/$name.aseprite-extension"
  rm -f "$out"
  (cd "$name" && zip -qr "../$out" . -x '.*')
  echo "$out"
done
