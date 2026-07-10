import Foundation

enum BrowserPersistenceError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case corruptedProfile(URL, reason: String)
    case readFailed(URL, reason: String)
    case writeFailed(URL, reason: String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(found, supported):
            "Browser profile schema \(found) is not supported; this build supports schema \(supported)."
        case let .corruptedProfile(url, reason):
            "The browser profile at \(url.path) is corrupted: \(reason)"
        case let .readFailed(url, reason):
            "The browser profile at \(url.path) could not be read: \(reason)"
        case let .writeFailed(url, reason):
            "The browser profile at \(url.path) could not be saved: \(reason)"
        }
    }
}

actor BrowserPersistence {
    static let defaultFileName = "browser-profile.json"

    nonisolated let directoryURL: URL
    nonisolated let fileURL: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        directoryURL: URL? = nil,
        fileName: String = BrowserPersistence.defaultFileName,
        fileManager: FileManager = .default
    ) {
        let resolvedDirectory = directoryURL
            ?? BrowserPersistence.defaultDirectoryURL(fileManager: fileManager)

        self.directoryURL = resolvedDirectory
        self.fileURL = resolvedDirectory.appendingPathComponent(fileName, isDirectory: false)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder

        self.decoder = JSONDecoder()
    }

    nonisolated static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        if let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            return applicationSupport.appendingPathComponent("Overture", isDirectory: true)
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Application Support/Overture", isDirectory: true)
    }

    func load() throws -> BrowserProfile {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .defaultProfile
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw BrowserPersistenceError.readFailed(
                fileURL,
                reason: String(describing: error)
            )
        }

        let envelope: VersionEnvelope
        do {
            envelope = try decoder.decode(VersionEnvelope.self, from: data)
        } catch {
            throw BrowserPersistenceError.corruptedProfile(
                fileURL,
                reason: "missing or invalid schema metadata"
            )
        }

        guard envelope.schemaVersion == BrowserProfile.currentSchemaVersion else {
            throw BrowserPersistenceError.unsupportedSchemaVersion(
                found: envelope.schemaVersion,
                supported: BrowserProfile.currentSchemaVersion
            )
        }

        do {
            return try decoder.decode(BrowserProfile.self, from: data).persistableCopy()
        } catch {
            throw BrowserPersistenceError.corruptedProfile(
                fileURL,
                reason: String(describing: error)
            )
        }
    }

    func save(_ profile: BrowserProfile) throws {
        guard profile.schemaVersion == BrowserProfile.currentSchemaVersion else {
            throw BrowserPersistenceError.unsupportedSchemaVersion(
                found: profile.schemaVersion,
                supported: BrowserProfile.currentSchemaVersion
            )
        }

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(profile.persistableCopy())
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw BrowserPersistenceError.writeFailed(
                fileURL,
                reason: String(describing: error)
            )
        }
    }

    func reset() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw BrowserPersistenceError.writeFailed(
                fileURL,
                reason: String(describing: error)
            )
        }
    }

    func profileExists() -> Bool {
        fileManager.fileExists(atPath: fileURL.path)
    }

    private struct VersionEnvelope: Decodable {
        let schemaVersion: Int
    }
}
