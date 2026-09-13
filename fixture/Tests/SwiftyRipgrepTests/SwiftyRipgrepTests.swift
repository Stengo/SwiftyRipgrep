import XCTest
import SwiftyRipgrep

final class SwiftyRipGrepTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SwiftyRipgrepTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func write(_ contents: String, to name: String) throws {
        try contents.write(
            to: directory.appendingPathComponent(name),
            atomically: true,
            encoding: .utf8
        )
    }

    private func names(_ paths: [String]) -> [String] {
        paths.map { URL(fileURLWithPath: $0).lastPathComponent }.sorted()
    }

    func testGrepReturnsFlattenedMatchesWithSubmatches() throws {
        try write("foo bar\n", to: "a.txt")

        let matches = try SwiftyRipgrep().grep(pattern: "foo", in: directory.path)

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].lineNumber, 1)
        XCTAssertEqual(matches[0].line, "foo bar")
        XCTAssertTrue(matches[0].path.hasSuffix("a.txt"))
        XCTAssertEqual(matches[0].submatches.count, 1)
        XCTAssertEqual(matches[0].submatches[0].text, "foo")
        XCTAssertEqual(matches[0].submatches[0].start, 0)
        XCTAssertEqual(matches[0].submatches[0].end, 3)
    }

    func testEventsIncludeBeginMatchAndEnd() throws {
        try write("foo\n", to: "a.txt")

        let events = try SwiftyRipgrep().events(pattern: "foo", in: directory.path)

        XCTAssertEqual(events.count, 3)
        guard case .begin = events[0], case .match = events[1], case .end = events[2] else {
            return XCTFail("Unexpected event sequence: \(events)")
        }
    }

    func testJsonIsRipgrepCompatible() throws {
        try write("foo\n", to: "a.txt")

        let json = try SwiftyRipgrep().json(pattern: "foo", in: directory.path)
        let firstLine = try XCTUnwrap(json.split(separator: "\n").first)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(firstLine.utf8)) as? [String: Any]
        )

        XCTAssertEqual(object["type"] as? String, "begin")
    }

    func testReportsInvalidPatterns() throws {
        try write("foo\n", to: "a.txt")

        XCTAssertThrowsError(try SwiftyRipgrep().grep(pattern: "(", in: directory.path)) { error in
            guard let error = error as? SwiftyRipgrepError, case .invalidPattern = error else {
                return XCTFail("Expected an invalidPattern error, got \(error)")
            }
        }
    }

    func testCaseInsensitiveOption() throws {
        try write("Hello World\n", to: "a.txt")

        var options = RipgrepOptions()
        options.caseInsensitive = true

        let matches = try SwiftyRipgrep().grep(pattern: "hello", in: directory.path, options: options)

        XCTAssertEqual(matches.map(\.line), ["Hello World"])
    }

    func testMaxCountOption() throws {
        try write("foo\nfoo\nfoo\n", to: "a.txt")

        var options = RipgrepOptions()
        options.maxCount = 1

        let matches = try SwiftyRipgrep().grep(pattern: "foo", in: directory.path, options: options)

        XCTAssertEqual(matches.count, 1)
    }

    func testGlobOption() throws {
        try write("needle\n", to: "a.js")
        try write("needle\n", to: "a.txt")

        var options = RipgrepOptions()
        options.globs = ["*.js"]

        let matches = try SwiftyRipgrep().grep(pattern: "needle", in: directory.path, options: options)

        XCTAssertEqual(names(matches.map(\.path)), ["a.js"])
    }

    func testReplaceOption() throws {
        try write("foo bar\n", to: "a.txt")

        var options = RipgrepOptions()
        options.replacement = "baz"

        let events = try SwiftyRipgrep().events(pattern: "foo", in: directory.path, options: options)
        let matchEvent = try XCTUnwrap(events.first { if case .match = $0 { return true } else { return false } })
        guard case .match(let match) = matchEvent else {
            return XCTFail("Expected a match event")
        }
        XCTAssertEqual(match.submatches.first?.replacement?.stringValue, "baz")
    }

    func testFindListsFilesAndRespectsIgnore() throws {
        try write("ignored.txt\n", to: ".ignore")
        try write("needle\n", to: "kept.txt")
        try write("needle\n", to: "ignored.txt")

        let files = try SwiftyRipgrep().find(in: directory.path)

        XCTAssertTrue(names(files).contains("kept.txt"))
        XCTAssertFalse(names(files).contains("ignored.txt"))
    }

    func testFindWithGlob() throws {
        try write("needle\n", to: "a.swift")
        try write("needle\n", to: "a.txt")

        let files = try SwiftyRipgrep().find(glob: "*.swift", in: directory.path)

        XCTAssertEqual(names(files), ["a.swift"])
    }
}
