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

> **Privacy first.** Lexed uses Apple's **on-device** `Speech` framework and is
> sandboxed with no network access, so **the audio never leaves your Mac** —
> nothing is recorded, uploaded, or sent to any server. See [docs/PRIVACY.md](docs/PRIVACY.md).

---

## Features

- 🎧 **Captures system audio from any app** — Zoom, Google Meet, Teams, Slack huddles — via `ScreenCaptureKit`. No virtual audio device needed. (Or switch to the **microphone** for in-person meetings.)
- 🎙️ **Live transcription** using Apple's `Speech` framework, with continuous (unlimited-length) recognition.
- ✨ **Inline keyword highlighting** — glossary terms light up the moment they're spoken.
- 📖 **Instant definitions** — a "current definition" card plus a running list of every term heard this session, with counts and timestamps.
- 🔒 **On-device only** — no network entitlement, no recording, sandboxed; audio never leaves the Mac.
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

The first time you press **Listen**, macOS asks for permission:

- **Speech Recognition** — always (Lexed transcribes).
- **Screen Recording** — when the audio source is **System audio** (ScreenCaptureKit
  captures app/call audio through this permission). macOS may require you to
  **relaunch Lexed** after granting it the first time.
- **Microphone** — when the audio source is **Microphone**.

> **On-device model required.** Lexed is **on-device only** — it will not start
> until your language's offline dictation model is installed. Add it in
> **System Settings ▸ Keyboard ▸ Dictation** (this downloads the offline model),
> then pick that language in Lexed's Settings. This is what guarantees the audio
> never leaves your Mac.

### Run during development

```bash
swift build          # compile
swift test           # run the matching-engine unit tests
swift run Lexed      # run without bundling (permission prompts may not appear)
```

For permission prompts to behave correctly, prefer the bundled app
(`./scripts/build-app.sh`).

---

## Verifying it works

The matching engine is covered by `swift test`, but the live audio path can only
be confirmed by running the app. Use this manual acceptance checklist:

**Build & launch**
- [ ] `swift test` → all tests pass.
- [ ] `./scripts/build-app.sh --open` builds and launches `Lexed.app`.

**System-audio mode (Zoom / Slack / Meet / Teams)**
- [ ] Settings ▸ Audio source = **System audio**.
- [ ] Press **Listen**. If prompted, grant **Speech Recognition** and **Screen
      Recording** (relaunch Lexed if macOS asks), then press Listen again.
- [ ] Play a talking video (e.g. a YouTube clip) or join a real call. Spoken words
      appear as captions within a second or two.
- [ ] Status pill reads "Listening to system audio (on-device)…".

**Microphone mode (in person)**
- [ ] Settings ▸ Audio source = **Microphone**. Press Listen; grant **Microphone**.
- [ ] Speak — your words appear as captions in real time.

**Keyword highlight & define**
- [ ] Say or play a sentence containing a glossary term, e.g. *"we need an **API**
      with a 99.9% **SLA**."*
- [ ] "API" and "SLA" highlight in the transcript.
- [ ] Their definitions appear in the right sidebar; the newest is the big card.
- [ ] Click a highlighted word → its definition becomes the focused card.

**Glossary editing**
- [ ] Keywords ▸ **Add** a new term; it persists after quitting and relaunching
      (`~/Library/Application Support/Lexed/keywords.json`).
- [ ] Export to JSON, then Import it into a fresh glossary.

**Privacy (the on-device claim)**
- [ ] Turn off Wi-Fi/Ethernet entirely, then transcribe — it still works,
      proving recognition is on-device. (If it refuses to start, install the
      on-device model via System Settings ▸ Keyboard ▸ Dictation.)

> Maintainers: please run this checklist before tagging a release, since CI can
> only verify the build and unit tests, not microphone/screen-capture behavior.

---

## How to use it

1. **Pick your audio source.** Open **Settings** (⌘,):
   - **System audio (apps & calls)** — captures the audio your Mac plays, so it
     hears the *other* person on a Zoom/Meet/Teams call or Slack huddle. Needs
     Screen Recording permission.
   - **Microphone (in person)** — captures the mic, for face-to-face meetings.
2. **Set up your glossary.** Click **Keywords** in the toolbar. Lexed ships with
   28 common tech/business terms (API, SLA, CI/CD, OKR, Kubernetes, …). Add the
   acronyms and jargon specific to the company you're interviewing with.
3. **Position the window** where you can glance at it during the conversation.
4. **Press Listen** (⌘L). Captions stream in real time.
5. When the speaker says a glossary term, it **highlights** in the transcript and
   its **definition appears** on the right. Click any highlighted word to re-focus
   its definition.
6. **Clear** (⇧⌘K) between conversations.

### Tips for interviews & meetings

- Before a specific interview, **export** your glossary, tweak it for that
  company's stack, and **import** it back — or keep multiple JSON files.
- For remote interviews, use **System audio** so you caption the interviewer
  through Zoom/Meet. For in-person, use **Microphone**.

---

## Capturing call audio (Zoom / Meet / Teams / Slack)

This is built in — no virtual audio device required. In **Settings**, choose
**System audio (apps & calls)**. Lexed uses `ScreenCaptureKit` to read the audio
your Mac is playing (excluding Lexed's own output) and transcribes it on-device.

- Requires **Screen Recording** permission (System Settings ▸ Privacy & Security ▸
  Screen Recording). macOS may ask you to relaunch Lexed after you grant it.
- It captures *everything* you hear — the call, plus any music or notifications.
  Mute other audio for the cleanest transcript.

> Per-app audio selection (capture only Zoom, say) is on the [roadmap](#roadmap).

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
│   ├── AudioCapture.swift        # system-audio (ScreenCaptureKit) + microphone backends
│   ├── SpeechRecognizer.swift    # SFSpeechRecognizer, on-device, live + rotating
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

- [x] System-audio capture via `ScreenCaptureKit` (caption the far side of a call without a virtual device).
- [ ] Per-app audio selection (capture a single app, e.g. only Zoom).
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
