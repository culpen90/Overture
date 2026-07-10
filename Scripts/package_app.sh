#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly APP_NAME="Overture"
readonly VERSION="${VERSION:-0.1.0}"
readonly BUILD_NUMBER="${BUILD_NUMBER:-1}"
readonly BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.overture.browser}"
readonly DIST_DIR="${PROJECT_ROOT}/dist"
readonly APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
readonly CONTENTS_DIR="${APP_BUNDLE}/Contents"
readonly MACOS_DIR="${CONTENTS_DIR}/MacOS"
readonly RESOURCES_DIR="${CONTENTS_DIR}/Resources"
readonly INFO_PLIST="${CONTENTS_DIR}/Info.plist"
readonly GENERATED_ASSETS_DIR="${PROJECT_ROOT}/.build/overture-packaging"

if [[ ! "${VERSION}" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
    printf 'error: VERSION must contain one to three numeric components (for example, 1.2.0).\n' >&2
    exit 64
fi

if [[ ! "${BUILD_NUMBER}" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
    printf 'error: BUILD_NUMBER must contain one to three numeric components.\n' >&2
    exit 64
fi

if [[ ! "${BUNDLE_IDENTIFIER}" =~ ^[A-Za-z0-9-]+([.][A-Za-z0-9-]+)+$ ]]; then
    printf 'error: BUNDLE_IDENTIFIER must be a reverse-DNS identifier.\n' >&2
    exit 64
fi

if ! command -v swift >/dev/null 2>&1; then
    printf 'error: Swift is unavailable. Install Xcode or the Xcode command-line tools.\n' >&2
    exit 69
fi

cd "${PROJECT_ROOT}"

printf 'Building %s %s (%s) in release mode...\n' "${APP_NAME}" "${VERSION}" "${BUILD_NUMBER}"
swift build -c release --product "${APP_NAME}"
readonly BIN_DIR="$(swift build -c release --show-bin-path)"
readonly EXECUTABLE="${BIN_DIR}/${APP_NAME}"

if [[ ! -x "${EXECUTABLE}" ]]; then
    printf 'error: expected release executable at %s\n' "${EXECUTABLE}" >&2
    exit 70
fi

printf 'Generating the application icon...\n'
swift "${SCRIPT_DIR}/generate_icon.swift" "${GENERATED_ASSETS_DIR}"

rm -rf -- "${APP_BUNDLE}"
mkdir -p -- "${MACOS_DIR}" "${RESOURCES_DIR}"

/bin/cp -- "${EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"
/bin/chmod 755 "${MACOS_DIR}/${APP_NAME}"
/bin/cp -- "${GENERATED_ASSETS_DIR}/Overture.icns" "${RESOURCES_DIR}/AppIcon.icns"

insert_plist_value() {
    local key_path="$1"
    local value_type="$2"
    local value="$3"

    /usr/bin/plutil -insert "${key_path}" "${value_type}" "${value}" "${INFO_PLIST}"
}

/usr/bin/plutil -create xml1 "${INFO_PLIST}"
insert_plist_value "CFBundleDevelopmentRegion" -string "en"
insert_plist_value "CFBundleDisplayName" -string "${APP_NAME}"
insert_plist_value "CFBundleExecutable" -string "${APP_NAME}"
insert_plist_value "CFBundleIconFile" -string "AppIcon"
insert_plist_value "CFBundleIdentifier" -string "${BUNDLE_IDENTIFIER}"
insert_plist_value "CFBundleInfoDictionaryVersion" -string "6.0"
insert_plist_value "CFBundleName" -string "${APP_NAME}"
insert_plist_value "CFBundlePackageType" -string "APPL"
insert_plist_value "CFBundleShortVersionString" -string "${VERSION}"
insert_plist_value "CFBundleVersion" -string "${BUILD_NUMBER}"
insert_plist_value "LSApplicationCategoryType" -string "public.app-category.productivity"
insert_plist_value "LSMinimumSystemVersion" -string "14.0"
insert_plist_value "NSHighResolutionCapable" -bool "true"
insert_plist_value "NSPrincipalClass" -string "NSApplication"
insert_plist_value "NSSupportsAutomaticGraphicsSwitching" -bool "true"
insert_plist_value "NSCameraUsageDescription" -string \
    "Overture allows websites you approve to use the camera for calls and media capture."
insert_plist_value "NSMicrophoneUsageDescription" -string \
    "Overture allows websites you approve to use the microphone for calls and media capture."
insert_plist_value "NSLocationUsageDescription" -string \
    "Overture allows websites you approve to request your approximate location."
insert_plist_value "NSDownloadsFolderUsageDescription" -string \
    "Overture saves files you download from websites to your chosen Downloads folder."

/usr/bin/plutil -insert "NSAppTransportSecurity" -dictionary "${INFO_PLIST}"
insert_plist_value "NSAppTransportSecurity.NSAllowsArbitraryLoadsInWebContent" -bool "true"
insert_plist_value "NSAppTransportSecurity.NSAllowsLocalNetworking" -bool "true"

/usr/bin/plutil -insert "CFBundleURLTypes" -array "${INFO_PLIST}"
/usr/bin/plutil -insert "CFBundleURLTypes.0" -dictionary "${INFO_PLIST}"
insert_plist_value "CFBundleURLTypes.0.CFBundleTypeRole" -string "Viewer"
insert_plist_value "CFBundleURLTypes.0.CFBundleURLName" -string "${BUNDLE_IDENTIFIER}"
/usr/bin/plutil -insert "CFBundleURLTypes.0.CFBundleURLSchemes" -array "${INFO_PLIST}"
insert_plist_value "CFBundleURLTypes.0.CFBundleURLSchemes.0" -string "overture"

/usr/bin/plutil -lint "${INFO_PLIST}"

printf 'Ad-hoc signing %s...\n' "${APP_BUNDLE}"
/usr/bin/codesign --force --sign - --timestamp=none "${APP_BUNDLE}"
/usr/bin/codesign --verify --deep --strict "${APP_BUNDLE}"

printf 'Packaged %s\n' "${APP_BUNDLE}"
