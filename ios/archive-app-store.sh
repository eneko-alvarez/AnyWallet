#!/bin/bash
set -euo pipefail

ios_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(cd "$ios_dir/.." && pwd)
archive_path="$ios_dir/build/AnyWallet.xcarchive"
export_path="$ios_dir/build/AppStore"
app_path="$archive_path/Products/Applications/AnyWallet.app"
ads_env_file="$ios_dir/.env.ads.production"

if [[ -f "$ads_env_file" ]]; then
  # The production identifiers stay on this Mac, outside Git.
  source "$ads_env_file"
fi
if [[ ! "${ADMOB_APP_ID:-}" =~ ^ca-app-pub-[0-9]{16}~[0-9]{10}$ ]] ||
   [[ ! "${ADMOB_INTERSTITIAL_ID:-}" =~ ^ca-app-pub-[0-9]{16}/[0-9]{10}$ ]] ||
   [[ "${ADMOB_APP_ID%%~*}" != "${ADMOB_INTERSTITIAL_ID%%/*}" ]]; then
  echo 'Faltan los IDs reales de AdMob o no coinciden. Configura ios/.env.ads.production.' >&2
  exit 1
fi

command -v xcodegen >/dev/null || { echo "Instala XcodeGen: brew install xcodegen" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "Selecciona Xcode 26 o posterior con xcode-select" >&2; exit 1; }
xcode_version=$(xcodebuild -version | awk '/^Xcode / { print $2; exit }')
xcode_major=${xcode_version%%.*}
if [[ ! "$xcode_major" =~ ^[0-9]+$ ]] || (( xcode_major < 26 )); then
  echo "App Store Connect exige Xcode 26 o posterior; detectado: $xcode_version" >&2
  exit 1
fi

cd "$ios_dir"
xcodegen generate
xcodebuild -project AnyWallet.xcodeproj -scheme AnyWallet -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive_path" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=B6757Q5N7U \
  ADMOB_APP_ID="$ADMOB_APP_ID" ADMOB_INTERSTITIAL_ID="$ADMOB_INTERSTITIAL_ID" archive

api_url=$(/usr/libexec/PlistBuddy -c 'Print :APIBaseURL' "$app_path/Info.plist")
test "$api_url" = 'https://anywallet.topitup.party' || { echo "APIBaseURL incorrecta: $api_url" >&2; exit 1; }
attest_required=$(/usr/libexec/PlistBuddy -c 'Print :AppAttestRequired' "$app_path/Info.plist")
test "$attest_required" = 'YES' || { echo "App Attest no está activado en Release: $attest_required" >&2; exit 1; }
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Info.plist")" = '1.1'
test "$(/usr/libexec/PlistBuddy -c 'Print :GADApplicationIdentifier' "$app_path/Info.plist")" = "$ADMOB_APP_ID"
test "$(/usr/libexec/PlistBuddy -c 'Print :InterstitialAdUnitID' "$app_path/Info.plist")" = "$ADMOB_INTERSTITIAL_ID"

xcodebuild -exportArchive -archivePath "$archive_path" \
  -exportPath "$export_path" -exportOptionsPlist "$ios_dir/ExportOptions-AppStore.plist" \
  -allowProvisioningUpdates

test -s "$export_path/AnyWallet.ipa"
echo "IPA preparada: $export_path/AnyWallet.ipa"
echo "Repositorio: $project_dir"
