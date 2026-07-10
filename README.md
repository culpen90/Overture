# Overture

Overture is an open-source, native macOS browser inspired by the fast,
workspace-centered experience of modern desktop browsers. Its interface is built
with SwiftUI and pages are rendered by Apple's WebKit framework.

Overture is an independent Opera-style alternative. It does not contain Opera
code or assets and is not affiliated with or endorsed by Opera Software.

## Included browser experience

The current macOS app includes:

- WebKit-powered browsing with an address/search field and tab management
- Horizontal or vertical tabs, workspaces, and grouped tab islands
- A customizable start page with Speed Dial shortcuts and recent pages
- Local bookmarks, history, session restoration, and download management
- Private browsing backed by non-persistent WebKit data stores
- Built-in WebKit content rules for known ads and trackers
- Resizable two-, three-, and four-pane Split Screen layouts
- Tab search, grouped Tab Islands, recently closed tabs, and drag reordering
- Find in page, page zoom, printing, PNG snapshots, and PDF export
- User-confirmed download destinations, progress/state tracking, retry, and reveal
- Native settings for search, appearance, privacy, downloads, and page zoom
- An optional Proton VPN companion handoff

Overture uses WebKit rather than Chromium, so it does not claim compatibility
with Opera or Chrome extensions, proprietary Opera sync/Flow services, or DRM
systems that require separate vendor entitlements. As with any young browser,
evaluate a development build before relying on it as your only security boundary.

## Proton VPN companion

Overture can detect and open the separately installed Proton VPN macOS app. If it
is not installed, Overture can open Proton's official free-plan or download page.
This makes Proton VPN easier to reach, but Overture does not provide, bundle,
resell, control, or inspect a VPN connection.

Proton VPN is a separate service with its own app, accounts, terms, privacy
policy, availability, and plan limits. Overture is not affiliated with or
endorsed by Proton AG, and use of Proton VPN is optional.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or a compatible Swift 6 toolchain
- Xcode command-line tools (`xcode-select --install`)

## Build, test, and run

From the repository root:

```bash
swift build
swift test
swift run Overture
```

`swift run` launches the Swift Package Manager executable directly. For a normal
macOS application bundle, use the packaging script instead.

## Package the app

```bash
./Scripts/package_app.sh
open dist/Overture.app
```

The script performs a release build, generates Overture's original app icon,
creates `dist/Overture.app`, writes its `Info.plist`, and ad-hoc signs the bundle
for local use. Override release metadata when needed:

```bash
VERSION=0.2.0 BUILD_NUMBER=42 ./Scripts/package_app.sh
```

You can also generate the icon independently:

```bash
swift Scripts/generate_icon.swift dist
```

This produces `dist/Overture.iconset` and `dist/Overture.icns` without using
third-party artwork.

## License

Overture is available under the [MIT License](LICENSE).
