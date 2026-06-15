# Privacy

Lexed is designed for confidential conversations — job interviews, sales calls,
internal meetings. Privacy is a core feature, not an afterthought.

## What Lexed does

- Captures **microphone** audio only while you are actively listening (after you
  press **Listen**).
- Converts that audio to text using Apple's **on-device** `Speech` framework when
  "On-device only" is enabled (the **default**).

## What Lexed does **not** do

- ❌ No network requests. Lexed makes **no** outbound connections — there is no
  analytics, no telemetry, no cloud backend. The app is sandboxed **without** the
  network entitlement.
- ❌ No audio recording. Microphone buffers are streamed to the recognizer and
  discarded; nothing is written to disk.
- ❌ No transcript persistence. The live transcript exists only in memory and is
  gone when you press **Clear** or quit.

## On-device vs. server recognition

| Mode | What happens to audio | When to use |
|------|-----------------------|-------------|
| **On-device only** (default) | Audio is transcribed entirely on your Mac and never leaves it. Requires the language's offline dictation model. | Always recommended; required for confidential meetings. |
| On-device off | Apple's `Speech` framework **may** send audio to Apple's servers for recognition, subject to Apple's privacy policy. | Only if an on-device model isn't available for your language and you accept the trade-off. |

Lexed defaults to on-device and will refuse to start in on-device mode if the
model isn't installed (rather than silently falling back to the network). Install
the model via **System Settings ▸ Keyboard ▸ Dictation ▸ add language**.

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
