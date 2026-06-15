import XCTest
@testable import Lexed

final class KeywordIndexTests: XCTestCase {

    private func index(_ keywords: [Keyword]) -> KeywordIndex {
        let idx = KeywordIndex()
        idx.rebuild(with: keywords)
        return idx
    }

    private func matchedTerms(_ idx: KeywordIndex, _ text: String) -> [String] {
        idx.matches(in: text).map { $0.keyword.term }
    }

    func testMatchesAcronymCaseInsensitively() {
        let idx = index([Keyword(term: "API", definition: "…")])
        XCTAssertEqual(matchedTerms(idx, "We expose an api for partners."), ["API"])
        XCTAssertEqual(matchedTerms(idx, "Our API is documented."), ["API"])
    }

    func testRespectsWordBoundaries() {
        let idx = index([Keyword(term: "REST", definition: "…")])
        // "restaurant" should NOT match "REST".
        XCTAssertTrue(matchedTerms(idx, "We went to a restaurant.").isEmpty)
        XCTAssertEqual(matchedTerms(idx, "We use REST endpoints."), ["REST"])
    }

    func testMatchesAliases() {
        let idx = index([
            Keyword(term: "SLA", definition: "…", aliases: ["service level agreement"])
        ])
        XCTAssertEqual(matchedTerms(idx, "Our service level agreement guarantees uptime."), ["SLA"])
        XCTAssertEqual(matchedTerms(idx, "The SLA is 99.9 percent."), ["SLA"])
    }

    func testMultiWordTermWinsOverSubstring() {
        let idx = index([
            Keyword(term: "learning", definition: "…"),
            Keyword(term: "machine learning", definition: "…")
        ])
        // The longer multi-word term should claim the range.
        XCTAssertEqual(matchedTerms(idx, "I love machine learning."), ["machine learning"])
    }

    func testHandlesSymbolsInTerms() {
        let idx = index([Keyword(term: "C++", definition: "…")])
        XCTAssertEqual(matchedTerms(idx, "I wrote it in C++ years ago."), ["C++"])
    }

    func testFindsMultipleHitsInOrder() {
        let idx = index([
            Keyword(term: "API", definition: "…"),
            Keyword(term: "SLA", definition: "…")
        ])
        let matches = idx.matches(in: "The API has an SLA.")
        XCTAssertEqual(matches.map { $0.keyword.term }, ["API", "SLA"])
        XCTAssertLessThan(matches[0].range.location, matches[1].range.location)
    }

    func testEmptyGlossaryMatchesNothing() {
        let idx = index([])
        XCTAssertTrue(idx.matches(in: "Anything at all.").isEmpty)
    }

    func testRangesAlignToSourceText() {
        let idx = index([Keyword(term: "Kubernetes", definition: "…", aliases: ["k8s"])])
        let text = "Deploy on k8s today."
        let match = try? XCTUnwrap(idx.matches(in: text).first)
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: match!.range).lowercased(), "k8s")
    }
}

final class KeywordModelTests: XCTestCase {

    func testMatchFormsDeduplicateCaseInsensitively() {
        let kw = Keyword(term: "API", definition: "…", aliases: ["api", "API", " application programming interface "])
        XCTAssertEqual(kw.matchForms, ["API", "application programming interface"])
    }

    func testDecodesWithoutIDAndMintsOne() throws {
        let json = #"[{"term":"MVP","definition":"Minimum Viable Product"}]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([Keyword].self, from: json)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].term, "MVP")
        XCTAssertEqual(decoded[0].aliases, [])
    }
}
