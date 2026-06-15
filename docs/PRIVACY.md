# Privacy

Lexed is designed for confidential conversations — job interviews, sales calls,
internal meetings. Privacy is a core feature, not an afterthought.

## What Lexed does

- Captures **microphone** audio only while you are actively listening (after you
  press **Listen**).
- Converts that audio to text using Apple's **on-device** `Speech` framework.
  Recognition is **on-device only** — there is no cloud mode.

## What Lexed does **not** do

- ❌ No network requests. Lexed makes **no** outbound connections — there is no
  analytics, no telemetry, no cloud backend. The app is sandboxed **without** the
  network entitlement.
- ❌ No audio recording. Microphone buffers are streamed to the recognizer and
  discarded; nothing is written to disk.
- ❌ No transcript persistence. The live transcript exists only in memory and is
  gone when you press **Clear** or quit.

## On-device only — no cloud fallback

Lexed transcribes **entirely on your Mac**. There is no server-recognition mode to
turn on, and there couldn't be: the app is sandboxed **without** the network
entitlement (`com.apple.security.network.client`), so the recognizer is
technically unable to send audio anywhere even if it tried.

Recognition sets `requiresOnDeviceRecognition = true`, and Lexed will **refuse to
start** if the language's offline model isn't installed (rather than degrade to a
network path). Install the model via **System Settings ▸ Keyboard ▸ Dictation ▸
add language**.

## Permissions Lexed requests

- **Microphone** (`NSMicrophoneUsageDescription`) — to hear the conversation.
- **Speech Recognition** (`NSSpeechRecognitionUsageDescription`) — to transcribe
  it.

Both are standard macOS TCC prompts shown the first time you listen, and can be
revoked anytime in **System Settings ▸ Privacy & Security**.

## The only data Lexed stores

- Your **glossary** at `~/Library/Application Support/Lexed/keywords.json` — the
  terms and definitions you chose to save. That's it.

## A note on consent

Transcribing someone's speech can be subject to laws about recording or processing
conversations, which vary by jurisdiction. Lexed does not record audio, but you are
responsible for using it lawfully and ethically — when in doubt, get consent.
