import AppKit
import Combine
import Foundation
import WebKit

/// Main-actor owner for one stable WebKit browsing context.
///
/// SwiftUI may recreate its representable values freely; the web view itself lives here
/// for the complete lifetime of the tab so navigation, page state, and session data survive.
@MainActor
final class BrowserTabController: NSObject, ObservableObject {
    struct NavigationError: Swift.Error, LocalizedError, Equatable, Sendable {
        let domain: String
        let code: Int
        let message: String
        let failingURL: URL?

        var errorDescription: String? { message }

        init(_ error: any Error, fallbackURL: URL? = nil) {
            let nsError = error as NSError
            domain = nsError.domain
            code = nsError.code
            message = nsError.localizedDescription
            failingURL = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? fallbackURL
        }

        init(domain: String, code: Int, message: String, failingURL: URL? = nil) {
            self.domain = domain
            self.code = code
            self.message = message
            self.failingURL = failingURL
        }
    }

    struct HistoryVisit: Identifiable, Equatable, Sendable {
        let id: UUID
        let url: URL
        let title: String
        let visitedAt: Date

        init(id: UUID = UUID(), url: URL, title: String, visitedAt: Date = Date()) {
            self.id = id
            self.url = url
            self.title = title
            self.visitedAt = visitedAt
        }
    }

    struct DownloadItem: Identifiable, Equatable, Sendable {
        let id: UUID
        let sourceURL: URL?
        let destinationURL: URL
        let filename: String
        let startedAt: Date
    }

    enum DownloadEvent: Sendable {
        case started(DownloadItem)
        case progress(id: UUID, fractionCompleted: Double)
        case finished(id: UUID, destinationURL: URL)
        case failed(id: UUID, error: NavigationError, resumeData: Data?)
        case cancelled(id: UUID, resumeData: Data?)
    }

    enum Event: Sendable {
        case requestNewTab(URL?)
        case closeRequested
        case history(HistoryVisit)
        case download(DownloadEvent)
        case webContentProcessTerminated
    }

    enum ControllerError: LocalizedError {
        case downloadsDirectoryUnavailable
        case invalidDownloadDirectory(URL)
        case downloadFinishedWithoutDestination

        var errorDescription: String? {
            switch self {
            case .downloadsDirectoryUnavailable:
                "The Downloads directory is unavailable."
            case let .invalidDownloadDirectory(url):
                "The download destination is not a file-system directory: \(url.path)."
            case .downloadFinishedWithoutDestination:
                "The download finished without a destination URL."
            }
        }
    }

    enum DownloadDestinationDecision {
        case useDefaultDirectory
        case destination(URL)
        case cancel
    }

    typealias EventHandler = @MainActor (Event) -> Void
    typealias DownloadDirectoryProvider = @MainActor () throws -> URL
    typealias DownloadDestinationProvider = @MainActor (String) throws -> DownloadDestinationDecision
    typealias MediaCapturePermissionProvider = @MainActor (
        WKSecurityOrigin,
        WKMediaCaptureType
    ) -> WKPermissionDecision

    let id: UUID
    let webView: WKWebView
    let isPrivate: Bool
    let startPageURL: URL

    @Published private(set) var title: String
    @Published private(set) var url: URL?
    @Published private(set) var displayURL: String
    @Published private(set) var isLoading = false
    @Published private(set) var estimatedProgress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var error: NavigationError?
    @Published var isPinned: Bool
    @Published var workspaceID: UUID
    @Published var groupID: UUID?
    @Published private(set) var isShowingStartPage: Bool
    @Published private(set) var zoomLevel = 1.0
    @Published private(set) var isContentBlockingEnabled: Bool
    @Published private(set) var contentBlockingError: String?

    /// Set after initialization when the tab's owning store needs to avoid a capture cycle.
    var eventHandler: EventHandler?

    var errorMessage: String? { error?.message }
    var isStartPage: Bool { isShowingStartPage }
    var usesPersistentWebsiteData: Bool { !isPrivate }

    private let contentBlockerService: ContentBlockerService
    private let downloadDirectoryProvider: DownloadDirectoryProvider
    private let downloadDestinationProvider: DownloadDestinationProvider
    private let mediaCapturePermissionProvider: MediaCapturePermissionProvider
    private var observations: [NSKeyValueObservation] = []
    private var activeDownloads: [ObjectIdentifier: ActiveDownload] = [:]
    private var recentNewTabRequest: (url: URL?, date: Date)?

