import XCTest
@testable import Overture

final class AddressResolverTests: XCTestCase {
    func testDomainUsesHTTPS() {
        XCTAssertEqual(
            AddressResolver.resolve("example.com/path", searchProvider: .google)?.absoluteString,
            "https://example.com/path"
        )
    }

    func testExplicitHTTPIsPreserved() {
        XCTAssertEqual(
            AddressResolver.resolve("http://example.com", searchProvider: .google)?.absoluteString,
            "http://example.com"
        )
    }

    func testSearchTermsUseSelectedProvider() {
        let url = AddressResolver.resolve("swift webkit browser", searchProvider: .duckDuckGo)
        XCTAssertEqual(url?.host, "duckduckgo.com")
        XCTAssertEqual(URLComponents(url: try! XCTUnwrap(url), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "swift webkit browser")
    }

    func testLocalhostDefaultsToHTTP() {
        XCTAssertEqual(
            AddressResolver.resolve("localhost:8080/test", searchProvider: .google)?.absoluteString,
            "http://localhost:8080/test"
        )
    }

    func testBlankInputReturnsNil() {
        XCTAssertNil(AddressResolver.resolve("   ", searchProvider: .google))
    }
}
