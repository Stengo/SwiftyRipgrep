# SwiftyRipgrep

[![SwiftyRipgrep](https://github.com/Stengo/SwiftyRipgrep/actions/workflows/SwiftyRipgrep.yml/badge.svg)](https://github.com/Stengo/SwiftyRipgrep/actions/workflows/SwiftyRipgrep.yml)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-lightgrey)
![iOS Badge](https://img.shields.io/badge/iOS-13-green)
![macOS Badge](https://img.shields.io/badge/macOS-11-green)

This repository contains a Swift package that embeds [ripgrep](https://github.com/BurntSushi/ripgrep) so it can be used programmatically in iOS (device and simulator), Mac Catalyst and macOS.

The search engine is compiled into a static library that is linked into your app. No `rg` executable is spawned at runtime and no command line tool needs to be bundled. Consumers of the Swift package do **not** need a Rust toolchain: the prebuilt `RustXcframework.xcframework` is checked in and distributed as a Swift Package binary target.

## Usage

SwiftyRipgrep is distributed as a Swift Package. Add the dependency to your project through Xcode or in the `Package.swift` of your package:

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/Stengo/SwiftyRipgrep.git", from: "15.2.0")
    ],
    ...
)
```

Then search from Swift:

```swift
import SwiftyRipgrep

let ripgrep = SwiftyRipgrep()
let matches = try ripgrep.grep(pattern: "TODO", in: "/path/to/project")

for match in matches {
    print("\(match.path):\(match.lineNumber): \(match.line)")
}
```

`grep` accepts a `RipgrepOptions` value to control matching and traversal:

```swift
var options = RipgrepOptions()
options.caseInsensitive = true
options.includesHidden = false
options.globs = ["*.swift"]
options.types = ["rust"]
options.beforeContext = 2
options.parallel = true

let matches = try ripgrep.grep(pattern: "fixme", in: directory, options: options)
```

`RipgrepOptions` mirrors ripgrep's search, filtering, context and ignore
options, including globs (`globs`), file types (`types`), `word`,
`lineRegexp`, `multiline`, `invertMatch`, `maxCount`, and replacement text.

For full fidelity, use ripgrep's JSON Lines format. `events` decodes it into
typed values and `json` returns the raw output, identical to `rg --json`:

```swift
let events = try ripgrep.events(pattern: "TODO", in: directory)
let json = try ripgrep.json(pattern: "TODO", in: directory)
```

Matches carry submatch text and byte offsets, and files can be listed with the
same ignore/glob/type filtering:

```swift
switch events.first {
case .match(let match):
    print("\(match.path.stringValue):\(match.lineNumber ?? 0): \(match.absoluteOffset)")
    for submatch in match.submatches {
        print("  \(submatch.start)..<\(submatch.end)")
    }
default:
    break
}

let files = try ripgrep.find(glob: "*.swift", in: directory)
```

Invalid patterns throw `SwiftyRipgrepError.invalidPattern`.

> **Regex engine:** Matching uses ripgrep's default regex engine. PCRE2
> features such as look-around and backreferences are not compiled in.

> **Version:** The version of SwiftyRipgrep aligns with the version of [ripgrep](https://github.com/BurntSushi/ripgrep) embedded, so version 15.2.0 indicates that the Swift package embeds ripgrep 15.2.0.

## Development

### System dependencies

- [Rust](https://rust.sh/) (nightly, with the `rust-src` component)
- [Xcode](https://developer.apple.com/xcode/)
- [Ruby](https://www.ruby-lang.org/en/) 3.2
- [swift-bridge-cli](https://github.com/chinedufn/swift-bridge) 0.1.59

Install the Rust toolchain components with:

```bash
rustup component add rust-src
cargo install swift-bridge-cli --version 0.1.59 --locked
```

### Generate the Swift Package

The project uses [swift-bridge](https://chinedufn.github.io/swift-bridge/index.html), a Rust tool that leverages macros and other build-time tools to generate the Swift Package from the Rust code. If you change the Rust code or update Cargo dependencies you'll have to run `bin/generate.rb`. The script will build the Rust library for every supported target, produce universal binaries, and regenerate the `Package.swift`, the content under `Sources`, and the `RustXcframework.xcframework` directory at the root.

This is only required when the Rust side changes. Consumers of the package never run it.

### Testing

The repository contains a Swift package under `fixture` with a tests target that exercises the public interface of the `SwiftyRipgrep` package generated at the root. Run the tests with:

```bash
swift test --package-path ./fixture
```

The Rust side has its own unit tests:

```bash
cargo test
```

## References

- [From Rust to Swift](https://betterprogramming.pub/from-rust-to-swift-df9bde59b7cd)
- [Grep Crate](https://github.com/BurntSushi/ripgrep/tree/master/crates/grep)
- [Cocoa CPU Architectures](https://docs.elementscompiler.com/Platforms/Cocoa/CpuArchitectures/)
- [swift-create-xcframework GitHub action](https://github.com/marketplace/actions/swift-create-xcframework)
- [XCFrameworks](https://kean.blog/post/xcframeworks-caveats)
- [Recipe for Calling Swift Closures from Asynchronous Rust Code](https://www.nickwilcox.com/blog/recipe_swift_rust_callback/)
- [Building and Deploying a Rust library on iOS](https://mozilla.github.io/firefox-browser-architecture/experiments/2017-09-06-rust-on-ios.html)
- [The swift-bridge book](https://chinedufn.github.io/swift-bridge/)