    init(
        id: UUID = UUID(),
        initialURL: URL? = nil,
        isPrivate: Bool = false,
        isPinned: Bool = false,
        workspaceID: UUID = UUID(),
        groupID: UUID? = nil,
        startPageURL: URL = URL(string: "overture://start")!,
        contentBlockingEnabled: Bool = true,
        contentBlockerService: ContentBlockerService? = nil,
        downloadDirectoryProvider: @escaping DownloadDirectoryProvider = {
            guard let directory = FileManager.default.urls(
                for: .downloadsDirectory,
                in: .userDomainMask
            ).first else {
                throw ControllerError.downloadsDirectoryUnavailable
            }
            return directory
        },
        downloadDestinationProvider: @escaping DownloadDestinationProvider = { _ in
            .useDefaultDirectory
        },
        mediaCapturePermissionProvider: @escaping MediaCapturePermissionProvider = { _, _ in .prompt },
        eventHandler: EventHandler? = nil
    ) {
        let configuration = Self.makeConfiguration(isPrivate: isPrivate)
        let webView = WKWebView(frame: .zero, configuration: configuration)

        self.id = id
        self.webView = webView
        self.isPrivate = isPrivate
        self.isPinned = isPinned
        self.workspaceID = workspaceID
        self.groupID = groupID
        self.startPageURL = startPageURL
        self.title = initialURL == nil || initialURL == startPageURL ? "Start Page" : "New Tab"
        self.url = initialURL ?? startPageURL
        self.displayURL = initialURL == nil || initialURL == startPageURL
            ? ""
            : Self.displayString(for: initialURL)
        self.isShowingStartPage = initialURL == nil || initialURL == startPageURL
        self.isContentBlockingEnabled = contentBlockingEnabled
        self.contentBlockerService = contentBlockerService ?? ContentBlockerService.shared
        self.downloadDirectoryProvider = downloadDirectoryProvider
        self.downloadDestinationProvider = downloadDestinationProvider
        self.mediaCapturePermissionProvider = mediaCapturePermissionProvider
        self.eventHandler = eventHandler

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        installObservers()

        if contentBlockingEnabled {
            Task { [weak self] in
                await self?.installContentBlocker()
            }
        }

        if let initialURL, initialURL != startPageURL {
            load(initialURL)
        }
    }

    // MARK: - Navigation

    func load(_ url: URL) {
        if url == startPageURL {
            showStartPage()
            return
        }
        load(URLRequest(url: url))
    }

    func load(_ request: URLRequest) {
        guard let requestURL = request.url else { return }
        if requestURL == startPageURL {
            showStartPage()
            return
        }

        isShowingStartPage = false
        error = nil
        updateURL(requestURL)
        webView.load(request)
    }

    func showStartPage() {
        webView.stopLoading()
        isShowingStartPage = true
        title = "Start Page"
        url = startPageURL
        displayURL = ""
        isLoading = false
        estimatedProgress = 0
        error = nil
        canGoBack = webView.url != nil
        canGoForward = webView.canGoForward
    }

    @discardableResult
    func goBack() -> WKNavigation? {
        if isShowingStartPage, webView.url != nil {
            isShowingStartPage = false
            synchronizeState()
            return nil
        }
        return webView.goBack()
    }

    @discardableResult
    func goForward() -> WKNavigation? {
        guard !isShowingStartPage else { return nil }
        return webView.goForward()
    }

