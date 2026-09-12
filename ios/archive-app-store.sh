#!/bin/bash
set -euo pipefail

ios_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(cd "$ios_dir/.." && pwd)
archive_path="$ios_dir/build/AnyWallet.xcarchive"
export_path="$ios_dir/build/AppStore"
app_path="$archive_path/Products/Applications/AnyWallet.app"

command -v xcodegen >/dev/null || { echo "Instala XcodeGen: brew install xcodegen" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "Selecciona Xcode 26 o posterior con xcode-select" >&2; exit 1; }

cd "$ios_dir"
xcodegen generate
xcodebuild -project AnyWallet.xcodeproj -scheme AnyWallet -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive_path" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=B6757Q5N7U archive

api_url=$(/usr/libexec/PlistBuddy -c 'Print :APIBaseURL' "$app_path/Info.plist")
test "$api_url" = 'https://anywallet.topitup.party' || { echo "APIBaseURL incorrecta: $api_url" >&2; exit 1; }
if /usr/libexec/PlistBuddy -c 'Print :GADApplicationIdentifier' "$app_path/Info.plist" >/dev/null 2>&1; then
  echo 'El archive contiene el App ID de anuncios; no se exporta.' >&2
  exit 1
fi
if find "$app_path" -iname '*GoogleMobileAds*' -o -iname '*UserMessagingPlatform*' | grep -q .; then
  echo 'El archive contiene un SDK publicitario; no se exporta.' >&2
  exit 1
fi

xcodebuild -exportArchive -archivePath "$archive_path" \
  -exportPath "$export_path" -exportOptionsPlist "$ios_dir/ExportOptions-AppStore.plist" \
  -allowProvisioningUpdates

test -s "$export_path/AnyWallet.ipa"
echo "IPA preparada: $export_path/AnyWallet.ipa"
echo "Repositorio: $project_dir"
