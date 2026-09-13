import Foundation

/// A byte string that ripgrep emits as either readable text or base64-encoded
/// bytes when the underlying data is not valid UTF-8.
public enum RipgrepBytes: Equatable, Sendable {
    case text(String)
    case bytes(Data)

    /// A lossy UTF-8 view, suitable for display. Use the raw `Data` when byte
    /// offsets must line up with the original content.
    public var stringValue: String {
        switch self {
        case .text(let text):
            return text
        case .bytes(let data):
            return String(decoding: data, as: UTF8.self)
        }
    }
}

extension RipgrepBytes: Codable {
    private enum CodingKeys: String, CodingKey { case text, bytes }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try container.decodeIfPresent(String.self, forKey: .text) {
            self = .text(text)
        } else {
            let base64 = try container.decode(String.self, forKey: .bytes)
            guard let data = Data(base64Encoded: base64) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .bytes,
                    in: container,
                    debugDescription: "ripgrep emitted invalid base64"
                )
            }
            self = .bytes(data)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .bytes(let data):
            try container.encode(data.base64EncodedString(), forKey: .bytes)
        }
    }
}

/// A single message from ripgrep's JSON Lines output.
public enum RipgrepEvent: Equatable, Sendable {
    case begin(RipgrepBegin)
    case match(RipgrepMatch)
    case context(RipgrepMatch)
    case end(RipgrepEnd)
    case summary(RipgrepSummary)
}

extension RipgrepEvent: Decodable {
    private enum CodingKeys: String, CodingKey { case type, data }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "begin":
            self = .begin(try container.decode(RipgrepBegin.self, forKey: .data))
        case "match":
            self = .match(try container.decode(RipgrepMatch.self, forKey: .data))
        case "context":
            self = .context(try container.decode(RipgrepMatch.self, forKey: .data))
        case "end":
            self = .end(try container.decode(RipgrepEnd.self, forKey: .data))
        case "summary":
            self = .summary(try container.decode(RipgrepSummary.self, forKey: .data))
        case let other:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ripgrep event: \(other)"
            )
        }
    }
}

public struct RipgrepBegin: Decodable, Equatable, Sendable {
    public let path: RipgrepBytes
}

public struct RipgrepMatch: Decodable, Equatable, Sendable {
    public let path: RipgrepBytes
    public let lines: RipgrepBytes
    public let lineNumber: UInt64?
    public let absoluteOffset: UInt64
    public let submatches: [Submatch]

    enum CodingKeys: String, CodingKey {
        case path, lines, submatches
        case lineNumber = "line_number"
        case absoluteOffset = "absolute_offset"
    }

    public struct Submatch: Decodable, Equatable, Sendable {
        public let match: RipgrepBytes
        public let replacement: RipgrepBytes?
        /// Byte range within `lines`, not a column number.
        public let start: UInt64
        public let end: UInt64
    }
}

public struct RipgrepEnd: Decodable, Equatable, Sendable {
    public let path: RipgrepBytes?
    public let binaryOffset: UInt64?
    public let stats: RipgrepStats

    enum CodingKeys: String, CodingKey {
        case path, stats
        case binaryOffset = "binary_offset"
    }
}

public struct RipgrepSummary: Decodable, Equatable, Sendable {
    public let elapsedTotal: RipgrepElapsed
    public let stats: RipgrepStats

    enum CodingKeys: String, CodingKey {
        case stats
        case elapsedTotal = "elapsed_total"
    }
}

public struct RipgrepStats: Decodable, Equatable, Sendable {
    public let elapsed: RipgrepElapsed
    public let searches: UInt64
    public let searchesWithMatch: UInt64
    public let bytesSearched: UInt64
    public let bytesPrinted: UInt64
    public let matchedLines: UInt64
    public let matches: UInt64

    enum CodingKeys: String, CodingKey {
        case elapsed, searches, matches
        case searchesWithMatch = "searches_with_match"
        case bytesSearched = "bytes_searched"
        case bytesPrinted = "bytes_printed"
        case matchedLines = "matched_lines"
    }
}

public struct RipgrepElapsed: Decodable, Equatable, Sendable {
    public let secs: UInt64
    public let nanos: UInt64
    public let human: String
}

/// A flattened match for callers that just want path, line and text.
public struct SwiftyRipgrepMatch: Codable, Equatable, Sendable {
    public let path: String
    public let lineNumber: Int
    public let line: String
    public let submatches: [Submatch]