    @discardableResult
    func reload() -> WKNavigation? {
        guard !isShowingStartPage else { return nil }
        error = nil
        return webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func reloadOrStop() {
        if isLoading {
            stopLoading()
        } else {
            reload()
        }
    }

    func clearError() {
        error = nil
    }

    // MARK: - Page tools

    func setZoom(_ value: Double) {
        let clampedValue = min(max(value, 0.25), 5.0)
        webView.pageZoom = clampedValue
        zoomLevel = clampedValue
    }

    func zoomIn() {
        setZoom(zoomLevel + 0.1)
    }

    func zoomOut() {
        setZoom(zoomLevel - 0.1)
    }

    func resetZoom() {
        setZoom(1.0)
    }

    @discardableResult
    func find(
        _ query: String,
        backwards: Bool = false,
        caseSensitive: Bool = false,
        wraps: Bool = true
    ) async throws -> Bool {
        guard !query.isEmpty else { return false }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = caseSensitive
        configuration.wraps = wraps
        return try await webView.find(query, configuration: configuration).matchFound
    }

    func snapshot(rect: CGRect? = nil, width: CGFloat? = nil) async throws -> NSImage {
        let configuration = WKSnapshotConfiguration()
        if let rect {
            configuration.rect = rect
        }
        if let width {
            configuration.snapshotWidth = NSNumber(value: Double(width))
        }
        configuration.afterScreenUpdates = true
        return try await webView.takeSnapshot(configuration: configuration)
    }

    func pdf(rect: CGRect? = nil, allowsTransparentBackground: Bool = false) async throws -> Data {
        let configuration = WKPDFConfiguration()
        configuration.rect = rect
        configuration.allowTransparentBackground = allowsTransparentBackground
        return try await webView.pdf(configuration: configuration)
    }

    @discardableResult
    func printPage(
        using printInfo: NSPrintInfo = .shared,
        showsPrintPanel: Bool = true,
        showsProgressPanel: Bool = true
    ) -> NSPrintOperation {
        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = showsPrintPanel
        operation.showsProgressPanel = showsProgressPanel
        operation.run()
        return operation
    }

    func pauseAllMediaPlayback() async {
        await webView.pauseAllMediaPlayback()
    }

    func setMediaPlaybackSuspended(_ suspended: Bool) async {
        await webView.setAllMediaPlaybackSuspended(suspended)
    }

    func mediaPlaybackState() async -> WKMediaPlaybackState {
        await webView.requestMediaPlaybackState()
    }

    func closeAllMediaPresentations() async {
        await webView.closeAllMediaPresentations()
    }

    func setCameraCaptureState(_ state: WKMediaCaptureState) async {
        await webView.setCameraCaptureState(state)
    }

    func setMicrophoneCaptureState(_ state: WKMediaCaptureState) async {
        await webView.setMicrophoneCaptureState(state)
    }

    // MARK: - Privacy rules

    func setContentBlockingEnabled(_ enabled: Bool, reloadCurrentPage: Bool = true) async {
        do {
            if enabled {
                try await contentBlockerService.install(
                    in: webView.configuration.userContentController
                )
            } else {
                await contentBlockerService.remove(
                    from: webView.configuration.userContentController
                )
            }
            isContentBlockingEnabled = enabled
            contentBlockingError = nil
            if reloadCurrentPage, !isShowingStartPage {
                webView.reload()
            }
        } catch {
            isContentBlockingEnabled = false
            contentBlockingError = error.localizedDescription
        }
    }

    // MARK: - Downloads

    @discardableResult
    func startDownload(_ request: URLRequest) async -> UUID {
        let download = await webView.startDownload(using: request)
        return register(download).id
    }

    @discardableResult
    func resumeDownload(from resumeData: Data) async -> UUID {
        let download = await webView.resumeDownload(fromResumeData: resumeData)
        return register(download).id
    }

    func cancelDownload(id: UUID) async -> Data? {
        guard let (key, activeDownload) = activeDownloads.first(where: { $0.value.id == id }) else {
            return nil
        }
        let resumeData = await activeDownload.download.cancel()
        activeDownload.terminalEventSent = true
        eventHandler?(.download(.cancelled(id: id, resumeData: resumeData)))
        activeDownloads.removeValue(forKey: key)
        return resumeData
    }

    // MARK: - Setup and state synchronization

    private static func makeConfiguration(isPrivate: Bool) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.inactiveSchedulingPolicy = .suspend
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.preferences.shouldPrintBackgrounds = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        return configuration
    }

    private func installContentBlocker() async {
        do {
            try await contentBlockerService.install(
                in: webView.configuration.userContentController
            )
            contentBlockingError = nil
        } catch {
            isContentBlockingEnabled = false
            contentBlockingError = error.localizedDescription
        }
    }

