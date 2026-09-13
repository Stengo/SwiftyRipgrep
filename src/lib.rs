#![allow(non_snake_case)]

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use grep_printer::JSONBuilder;
use grep_regex::{RegexMatcher, RegexMatcherBuilder};
use grep_searcher::{BinaryDetection, Searcher, SearcherBuilder};
use ignore::overrides::OverrideBuilder;
use ignore::types::TypesBuilder;
use ignore::{WalkBuilder, WalkState};

type FileChunk = (PathBuf, Vec<u8>);
type CollectedChunks = Arc<Mutex<Vec<FileChunk>>>;

#[swift_bridge::bridge]
mod ffi {
    #[swift_bridge(swift_repr = "struct")]
    struct RipgrepOptionsFFI {
        case_insensitive: bool,
        smart_case: bool,
        fixed_strings: bool,
        word: bool,
        line_regexp: bool,
        multiline: bool,
        dot_matches_new_line: bool,
        invert_match: bool,
        unicode: bool,
        crlf: bool,
        max_count: u32,
        before_context: u32,
        after_context: u32,
        passthru: bool,
        include_hidden: bool,
        follow_links: bool,
        same_file_system: bool,
        max_depth: i32,
        max_filesize: u64,
        respect_ignore: bool,
        respect_git_ignore: bool,
        respect_git_global: bool,
        respect_git_exclude: bool,
        respect_parents: bool,
        require_git: bool,
        parallel: bool,
        has_replace: bool,
        replace: String,
        globs: String,
        types: String,
    }

    extern "Rust" {
        fn ripgrep(
            pattern: String,
            path: String,
            options: RipgrepOptionsFFI,
        ) -> Result<String, String>;

        fn find_files(path: String, options: RipgrepOptionsFFI) -> Result<Vec<String>, String>;
    }
}

fn ripgrep(
    pattern: String,
    path: String,
    options: ffi::RipgrepOptionsFFI,
) -> Result<String, String> {
    let options = Options::new(&options);
    let matcher = make_matcher(&pattern, &options)?;
    let walker = make_walker(&path, &options)?;

    let mut chunks: Vec<FileChunk> = Vec::new();
    if options.parallel {
        let collected = Arc::new(Mutex::new(Vec::new()));
        collect_parallel(&matcher, walker, &options, &collected);
        chunks = std::mem::take(&mut *collected.lock().unwrap());
    } else {
        let mut searcher = make_searcher(&options);
        for result in walker.build() {
            let entry = match result {
                Ok(entry) => entry,
                Err(_) => continue,
            };
            if !entry.file_type().is_some_and(|file_type| file_type.is_file()) {
                continue;
            }
            let bytes = search_one(
                &matcher,
                &mut searcher,
                entry.path(),
                options.replacement.as_deref(),
            );
            if !bytes.is_empty() {
                chunks.push((entry.path().to_path_buf(), bytes));
            }
        }
    }

    chunks.sort_by(|left, right| left.0.cmp(&right.0));
    let mut output = Vec::new();
    for (_, bytes) in &chunks {
        output.extend_from_slice(bytes);
    }
    String::from_utf8(output).map_err(|error| error.to_string())
}