    public struct Submatch: Codable, Equatable, Sendable {
        public let text: String
        public let start: Int
        public let end: Int
    }

    public init(path: String, lineNumber: Int, line: String, submatches: [Submatch] = []) {
        self.path = path
        self.lineNumber = lineNumber
        self.line = line
        self.submatches = submatches
    }

    init(_ match: RipgrepMatch) {
        self.path = match.path.stringValue
        self.lineNumber = Int(match.lineNumber ?? 0)
        self.line = match.lines.stringValue.trimmingCharacters(in: .newlines)
        self.submatches = match.submatches.map {
            Submatch(text: $0.match.stringValue, start: Int($0.start), end: Int($0.end))
        }
    }
}

/// Options controlling how ripgrep performs a search.
public struct RipgrepOptions: Equatable, Sendable {
    public var caseInsensitive: Bool
    public var smartCase: Bool
    public var fixedStrings: Bool
    public var word: Bool
    public var lineRegexp: Bool
    public var multiline: Bool
    public var dotMatchesNewLine: Bool
    public var invertMatch: Bool
    public var unicode: Bool
    public var crlf: Bool
    public var maxCount: UInt32
    public var beforeContext: UInt32
    public var afterContext: UInt32
    public var passthru: Bool
    public var includesHidden: Bool
    public var followsSymlinks: Bool
    public var oneFileSystem: Bool
    /// Maximum directory depth; a negative value means unlimited.
    public var maxDepth: Int32
    /// Skip files larger than this many bytes; zero means no limit.
    public var maxFileSize: UInt64
    public var respectsIgnoreFiles: Bool
    public var respectsVCSIgnores: Bool
    public var respectsGlobalIgnores: Bool
    public var respectsExcludeIgnores: Bool
    public var respectsParentIgnores: Bool
    public var requiresGitRepository: Bool
    public var parallel: Bool
    /// When set, matched text is replaced in the reported JSON submatches.
    public var replacement: String?
    /// Glob patterns, applied like `--glob`. Prefix with `!` to exclude.
    public var globs: [String]
    /// File type names, applied like `--type`. Prefix with `!` to negate.
    public var types: [String]

    public init(
        caseInsensitive: Bool = false,
        smartCase: Bool = false,
        fixedStrings: Bool = false,
        word: Bool = false,
        lineRegexp: Bool = false,
        multiline: Bool = false,
        dotMatchesNewLine: Bool = false,
        invertMatch: Bool = false,
        unicode: Bool = true,
        crlf: Bool = false,
        maxCount: UInt32 = 0,
        beforeContext: UInt32 = 0,
        afterContext: UInt32 = 0,
        passthru: Bool = false,
        includesHidden: Bool = false,
        followsSymlinks: Bool = false,
        oneFileSystem: Bool = false,
        maxDepth: Int32 = -1,
        maxFileSize: UInt64 = 0,
        respectsIgnoreFiles: Bool = true,
        respectsVCSIgnores: Bool = true,
        respectsGlobalIgnores: Bool = true,
        respectsExcludeIgnores: Bool = true,
        respectsParentIgnores: Bool = true,
        requiresGitRepository: Bool = true,
        parallel: Bool = false,
        replacement: String? = nil,
        globs: [String] = [],
        types: [String] = []
    ) {
        self.caseInsensitive = caseInsensitive
        self.smartCase = smartCase
        self.fixedStrings = fixedStrings
        self.word = word
        self.lineRegexp = lineRegexp
        self.multiline = multiline
        self.dotMatchesNewLine = dotMatchesNewLine
        self.invertMatch = invertMatch
        self.unicode = unicode
        self.crlf = crlf
        self.maxCount = maxCount
        self.beforeContext = beforeContext
        self.afterContext = afterContext
        self.passthru = passthru
        self.includesHidden = includesHidden
        self.followsSymlinks = followsSymlinks
        self.oneFileSystem = oneFileSystem
        self.maxDepth = maxDepth
        self.maxFileSize = maxFileSize
        self.respectsIgnoreFiles = respectsIgnoreFiles
        self.respectsVCSIgnores = respectsVCSIgnores
        self.respectsGlobalIgnores = respectsGlobalIgnores
        self.respectsExcludeIgnores = respectsExcludeIgnores
        self.respectsParentIgnores = respectsParentIgnores
        self.requiresGitRepository = requiresGitRepository
        self.parallel = parallel
        self.replacement = replacement
        self.globs = globs
        self.types = types
    }

