# Contributing to Lexed

Thanks for your interest! Lexed aims to stay small, private, and dependency-free.

## Getting set up

```bash
git clone https://github.com/<your-org>/Lexed.git
cd Lexed
swift build        # compile
swift test         # run the unit tests
./scripts/build-app.sh --open   # build & launch the .app
```

Requirements: macOS 13+, the Swift toolchain (Xcode or Command Line Tools). You can
also open `Package.swift` directly in Xcode.

## Ground rules

- **No third-party dependencies.** Lexed uses only Apple frameworks. Please keep it
  that way unless there's a compelling reason discussed in an issue first.
- **No networking.** The app must remain offline/sandboxed. Don't add the network
  entitlement or any outbound calls. Privacy is the product.
- **Keep the matching engine pure.** `KeywordIndex` and `Models` must not import UI
  or speech frameworks, and changes to them need test coverage.

## Before you open a PR

1. `swift test` passes (add tests for new matching/model behavior).
2. `swift build` is warning-clean.
3. New user-facing strings read naturally and match the existing tone.
4. Describe the change and how you verified it (especially anything touching the
   live speech path, which is hard to unit-test).

## Good first issues

- Transcript export (Markdown/txt).
- Floating always-on-top caption overlay.
- Glossary profiles (switch keyword sets per context).
- `ScreenCaptureKit` system-audio capture mode.

See the [roadmap](README.md#roadmap) for the bigger picture.

## Code style

Idiomatic Swift / SwiftUI. Match the surrounding code: explanatory comments where
intent isn't obvious (especially the speech-rotation logic), `// MARK:` sections in
larger files, and `final` classes for reference types.
