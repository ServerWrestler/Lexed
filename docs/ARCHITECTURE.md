# Architecture

Lexed is a small SwiftUI app with a clear one-way data flow. The goal is that the
**matching engine is pure and testable**, the **speech layer is isolated**, and
the **UI is a thin projection** of observable state.

```
 microphone
     │  AVAudioEngine tap (realtime thread)
     ▼
┌─────────────────────┐     partial/final results
│  SpeechRecognizer    │ ─────────────────────────────┐
│  (SFSpeechRecognizer)│                               │
└─────────────────────┘                               ▼
   @Published finalizedText / volatileText     ┌──────────────────┐
                                               │  LexedViewModel   │
        ┌──────────────────┐   keywords change │                  │
        │     Glossary      │ ─────────────────▶│  • KeywordIndex   │
        │  (JSON store)     │                   │  • highlighted    │
        └──────────────────┘                   │    AttributedString│
                                               │  • detected[]     │
                                               └──────────────────┘
                                                        │ @Published
                                                        ▼
                                          SwiftUI views (Transcript, Sidebar, …)
```

## Components

### `SpeechRecognizer` (`Sources/Lexed/SpeechRecognizer.swift`)
`@MainActor ObservableObject` wrapping Apple's `Speech` framework.

- Captures mic audio with a single long-lived `AVAudioEngine` tap. The tap runs on
  a realtime audio thread and only does one thing: append buffers to the *current*
  `SFSpeechAudioBufferRecognitionRequest`.
- **Continuous recognition.** `SFSpeechRecognizer` finalizes a request after a
  pause or ~1 minute. To transcribe indefinitely, the recognizer **rotates**: on a
  final result (or a recoverable error) it commits the text to `finalizedText`,
  tears down the request/task, and starts a fresh one — without stopping the audio
  engine. This is what makes "real time, all meeting long" work.
- Exposes two strings: `finalizedText` (committed) and `volatileText` (the live
  hypothesis, updated several times per second). `fullText` joins them.
- Recognition is **on-device only**: `requiresOnDeviceRecognition` is always
  `true` and the recognizer refuses to start without the offline model, so audio
  never leaves the Mac. (The app is also sandboxed without the network
  entitlement, making a cloud path impossible.)

### `Glossary` (`Sources/Lexed/Glossary.swift`)
`ObservableObject` owning `[Keyword]`, persisted to
`~/Library/Application Support/Lexed/keywords.json`. On first launch it seeds from
the bundled starter set. Handles add/update/remove and JSON import/export
(security-scoped for the sandbox).

### `KeywordIndex` (`Sources/Lexed/KeywordIndex.swift`)
The **matching engine** — pure, no UI or framework dependencies beyond Foundation,
fully unit-tested.

- Compiles every term + alias into **one** case-insensitive `NSRegularExpression`
  alternation (`\b(term a|term b|…)\b`). Matching is a single pass over the text,
  so cost is independent of glossary size.
- Word boundaries (`\b`) are added only where an edge character is alphanumeric, so
  symbol-bearing terms like `C++` and `.NET` still match.
- Forms are sorted longest-first and overlapping hits are dropped, so a multi-word
  term ("machine learning") wins over a contained shorter one ("learning").
- Returns `[KeywordMatch]` with UTF-16 `NSRange`s that map cleanly onto both the
  source `String` and the displayed `AttributedString`.

### `LexedViewModel` (`Sources/Lexed/LexedViewModel.swift`)
`@MainActor ObservableObject` that joins the two sources with Combine:

- Rebuilds the `KeywordIndex` **only when the glossary changes** (not per word).
- On every transcript update, runs the matcher and builds a `highlighted`
  `AttributedString`: each hit gets a soft accent background, bold weight, an
  underline, and a `lexed://term/<uuid>` link so it's clickable.
- Maintains `detected[]` — a session history of heard terms with first/last-heard
  timestamps and counts — and auto-focuses the newest term.

### Views (`Sources/Lexed/Views/`)
Thin and stateless beyond view-local `@State`:

- `ContentView` — toolbar (Listen / Clear / Keywords), `HSplitView` layout, and the
  `OpenURLAction` that turns `lexed://` link clicks into a focused definition.
- `TranscriptView` — auto-scrolling captions rendered from `highlighted`, with a
  font-size slider.
- `DefinitionsSidebar` — the big "current definition" card plus the session list.
- `GlossaryEditor` — CRUD + JSON import/export.
- `SettingsView` — language picker (recognition is on-device only; nothing to toggle).

## Why SwiftPM instead of an `.xcodeproj`?

Plain text files are friendlier for GitHub review and CI. The catch is that macOS
only shows TCC permission prompts (and applies entitlements) for a signed `.app`
bundle, so:

- `Info.plist` is **embedded into the binary** via a linker `-sectcreate` flag
  (see `Package.swift`) for direct `swift run` use, **and**
- `scripts/build-app.sh` assembles a real `Lexed.app`, copies the SwiftPM resource
  bundle into `Contents/Resources`, and ad-hoc code-signs it with
  `Lexed.entitlements`.

You can open the package directly in Xcode (`File ▸ Open ▸ Package.swift`) for a
full IDE experience if you prefer.

## Testing

`Tests/LexedTests` covers the matching engine and the `Keyword` model
(case-insensitivity, word boundaries, aliases, multi-word precedence, symbol
handling, range alignment, JSON decoding without an `id`). Run with `swift test`.

The speech and UI layers are intentionally kept thin so the tested core holds the
logic that's easy to get wrong.
