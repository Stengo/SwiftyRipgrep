import RustXcframework
internal func ripgrep<GenericIntoRustString: IntoRustString>(_ pattern: GenericIntoRustString, _ path: GenericIntoRustString, _ options: RipgrepOptionsFFI) throws -> RustString {
    try { let val = __swift_bridge__$ripgrep({ let rustString = pattern.intoRustString(); rustString.isOwned = false; return rustString.ptr }(), { let rustString = path.intoRustString(); rustString.isOwned = false; return rustString.ptr }(), options.intoFfiRepr()); if val.is_ok { return RustString(ptr: val.ok_or_err!) } else { throw RustString(ptr: val.ok_or_err!) } }()
}
internal func find_files<GenericIntoRustString: IntoRustString>(_ path: GenericIntoRustString, _ options: RipgrepOptionsFFI) throws -> RustVec<RustString> {
    try { let val = __swift_bridge__$find_files({ let rustString = path.intoRustString(); rustString.isOwned = false; return rustString.ptr }(), options.intoFfiRepr()); if val.is_ok { return RustVec(ptr: val.ok_or_err!) } else { throw RustString(ptr: val.ok_or_err!) } }()
}
internal struct RipgrepOptionsFFI {
    internal var case_insensitive: Bool
    internal var smart_case: Bool
    internal var fixed_strings: Bool
    internal var word: Bool
    internal var line_regexp: Bool
    internal var multiline: Bool
    internal var dot_matches_new_line: Bool
    internal var invert_match: Bool
    internal var unicode: Bool
    internal var crlf: Bool
    internal var max_count: UInt32
    internal var before_context: UInt32
    internal var after_context: UInt32
    internal var passthru: Bool
    internal var include_hidden: Bool
    internal var follow_links: Bool
    internal var same_file_system: Bool
    internal var max_depth: Int32
    internal var max_filesize: UInt64
    internal var respect_ignore: Bool
    internal var respect_git_ignore: Bool
    internal var respect_git_global: Bool
    internal var respect_git_exclude: Bool
    internal var respect_parents: Bool
    internal var require_git: Bool
    internal var parallel: Bool
    internal var has_replace: Bool
    internal var replace: RustString
    internal var globs: RustString
    internal var types: RustString

    internal init(case_insensitive: Bool,smart_case: Bool,fixed_strings: Bool,word: Bool,line_regexp: Bool,multiline: Bool,dot_matches_new_line: Bool,invert_match: Bool,unicode: Bool,crlf: Bool,max_count: UInt32,before_context: UInt32,after_context: UInt32,passthru: Bool,include_hidden: Bool,follow_links: Bool,same_file_system: Bool,max_depth: Int32,max_filesize: UInt64,respect_ignore: Bool,respect_git_ignore: Bool,respect_git_global: Bool,respect_git_exclude: Bool,respect_parents: Bool,require_git: Bool,parallel: Bool,has_replace: Bool,replace: RustString,globs: RustString,types: RustString) {
        self.case_insensitive = case_insensitive
        self.smart_case = smart_case
        self.fixed_strings = fixed_strings
        self.word = word
        self.line_regexp = line_regexp
        self.multiline = multiline
        self.dot_matches_new_line = dot_matches_new_line
        self.invert_match = invert_match
        self.unicode = unicode
        self.crlf = crlf
        self.max_count = max_count
        self.before_context = before_context
        self.after_context = after_context
        self.passthru = passthru
        self.include_hidden = include_hidden
        self.follow_links = follow_links
        self.same_file_system = same_file_system
        self.max_depth = max_depth
        self.max_filesize = max_filesize
        self.respect_ignore = respect_ignore
        self.respect_git_ignore = respect_git_ignore
        self.respect_git_global = respect_git_global
        self.respect_git_exclude = respect_git_exclude
        self.respect_parents = respect_parents
        self.require_git = require_git
        self.parallel = parallel
        self.has_replace = has_replace
        self.replace = replace
        self.globs = globs
        self.types = types
    }

    @inline(__always)
    func intoFfiRepr() -> __swift_bridge__$RipgrepOptionsFFI {
        { let val = self; return __swift_bridge__$RipgrepOptionsFFI(case_insensitive: val.case_insensitive, smart_case: val.smart_case, fixed_strings: val.fixed_strings, word: val.word, line_regexp: val.line_regexp, multiline: val.multiline, dot_matches_new_line: val.dot_matches_new_line, invert_match: val.invert_match, unicode: val.unicode, crlf: val.crlf, max_count: val.max_count, before_context: val.before_context, after_context: val.after_context, passthru: val.passthru, include_hidden: val.include_hidden, follow_links: val.follow_links, same_file_system: val.same_file_system, max_depth: val.max_depth, max_filesize: val.max_filesize, respect_ignore: val.respect_ignore, respect_git_ignore: val.respect_git_ignore, respect_git_global: val.respect_git_global, respect_git_exclude: val.respect_git_exclude, respect_parents: val.respect_parents, require_git: val.require_git, parallel: val.parallel, has_replace: val.has_replace, replace: { let rustString = val.replace.intoRustString(); rustString.isOwned = false; return rustString.ptr }(), globs: { let rustString = val.globs.intoRustString(); rustString.isOwned = false; return rustString.ptr }(), types: { let rustString = val.types.intoRustString(); rustString.isOwned = false; return rustString.ptr }()); }()
    }
}
extension __swift_bridge__$RipgrepOptionsFFI {
    @inline(__always)
    func intoSwiftRepr() -> RipgrepOptionsFFI {
        { let val = self; return RipgrepOptionsFFI(case_insensitive: val.case_insensitive, smart_case: val.smart_case, fixed_strings: val.fixed_strings, word: val.word, line_regexp: val.line_regexp, multiline: val.multiline, dot_matches_new_line: val.dot_matches_new_line, invert_match: val.invert_match, unicode: val.unicode, crlf: val.crlf, max_count: val.max_count, before_context: val.before_context, after_context: val.after_context, passthru: val.passthru, include_hidden: val.include_hidden, follow_links: val.follow_links, same_file_system: val.same_file_system, max_depth: val.max_depth, max_filesize: val.max_filesize, respect_ignore: val.respect_ignore, respect_git_ignore: val.respect_git_ignore, respect_git_global: val.respect_git_global, respect_git_exclude: val.respect_git_exclude, respect_parents: val.respect_parents, require_git: val.require_git, parallel: val.parallel, has_replace: val.has_replace, replace: RustString(ptr: val.replace), globs: RustString(ptr: val.globs), types: RustString(ptr: val.types)); }()
    }
}
extension __swift_bridge__$Option$RipgrepOptionsFFI {
    @inline(__always)
    func intoSwiftRepr() -> Optional<RipgrepOptionsFFI> {
        if self.is_some {
            return self.val.intoSwiftRepr()
        } else {
            return nil
        }
    }

    @inline(__always)
    static func fromSwiftRepr(_ val: Optional<RipgrepOptionsFFI>) -> __swift_bridge__$Option$RipgrepOptionsFFI {
        if let v = val {
            return __swift_bridge__$Option$RipgrepOptionsFFI(is_some: true, val: v.intoFfiRepr())
        } else {
            return __swift_bridge__$Option$RipgrepOptionsFFI(is_some: false, val: __swift_bridge__$RipgrepOptionsFFI())
        }
    }
}