    private func installObservers() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.isShowingStartPage else { return }
                    let newTitle = change.newValue ?? nil
                    self.title = Self.pageTitle(newTitle, url: self.webView.url)
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.isShowingStartPage else { return }
                    self.updateURL(change.newValue ?? nil)
                }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.isShowingStartPage else { return }
                    self.isLoading = change.newValue ?? false
                }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.isShowingStartPage else { return }
                    self.estimatedProgress = min(max(change.newValue ?? 0, 0), 1)
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.canGoBack = self.isShowingStartPage
                        ? self.webView.url != nil
                        : change.newValue ?? false
                }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.canGoForward = change.newValue ?? false
                }
            }
        ]
    }

    private func synchronizeState() {
        guard !isShowingStartPage else { return }
        updateURL(webView.url)
        title = Self.pageTitle(webView.title, url: webView.url)
        isLoading = webView.isLoading
        estimatedProgress = min(max(webView.estimatedProgress, 0), 1)
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        zoomLevel = webView.pageZoom
    }

    private func updateURL(_ newURL: URL?) {
        url = newURL
        displayURL = Self.displayString(for: newURL)
    }

    private static func displayString(for url: URL?) -> String {
        guard let url else { return "" }
        if url.absoluteString == "about:blank" { return "" }
        return url.absoluteString.removingPercentEncoding ?? url.absoluteString
    }

    private static func pageTitle(_ title: String?, url: URL?) -> String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty { return trimmedTitle }
        return url?.host ?? url?.absoluteString ?? "New Tab"
    }

    private func recordFailure(_ error: any Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }
        self.error = NavigationError(error, fallbackURL: webView.url ?? url)
        synchronizeState()
    }

    private func emitNewTabRequest(_ requestURL: URL?) {
        let requestedURL = requestURL?.absoluteString == "about:blank" ? nil : requestURL
        let now = Date()
        if let recentNewTabRequest,
           recentNewTabRequest.url == requestedURL,
           now.timeIntervalSince(recentNewTabRequest.date) < 0.5 {
            return
        }
        recentNewTabRequest = (requestedURL, now)
        eventHandler?(.requestNewTab(requestedURL))
    }

    private func register(_ download: WKDownload) -> ActiveDownload {
        let key = ObjectIdentifier(download)
        if let activeDownload = activeDownloads[key] {
            download.delegate = self
            return activeDownload
        }

        let activeDownload = ActiveDownload(
            download: download,
            sourceURL: download.originalRequest?.url
        )
        activeDownloads[key] = activeDownload
        download.delegate = self

        activeDownload.progressObservation = download.progress.observe(
            \.fractionCompleted,
            options: [.initial, .new]
        ) { [weak self, weak activeDownload] progress, _ in
            MainActor.assumeIsolated {
                guard let self,
                      let activeDownload,
                      activeDownload.destinationURL != nil,
                      !activeDownload.terminalEventSent else {
                    return
                }
                let fraction = progress.fractionCompleted.isFinite
                    ? min(max(progress.fractionCompleted, 0), 1)
                    : 0
                guard abs(fraction - activeDownload.lastReportedProgress) >= 0.001 else { return }
                activeDownload.lastReportedProgress = fraction
                self.eventHandler?(
                    .download(.progress(id: activeDownload.id, fractionCompleted: fraction))
                )
            }
        }

        return activeDownload
    }

    private func uniqueDestination(in directory: URL, suggestedFilename: String) throws -> URL {
        guard directory.isFileURL else {
            throw ControllerError.invalidDownloadDirectory(directory)
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let pathSafeName = (suggestedFilename as NSString).lastPathComponent
        let filename = pathSafeName.isEmpty || pathSafeName == "." || pathSafeName == ".."
            ? "Download"
            : pathSafeName
        let filenameExtension = (filename as NSString).pathExtension
        let basename = (filename as NSString).deletingPathExtension

        var destination = directory.appendingPathComponent(filename, isDirectory: false)
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let candidateName = filenameExtension.isEmpty
                ? "\(basename) \(suffix)"
                : "\(basename) \(suffix).\(filenameExtension)"
            destination = directory.appendingPathComponent(candidateName, isDirectory: false)
            suffix += 1
        }
        return destination
    }
}

// MARK: - WKNavigationDelegate

extension BrowserTabController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        let requestURL = navigationAction.request.url
        if requestURL == startPageURL {
            showStartPage()
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame == nil {
            emitNewTabRequest(requestURL)
            decisionHandler(.cancel)
            return
        }

        if let requestURL,
           let scheme = requestURL.scheme?.lowercased(),
           !["http", "https", "file", "data", "about", "blob"].contains(scheme) {
            if navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(requestURL)
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isShowingStartPage = false
        error = nil
        synchronizeState()
    }

    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        synchronizeState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        synchronizeState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        synchronizeState()
        error = nil

        guard !isPrivate,
              let visitedURL = webView.url,
              ["http", "https"].contains(visitedURL.scheme?.lowercased() ?? "") else {
            return
        }
        eventHandler?(
            .history(
                HistoryVisit(
                    url: visitedURL,
                    title: Self.pageTitle(webView.title, url: visitedURL)
                )
            )
        )
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        recordFailure(error)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        recordFailure(error)
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @MainActor @Sendable (
            URLSession.AuthChallengeDisposition,
            URLCredential?
        ) -> Void
    ) {
        completionHandler(.performDefaultHandling, nil)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        error = NavigationError(
            domain: WKError.errorDomain,
            code: WKError.webContentProcessTerminated.rawValue,
            message: "The webpage process stopped unexpectedly. Reload the page to continue.",
            failingURL: webView.url
        )
        isLoading = false
        eventHandler?(.webContentProcessTerminated)
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        _ = register(download)
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        _ = register(download)
    }
}

// MARK: - WKUIDelegate

