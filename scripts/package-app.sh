#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_root=${script_dir:h}
app_bundle="$project_root/dist/Codex Appearance Manager.app"
legacy_resource_bundle="$app_bundle/CodexAppearanceManager_CodexAppearanceUI.bundle"
(cd "$project_root" && swift build -c release)
binary_directory=$(cd "$project_root" && swift build -c release --show-bin-path)

mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
if [[ -e "$legacy_resource_bundle" ]]; then
    rm -rf "$legacy_resource_bundle"
fi
cp "$binary_directory/CodexAppearanceApp" "$app_bundle/Contents/MacOS/CodexAppearanceApp"
cp "$script_dir/CodexAppearanceManager-Info.plist" "$app_bundle/Contents/Info.plist"
cp "$project_root/assets/AppIcon.icns" "$app_bundle/Contents/Resources/AppIcon.icns"
ditto "$binary_directory/CodexAppearanceManager_CodexAppearanceUI.bundle" "$app_bundle/Contents/Resources/CodexAppearanceManager_CodexAppearanceUI.bundle"
codesign --force --sign - --timestamp=none "$app_bundle"

print "Created: $app_bundle"