fn find_files(path: String, options: ffi::RipgrepOptionsFFI) -> Result<Vec<String>, String> {
    let options = Options::new(&options);
    let walker = make_walker(&path, &options)?;

    let mut files = Vec::new();
    for result in walker.build() {
        let entry = match result {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        if entry.file_type().is_some_and(|file_type| file_type.is_file()) {
            files.push(entry.path().to_string_lossy().into_owned());
        }
    }
    files.sort();
    Ok(files)
}

fn collect_parallel(
    matcher: &RegexMatcher,
    walker: WalkBuilder,
    options: &Options,
    collected: &CollectedChunks,
) {
    let matcher = Arc::new(matcher.clone());
    let options = Arc::new(options.clone());

    walker.build_parallel().run({
        let matcher = Arc::clone(&matcher);
        let options = Arc::clone(&options);
        let collected = Arc::clone(collected);
        move || {
            let matcher = Arc::clone(&matcher);
            let options = Arc::clone(&options);
            let collected = Arc::clone(&collected);
            let mut searcher = make_searcher(&options);
            Box::new(move |result| {
                if let Ok(entry) = result {
                    if entry.file_type().is_some_and(|file_type| file_type.is_file()) {
                        let bytes = search_one(
                            &matcher,
                            &mut searcher,
                            entry.path(),
                            options.replacement.as_deref(),
                        );
                        if !bytes.is_empty() {
                            collected
                                .lock()
                                .unwrap()
                                .push((entry.path().to_path_buf(), bytes));
                        }
                    }
                }
                WalkState::Continue
            })
        }
    });
}

fn search_one(
    matcher: &RegexMatcher,
    searcher: &mut Searcher,
    path: &Path,
    replacement: Option<&[u8]>,
) -> Vec<u8> {
    let mut printer = JSONBuilder::new()
        .replacement(replacement.map(<[u8]>::to_vec))
        .build(Vec::<u8>::new());
    {
        let sink = printer.sink_with_path(matcher, path);
        let _ = searcher.search_path(matcher, path, sink);
    }
    printer.into_inner()
}

fn make_matcher(pattern: &str, options: &Options) -> Result<RegexMatcher, String> {
    let mut builder = RegexMatcherBuilder::new();
    builder
        .case_insensitive(options.case_insensitive)
        .case_smart(options.smart_case && !options.case_insensitive)
        .fixed_strings(options.fixed_strings)
        .word(options.word)
        .whole_line(options.line_regexp)
        .multi_line(options.multiline)
        .dot_matches_new_line(options.dot_matches_new_line)
        .unicode(options.unicode)
        .crlf(options.crlf);
    builder
        .build(pattern)
        .map_err(|error| format!("invalid pattern: {error}"))
}

fn make_searcher(options: &Options) -> Searcher {
    let mut builder = SearcherBuilder::new();
    builder
        .line_number(true)
        .invert_match(options.invert_match)
        .multi_line(options.multiline)
        .before_context(options.before_context as usize)
        .after_context(options.after_context as usize)
        .passthru(options.passthru)
        .binary_detection(BinaryDetection::quit(b'\x00'));
    if options.max_count > 0 {
        builder.max_matches(Some(u64::from(options.max_count)));
    }
    builder.build()
}

fn make_walker(path: &str, options: &Options) -> Result<WalkBuilder, String> {
    let mut builder = WalkBuilder::new(path);
    builder
        .hidden(!options.include_hidden)
        .follow_links(options.follow_links)
        .same_file_system(options.same_file_system)
        .ignore(options.respect_ignore)
        .git_ignore(options.respect_git_ignore)
        .git_global(options.respect_git_global)
        .git_exclude(options.respect_git_exclude)
        .parents(options.respect_parents)
        .require_git(options.require_git);
    if options.max_depth >= 0 {
        builder.max_depth(Some(options.max_depth as usize));
    }
    if options.max_filesize > 0 {
        builder.max_filesize(Some(options.max_filesize));
    }

    if !options.globs.is_empty() {
        let mut overrides = OverrideBuilder::new(path);
        for glob in &options.globs {
            overrides
                .add(glob)
                .map_err(|error| format!("invalid glob {glob:?}: {error}"))?;
        }
        let overrides = overrides
            .build()
            .map_err(|error| format!("invalid glob: {error}"))?;
        builder.overrides(overrides);
    }

    if !options.types.is_empty() {
        let mut types = TypesBuilder::new();
        types.add_defaults();
        for entry in &options.types {
            match entry.strip_prefix('!') {
                Some(name) => {
                    types.negate(name);
                }
                None => {
                    types.select(entry);
                }
            }
        }
        let types = types
            .build()
            .map_err(|error| format!("invalid type: {error}"))?;
        builder.types(types);
    }

    Ok(builder)
}

#[derive(Clone)]
struct Options {
    case_insensitive: bool,
    smart_case: bool,
    fixed_strings: bool,
    word: bool,
    line_regexp: bool,
    multiline: bool,
    dot_matches_new_line: bool,
    invert_match: bool,
    unicode: bool,
    crlf: bool,
    max_count: u32,
    before_context: u32,
    after_context: u32,
    passthru: bool,
    include_hidden: bool,
    follow_links: bool,
    same_file_system: bool,
    max_depth: i32,
    max_filesize: u64,
    respect_ignore: bool,
    respect_git_ignore: bool,
    respect_git_global: bool,
    respect_git_exclude: bool,
    respect_parents: bool,
    require_git: bool,
    parallel: bool,
    replacement: Option<Vec<u8>>,
    globs: Vec<String>,
    types: Vec<String>,
}

impl Options {
    fn new(options: &ffi::RipgrepOptionsFFI) -> Self {
        Self {
            case_insensitive: options.case_insensitive,
            smart_case: options.smart_case,
            fixed_strings: options.fixed_strings,
            word: options.word,
            line_regexp: options.line_regexp,
            multiline: options.multiline,
            dot_matches_new_line: options.dot_matches_new_line,
            invert_match: options.invert_match,
            unicode: options.unicode,
            crlf: options.crlf,
            max_count: options.max_count,
            before_context: options.before_context,
            after_context: options.after_context,
            passthru: options.passthru,
            include_hidden: options.include_hidden,
            follow_links: options.follow_links,
            same_file_system: options.same_file_system,
            max_depth: options.max_depth,
            max_filesize: options.max_filesize,
            respect_ignore: options.respect_ignore,
            respect_git_ignore: options.respect_git_ignore,
            respect_git_global: options.respect_git_global,
            respect_git_exclude: options.respect_git_exclude,
            respect_parents: options.respect_parents,
            require_git: options.require_git,
            parallel: options.parallel,
            replacement: options
                .has_replace
                .then(|| options.replace.clone().into_bytes()),
            globs: split_lines(&options.globs),
            types: split_lines(&options.types),
        }
    }
}

fn split_lines(value: &str) -> Vec<String> {
    value
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(str::to_string)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn options() -> ffi::RipgrepOptionsFFI {
        ffi::RipgrepOptionsFFI {
            case_insensitive: false,
            smart_case: false,
            fixed_strings: false,
            word: false,
            line_regexp: false,
            multiline: false,
            dot_matches_new_line: false,
            invert_match: false,
            unicode: true,
            crlf: false,
            max_count: 0,
            before_context: 0,
            after_context: 0,
            passthru: false,
            include_hidden: false,
            follow_links: false,
            same_file_system: false,
            max_depth: -1,
            max_filesize: 0,
            respect_ignore: true,
            respect_git_ignore: true,
            respect_git_global: true,
            respect_git_exclude: true,
            respect_parents: true,
            require_git: true,
            parallel: false,
            has_replace: false,
            replace: String::new(),
            globs: String::new(),
            types: String::new(),
        }
    }

    fn search(pattern: &str, path: &Path, options: ffi::RipgrepOptionsFFI) -> Vec<serde_json::Value> {
        let output = ripgrep(pattern.to_string(), path.to_string_lossy().into_owned(), options)
            .expect("search should succeed");
        output
            .lines()
            .filter(|line| !line.is_empty())
            .map(|line| serde_json::from_str(line).expect("valid json"))
            .collect()
    }

    fn match_events(events: &[serde_json::Value]) -> Vec<&serde_json::Value> {
        events
            .iter()
            .filter(|event| event["type"] == "match")
            .collect()
    }

    #[test]
    fn emits_json_lines_with_submatches() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("a.txt"), "foo bar\n").unwrap();

        let events = search("foo", dir.path(), options());
        assert_eq!(events[0]["type"], "begin");
        assert_eq!(events[1]["type"], "match");
        let data = &events[1]["data"];
        assert_eq!(data["line_number"], 1);
        assert_eq!(data["absolute_offset"], 0);
        assert_eq!(data["lines"]["text"], "foo bar\n");
        assert_eq!(data["submatches"][0]["start"], 0);
        assert_eq!(data["submatches"][0]["end"], 3);
        assert_eq!(data["submatches"][0]["match"]["text"], "foo");
        assert_eq!(events.last().unwrap()["type"], "end");
    }

    #[test]
    fn reports_invalid_patterns() {
        let dir = tempfile::tempdir().unwrap();
        let error = ripgrep("(".to_string(), dir.path().to_string_lossy().into_owned(), options());
        assert!(error.unwrap_err().starts_with("invalid pattern"));
    }

    #[test]
    fn honors_max_count_per_file() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("a.txt"), "foo\nfoo\nfoo\n").unwrap();

        let mut options = options();
        options.max_count = 1;
        let events = search("foo", dir.path(), options);
        assert_eq!(match_events(&events).len(), 1);
    }

    #[test]
    fn filters_by_glob() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("a.js"), "needle\n").unwrap();
        fs::write(dir.path().join("a.txt"), "needle\n").unwrap();

        let mut options = options();
        options.globs = "*.js".to_string();
        let events = search("needle", dir.path(), options);
        let paths: Vec<&str> = match_events(&events)
            .iter()
            .map(|event| event["data"]["path"]["text"].as_str().unwrap())
            .collect();
        assert_eq!(paths.len(), 1);
        assert!(paths[0].ends_with("a.js"));
    }

    #[test]
    fn filters_by_type() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("a.rs"), "needle\n").unwrap();
        fs::write(dir.path().join("a.txt"), "needle\n").unwrap();

        let mut options = options();
        options.types = "rust".to_string();
        let events = search("needle", dir.path(), options);
        let paths: Vec<&str> = match_events(&events)
            .iter()
            .map(|event| event["data"]["path"]["text"].as_str().unwrap())
            .collect();
        assert_eq!(paths.len(), 1);
        assert!(paths[0].ends_with("a.rs"));
    }

    #[test]
    fn applies_replacement() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("a.txt"), "foo bar\n").unwrap();

        let mut options = options();
        options.has_replace = true;
        options.replace = "baz".to_string();
        let events = search("foo", dir.path(), options);
        let submatches = &match_events(&events)[0]["data"]["submatches"];
        assert_eq!(submatches[0]["replacement"]["text"], "baz");
    }

    #[test]
    fn find_lists_files_and_respects_ignore() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join(".ignore"), "ignored.txt\n").unwrap();
        fs::write(dir.path().join("kept.txt"), "needle\n").unwrap();
        fs::write(dir.path().join("ignored.txt"), "needle\n").unwrap();

        let files = find_files(dir.path().to_string_lossy().into_owned(), options()).unwrap();
        let names: Vec<String> = files
            .iter()
            .map(|file| Path::new(file).file_name().unwrap().to_string_lossy().into_owned())
            .collect();
        assert!(names.contains(&"kept.txt".to_string()));
        assert!(!names.contains(&"ignored.txt".to_string()));
    }

    fn normalize(output: &str) -> Vec<serde_json::Value> {
        output
            .lines()
            .filter(|line| !line.is_empty())
            .map(|line| {
                let mut event: serde_json::Value = serde_json::from_str(line).unwrap();
                if event["type"] == "end" {
                    event["data"].as_object_mut().unwrap().remove("stats");
                }
                event
            })
            .collect()
    }

    #[test]
    fn parallel_matches_sequential() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("a.txt"), "foo\nbar\n").unwrap();
        fs::write(dir.path().join("b.txt"), "foo\n").unwrap();

        let sequential = ripgrep(
            "foo".to_string(),
            dir.path().to_string_lossy().into_owned(),
            options(),
        )
        .unwrap();

        let mut parallel_options = options();
        parallel_options.parallel = true;
        let parallel = ripgrep(
            "foo".to_string(),
            dir.path().to_string_lossy().into_owned(),
            parallel_options,
        )
        .unwrap();

        assert_eq!(normalize(&sequential), normalize(&parallel));
    }
}
