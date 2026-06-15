<div align="center">

# Lexed

**Real-time captions that highlight and define the jargon you don't know — live, on-device, private.**

[lexed.app](https://lexed.app) · macOS 13+ · Swift / SwiftUI

</div>

---

Lexed listens to the person across the table (or on the call), turns their speech
into **live on-screen captions**, and the instant they say a term from your
glossary — a technical acronym, a piece of company jargon, a buzzword — it
**highlights the word and shows you its definition**. No more nodding along to
"we need this to be idempotent behind the SLA" and quietly panicking.

Built for **job interviews, sales calls, standups, and meetings** where you want
to follow every word without breaking eye contact to Google an acronym.

> **Privacy first.** Lexed uses Apple's on-device `Speech` framework. With
> on-device mode on (the default), **the audio never leaves your Mac** — nothing
> is recorded, uploaded, or sent to any server. See [docs/PRIVACY.md](docs/PRIVACY.md).

---

## Features

- 🎙️ **Live transcription** of the microphone using Apple's `Speech` framework, with continuous (unlimited-length) recognition.
- ✨ **Inline keyword highlighting** — glossary terms light up the moment they're spoken.
- 📖 **Instant definitions** — a "current definition" card plus a running list of every term heard this session, with counts and timestamps.
- 🔒 **On-device by default** — no network, no recording, sandboxed.
- 📝 **Editable glossary** — add/edit terms, aliases ("k8s" → Kubernetes), categories, and source links; import/export as JSON.
- 🖱️ **Click any highlighted word** in the transcript to pull up its definition.
- 🔤 **Adjustable caption size**, auto-scroll, and selectable text.
- 🌍 **Multi-language** recognition (any locale with an installed on-device model).

---

## Quick start

> Requires macOS 13 (Ventura) or later and the Xcode command-line tools / Swift toolchain.

```bash
git clone https://github.com/<your-org>/Lexed.git
cd Lexed

# Build a proper .app bundle (needed for the mic/speech permission prompts)
./scripts/build-app.sh --open
```

The first time you press **Listen**, macOS asks for **Microphone** and **Speech
Recognition** permission. Grant both.

> **On-device model:** for fully-private recognition, make sure your language's
> dictation model is installed: **System Settings ▸ Keyboard ▸ Dictation**, add
> your language (this downloads the offline model). If it isn't installed, either
> install it or turn off "On-device only" in Lexed's Settings.

### Run during development

```bash
swift build          # compile
swift test           # run the matching-engine unit tests
swift run Lexed      # run without bundling (permission prompts may not appear)
```

For permission prompts to behave correctly, prefer the bundled app
(`./scripts/build-app.sh`).

---

## How to use it

1. **Set up your glossary.** Click **Keywords** in the toolbar. Lexed ships with
   ~30 common tech/business terms (API, SLA, CI/CD, OKR, Kubernetes, …). Add the
   acronyms and jargon specific to the company you're interviewing with.
2. **Position the window** where you can glance at it during the conversation.
3. **Press Listen** (⌘L). Captions stream in real time.
4. When the speaker says a glossary term, it **highlights** in the transcript and
   its **definition appears** on the right. Click any highlighted word to re-focus
   its definition.
5. **Clear** (⇧⌘K) between conversations.

### Tips for interviews & meetings

- Before a specific interview, **export** your glossary, tweak it for that
  company's stack, and **import** it back — or keep multiple JSON files.
- Lexed transcribes whatever the **microphone** hears. For in-person meetings the
  built-in mic is fine. For video calls, see *Capturing call audio* below.

---

## Capturing call audio (Zoom / Meet / Teams)

Lexed listens to the system **microphone**. To caption the *other* person on a
video call, route that call's audio into an input device Lexed can hear:

- Install a virtual audio device (e.g. **BlackHole**, free/open-source), create a
  **Multi-Output Device** in *Audio MIDI Setup* so you still hear the call, and
  select the virtual device as the input in Lexed's Settings, **or**
- Use an aggregate/loopback setup of your choice.

This keeps Lexed itself simple and within the microphone-only sandbox. A built-in
system-audio capture mode (via `ScreenCaptureKit`) is on the [roadmap](#roadmap).

---

## Glossary format

The glossary is a plain JSON array. Each entry:

```json
{
  "term": "SLA",
  "definition": "Service Level Agreement — a commitment about how reliable or fast a service will be.",
  "aliases": ["service level agreement"],
  "category": "Operations",
  "source": "https://en.wikipedia.org/wiki/Service-level_agreement"
}
```

| Field        | Required | Notes                                                            |
|--------------|----------|------------------------------------------------------------------|
| `term`       | ✅       | Canonical term shown in the UI.                                  |
| `definition` | ✅       | Plain-language explanation.                                      |
| `aliases`    | —        | Other spoken/written forms that should also match.              |
| `category`   | —        | Optional grouping label shown as a chip.                        |
| `source`     | —        | Optional "Learn more" URL.                                       |
| `id`         | —        | Optional UUID; auto-generated if omitted.                        |

Your editable copy lives at
`~/Library/Application Support/Lexed/keywords.json`. The bundled starter set is
[`Sources/Lexed/Resources/keywords.json`](Sources/Lexed/Resources/keywords.json).

---

## Project layout

```
Lexed/
├── Package.swift                 # SwiftPM manifest (executable + test target)
├── Sources/Lexed/
│   ├── LexedApp.swift            # @main App, scenes, menu commands
│   ├── Models.swift              # Keyword, DetectedTerm
│   ├── Glossary.swift            # load/save/import/export keyword store
│   ├── KeywordIndex.swift        # compiled regex matcher (the matching engine)
│   ├── SpeechRecognizer.swift    # AVAudioEngine + SFSpeechRecognizer, live + rotating
│   ├── LexedViewModel.swift      # ties speech + glossary → highlighted transcript
│   ├── Views/                    # SwiftUI: transcript, sidebar, glossary editor, settings
│   ├── Resources/keywords.json   # starter glossary
│   ├── Info.plist                # TCC usage strings, bundle metadata
│   └── Lexed.entitlements        # sandbox + audio-input
├── Tests/LexedTests/             # unit tests for the matching engine
├── scripts/build-app.sh          # assemble + sign the .app bundle
└── docs/                         # ARCHITECTURE, PRIVACY
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.

---

## Roadmap

- [ ] System-audio capture via `ScreenCaptureKit` (caption the far side of a call without a virtual device).
- [ ] Floating always-on-top caption overlay / picture-in-picture mode.
- [ ] Per-context glossary profiles (switch between "interview", "standup", …).
- [ ] Transcript export (Markdown / `.txt`) with detected terms appended.
- [ ] Adopt `SpeechAnalyzer` / `SpeechTranscriber` on macOS 26+ for lower-latency streaming.
- [ ] Optional definition lookups for unknown words via a local dictionary.
- [ ] Signed & notarized release builds + Homebrew cask.

---

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Run `swift test` before
submitting; the matching engine is covered by unit tests and should stay green.

## License

[MIT](LICENSE) © Lexed contributors.

Built with Apple's on-device Speech framework. Not affiliated with Apple Inc.
