import XCTest
@testable import Overture

@MainActor
final class ContentBlockerServiceTests: XCTestCase {
    func testBundledRulesCompileInWebKit() async throws {
        let service = ContentBlockerService(
            identifier: "com.overture.browser.tests.\(UUID().uuidString)"
        )

        _ = try await service.ruleList(forceRecompile: true)
    }
}
