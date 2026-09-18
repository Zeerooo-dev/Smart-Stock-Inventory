#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STASH=$(mktemp -d)
trap 'rm -rf "$STASH"' EXIT
cp -R "$ROOT/lib" "$STASH/lib"
cp -R "$ROOT/test" "$STASH/test"
cp "$ROOT/pubspec.yaml" "$STASH/pubspec.yaml"
cp "$ROOT/analysis_options.yaml" "$STASH/analysis_options.yaml"
cp "$ROOT/README.md" "$STASH/README.md"
cd "$ROOT"
flutter create --platforms=android,ios,windows,macos,linux,web --org com.smartstock --project-name smartstock_flutter .
rm -rf "$ROOT/lib" "$ROOT/test"
cp -R "$STASH/lib" "$ROOT/lib"
cp -R "$STASH/test" "$ROOT/test"
cp "$STASH/pubspec.yaml" "$ROOT/pubspec.yaml"
cp "$STASH/analysis_options.yaml" "$ROOT/analysis_options.yaml"
cp "$STASH/README.md" "$ROOT/README.md"
flutter pub get
dart run sqflite_common_ffi_web:setup
printf '%s\n' 'SmartStock Flutter platform runners are ready.'