    func intoFfiRepr() -> RipgrepOptionsFFI {
        let vcs = respectsIgnoreFiles && respectsVCSIgnores
        return RipgrepOptionsFFI(
            case_insensitive: caseInsensitive,
            smart_case: smartCase,
            fixed_strings: fixedStrings,
            word: word,
            line_regexp: lineRegexp,
            multiline: multiline,
            dot_matches_new_line: dotMatchesNewLine,
            invert_match: invertMatch,
            unicode: unicode,
            crlf: crlf,
            max_count: maxCount,
            before_context: beforeContext,
            after_context: afterContext,
            passthru: passthru,
            include_hidden: includesHidden,
            follow_links: followsSymlinks,
            same_file_system: oneFileSystem,
            max_depth: maxDepth,
            max_filesize: maxFileSize,
            respect_ignore: respectsIgnoreFiles,
            respect_git_ignore: vcs,
            respect_git_global: vcs && respectsGlobalIgnores,
            respect_git_exclude: vcs && respectsExcludeIgnores,
            respect_parents: respectsIgnoreFiles && respectsParentIgnores,
            require_git: requiresGitRepository,
            parallel: parallel,
            has_replace: replacement != nil,
            replace: RustString(replacement ?? ""),
            globs: RustString(globs.joined(separator: "\n")),
            types: RustString(types.joined(separator: "\n"))
        )
    }
}

/// An error produced while searching.
public enum SwiftyRipgrepError: Error, Equatable {
    /// The regular expression could not be compiled.
    case invalidPattern(String)
    /// The search failed for some other reason.
    case searchFailed(String)
}

/// The interface implemented by `SwiftyRipgrep`.
public protocol SwiftyRipgrepping {
    func grep(pattern: String, in path: String, options: RipgrepOptions) throws -> [SwiftyRipgrepMatch]
    func find(in path: String, options: RipgrepOptions) throws -> [String]
}

/// An in-process, embeddable port of [ripgrep](https://github.com/BurntSushi/ripgrep).
///
/// The search engine is compiled into the binary; no separate `rg` process is
/// spawned and no command line tool needs to be bundled.
public final class SwiftyRipgrep: SwiftyRipgrepping {
    public init() {}

    /// Run a search and return ripgrep's raw JSON Lines output.
    public func json(
        pattern: String,
        in path: String,
        options: RipgrepOptions = RipgrepOptions()
    ) throws -> String {
        do {
            return try ripgrep(pattern, path, options.intoFfiRepr()).toString()
        } catch let error as RustString {
            throw Self.mapError(error.toString())
        } catch {
            throw SwiftyRipgrepError.searchFailed(String(describing: error))
        }
    }

    /// Run a search and decode ripgrep's JSON Lines output.
    public func events(
        pattern: String,
        in path: String,
        options: RipgrepOptions = RipgrepOptions()
    ) throws -> [RipgrepEvent] {
        try Self.decodeEvents(try json(pattern: pattern, in: path, options: options))
    }

    /// Run a search and return only its matches, flattened for convenience.
    public func grep(
        pattern: String,
        in path: String,
        options: RipgrepOptions = RipgrepOptions()
    ) throws -> [SwiftyRipgrepMatch] {
        try events(pattern: pattern, in: path, options: options).compactMap { event in
            guard case .match(let match) = event else { return nil }
            return SwiftyRipgrepMatch(match)
        }
    }

    /// List files, honoring ignore rules and any glob/type filters in `options`.
    public func find(
        in path: String,
        options: RipgrepOptions = RipgrepOptions()
    ) throws -> [String] {
        do {
            return try find_files(path, options.intoFfiRepr()).map { $0.as_str().toString() }
        } catch let error as RustString {
            throw Self.mapError(error.toString())
        } catch {
            throw SwiftyRipgrepError.searchFailed(String(describing: error))
        }
    }

    /// List files matching a single glob, honoring ignore rules.
    public func find(
        glob: String,
        in path: String,
        options: RipgrepOptions = RipgrepOptions()
    ) throws -> [String] {
        var options = options
        options.globs = [glob] + options.globs
        return try find(in: path, options: options)
    }

    private static func decodeEvents(_ output: String) throws -> [RipgrepEvent] {
        let decoder = JSONDecoder()
        return try output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { try decoder.decode(RipgrepEvent.self, from: Data($0.utf8)) }
    }

    private static func mapError(_ message: String) -> SwiftyRipgrepError {
        message.hasPrefix("invalid pattern")
            ? .invalidPattern(message)
            : .searchFailed(message)
    }
}
