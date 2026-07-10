# Overture architecture

Overture is a native macOS browser built with SwiftUI, AppKit, and WebKit. WebKit supplies the standards-compliant browser engine; Overture owns the browser chrome, tab and workspace model, privacy rules, persistence, downloads, and desktop integration.

## Product contract

- Real multi-tab browsing with address/search resolution, navigation controls, loading state, page zoom, find-in-page, reader styling, screenshots, printing, and downloads.
- Opera-inspired desktop shell with a collapsible sidebar, workspaces, speed dial, tab strip, split browsing, command palette, and configurable appearance.
- Local browser library containing bookmarks, history, recently closed tabs, downloads, and pinboards.
- Privacy controls including private tabs, tracker/ad content blocking, cookie and website-data clearing, HTTPS-first navigation, and per-page shield state.
- An optional Proton VPN companion hand-off that opens the installed Proton VPN app or its official free-plan page. Overture does not claim to provide or control the VPN tunnel and does not access Proton credentials or traffic.
- Session restore, search-engine selection, startup preferences, keyboard shortcuts, native menus, accessibility labels, and multiple windows.
- No fake network features: capabilities that require a privileged VPN service, proprietary sync backend, DRM entitlement, or signed extension are documented rather than represented as active. Proton VPN remains a separately installed, separately operated service.

## State ownership

- `BrowserStore` is the main-actor source of truth for windows, tabs, workspaces, library data, preferences, and presentation state.
- `BrowserTab` owns one `WKWebView` for the life of the tab and publishes only browser-facing state. This preserves page/session state across SwiftUI updates.
- Small Codable records (`Bookmark`, `HistoryEntry`, `SpeedDialItem`, `Workspace`, `DownloadRecord`, `PinboardNote`) are persisted by `BrowserPersistence` as versioned JSON in Application Support.
- Preferences use a Codable settings record managed by the store so the app and Settings scene share one consistent model.
- Views receive `BrowserStore` explicitly or through a focused scene value. Feature-local UI state remains in the narrowest view that owns it.

## UI composition

`BrowserRootView` owns the stable window shell. It composes `BrowserSidebar`, `TabStrip`, `NavigationToolbar`, `BrowserContentView`, optional library/command overlays, and enum-driven sheets. Views are split by responsibility to keep WebKit delegates and persistence out of SwiftUI render paths.

## Boundaries

- `Models/`: value records, browser settings, and observable tab/store state.
- `Services/`: URL resolution, JSON persistence, privacy content rules, downloads, and WebKit delegate behavior.
- `Views/Browser/`: browser chrome and web content bridge.
- `Views/StartPage/`: speed dial and start-page experience.
- `Views/Library/`: history, bookmarks, downloads, and pinboards.
- `Views/Settings/`: native macOS Settings scene.
- `App/`: app entry point, menu commands, window wiring, and focused actions.

## Verification

Pure URL, model, and persistence behavior is covered by `swift test`. The app must also pass `swift build`, an application-bundle packaging smoke test, launch without runtime exceptions, and an interactive WebKit smoke test against local and remote pages.