extension BrowserTabController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        emitNewTabRequest(navigationAction.request.url)
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        eventHandler?(.closeRequested)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable () -> Void
    ) {
        let alert = makeJavaScriptAlert(message: message)
        alert.addButton(withTitle: "OK")
        present(alert, in: webView.window) { _ in completionHandler() }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        let alert = makeJavaScriptAlert(message: message)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert, in: webView.window) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (String?) -> Void
    ) {
        let alert = makeJavaScriptAlert(message: prompt)
        let textField = NSTextField(string: defaultText ?? "")
        textField.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = textField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert, in: webView.window) { response in
            completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection

        if let window = webView.window {
            panel.beginSheetModal(for: window) { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        } else {
            completionHandler(panel.runModal() == .OK ? panel.urls : nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void
    ) {
        decisionHandler(mediaCapturePermissionProvider(origin, type))
    }

    private func makeJavaScriptAlert(message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = webView.url?.host ?? "Webpage"
        alert.informativeText = message
        return alert
    }

    private func present(
        _ alert: NSAlert,
        in window: NSWindow?,
        completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void
    ) {
        if let window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }
}

// MARK: - WKDownloadDelegate

extension BrowserTabController: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping @MainActor @Sendable (URL?) -> Void
    ) {
        let activeDownload = register(download)
        do {
            let destination: URL
            switch try downloadDestinationProvider(suggestedFilename) {
            case .useDefaultDirectory:
                let directory = try downloadDirectoryProvider()
                destination = try uniqueDestination(
                    in: directory,
                    suggestedFilename: suggestedFilename
                )
            case let .destination(selectedURL):
                guard selectedURL.isFileURL else {
                    throw ControllerError.invalidDownloadDirectory(selectedURL)
                }
                try FileManager.default.createDirectory(
                    at: selectedURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if FileManager.default.fileExists(atPath: selectedURL.path) {
                    try FileManager.default.removeItem(at: selectedURL)
                }
                destination = selectedURL
            case .cancel:
                activeDownload.terminalEventSent = true
                eventHandler?(.download(.cancelled(id: activeDownload.id, resumeData: nil)))
                activeDownloads.removeValue(forKey: ObjectIdentifier(download))
                completionHandler(nil)
                return
            }
            activeDownload.destinationURL = destination
            eventHandler?(
                .download(
                    .started(
                        DownloadItem(
                            id: activeDownload.id,
                            sourceURL: activeDownload.sourceURL,
                            destinationURL: destination,
                            filename: destination.lastPathComponent,
                            startedAt: activeDownload.startedAt
                        )
                    )
                )
            )
            completionHandler(destination)
        } catch {
            activeDownload.terminalEventSent = true
            eventHandler?(
                .download(
                    .failed(
                        id: activeDownload.id,
                        error: NavigationError(error, fallbackURL: activeDownload.sourceURL),
                        resumeData: nil
                    )
                )
            )
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        guard let activeDownload = activeDownloads.removeValue(forKey: key),
              !activeDownload.terminalEventSent else {
            return
        }

        guard let destinationURL = activeDownload.destinationURL else {
            eventHandler?(
                .download(
                    .failed(
                        id: activeDownload.id,
                        error: NavigationError(
                            ControllerError.downloadFinishedWithoutDestination,
                            fallbackURL: activeDownload.sourceURL
                        ),
                        resumeData: nil
                    )
                )
            )
            return
        }

        activeDownload.terminalEventSent = true
        eventHandler?(
            .download(.finished(id: activeDownload.id, destinationURL: destinationURL))
        )
    }

    func download(
        _ download: WKDownload,
        didFailWithError error: any Error,
        resumeData: Data?
    ) {
        let key = ObjectIdentifier(download)
        let activeDownload = activeDownloads.removeValue(forKey: key) ?? register(download)
        guard !activeDownload.terminalEventSent else { return }
        activeDownload.terminalEventSent = true
        eventHandler?(
            .download(
                .failed(
                    id: activeDownload.id,
                    error: NavigationError(error, fallbackURL: activeDownload.sourceURL),
                    resumeData: resumeData
                )
            )
        )
        activeDownloads.removeValue(forKey: key)
    }
}

@MainActor
private final class ActiveDownload {
    let id = UUID()
    let download: WKDownload
    let sourceURL: URL?
    let startedAt = Date()
    var destinationURL: URL?
    var progressObservation: NSKeyValueObservation?
    var lastReportedProgress = -1.0
    var terminalEventSent = false

    init(download: WKDownload, sourceURL: URL?) {
        self.download = download
        self.sourceURL = sourceURL
    }
}
