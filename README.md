# SpeakEase

Dictation for macOS that stays on your Mac. Press a hotkey, say what you mean,
and the text appears in whatever you were typing in.

**Developer:** Nav Virdi — [Liberated.Studio](https://liberated.studio) — [nav@Liberated.Studio](mailto:nav@Liberated.Studio)

---

## Nothing leaves your machine

SpeakEase has **no networking code at all.** There is no `URLSession` anywhere in
the source — you can check that in about thirty seconds, and you should, because
this is an app that hears everything you say to it.

Transcription uses Apple's **Speech** framework. Optional text enhancement uses
Apple's **Foundation Models** framework. Both run entirely on your Mac. Your
audio is never uploaded, your transcripts are never uploaded, and there is no
account, no API key and no service to sign up for.

## How it works

1. Press the hotkey — **⌥ Space** by default.
2. Speak. A small HUD shows a live waveform so you know it's listening.
3. Press again (or release, in push-to-talk mode).
4. The text is inserted into the app you were already in.

**Two recording modes:**

- **Toggle** — press once to start, press again to stop.
- **Push to talk** — record while you hold the key, stop when you let go.

The HUD can be turned off, or moved to any of the four screen corners.

## Enhancement and prompts

Raw dictation is literal — it keeps your false starts and gives you no
punctuation you didn't say. Turn on **enhancement** and the transcript is passed
through Apple's on-device language model first, guided by a **prompt** you choose.

Prompts are just instructions in plain English — clean this up, make it a commit
message, make it a polite email — and you can add your own. SpeakEase ships with
a set of defaults to start from. Enhancement is **off** by default.

## Vocabulary rules

Speech recognisers reliably mangle names, jargon and product names. A
**vocabulary rule** is a find-and-replace applied to every transcript before it
reaches you:

| Option | What it does |
|---|---|
| **Whole word** | matches only complete words, so "cat" won't rewrite "category" |
| **Case sensitive** | off by default, so one rule catches every capitalisation |

Rules run in order, before enhancement and before the text is inserted.

## History

Completed transcriptions are saved so you can retrieve something you dictated
earlier. The menu bar keeps a Recent History submenu — 10, 20, 50 or 100 items,
your choice.

History can be turned off entirely, and when it's on you can set it to expire
after **7, 30 or 90 days**, or never.

## What happens to your clipboard

Inserting text requires the clipboard, which means SpeakEase briefly writes over
whatever you had copied. It does three things about that:

- It tags the pasteboard item as **transient** (`org.nspasteboard.TransientType`),
  which tells clipboard managers like Maccy and Raycast not to archive your
  dictation in their history.
- **Restore clipboard** puts your previous clipboard contents back afterwards.
- **Auto-clear** wipes the clipboard after 30 seconds, 60 seconds or 2 minutes,
  so a dictated password doesn't sit there indefinitely.

There's also **auto-enter**, which presses Return after inserting — useful for
chat windows, dangerous everywhere else, and off by default.

## Permissions

SpeakEase needs two, and asks for both on first run:

- **Microphone** — to hear you.
- **Accessibility** — to register the global hotkey and to type into other
  applications. macOS has no other way to grant this.

It is deliberately **not sandboxed**. A sandboxed app cannot insert text into
another application or register a system-wide hotkey, which is the entire
premise of this one.

## Requirements

- **macOS 26 or later.** A hard requirement — the enhancement feature uses
  Apple's Foundation Models framework, which does not exist on earlier versions.
  The app will not launch on anything older.
- **Apple Silicon.** SpeakEase is built for `arm64` only. Apple Intelligence and
  the Foundation Models framework do not run on Intel Macs at all, so an Intel
  build would ship with its enhancement feature permanently unavailable. Rather
  than distribute a half-working app, the project targets Apple Silicon alone.

## Building

Two ways, both work:

**Xcode** — open `SpeakEase.xcodeproj`, set your own signing team under Signing &
Capabilities (the project ships with an empty `DEVELOPMENT_TEAM`), then build and
run.

**Swift Package Manager** — `swift build`. The package targets macOS 26 and Swift
language mode 6.

The Xcode project pins `ARCHS = arm64` at the project level. That is deliberate,
for the reason given under Requirements — please don't widen it without also
deciding what should happen to enhancement on a machine that can't run it.

### Developer scripts

| Script | What it does |
|---|---|
| `dev-scripts/local_build.sh [Config]` | `xcodebuild` into `./build`, Release by default |
| `dev-scripts/local_run.sh [Config]` | build, then launch the result |
| `dev-scripts/clear_settings.sh [key]` | delete one preference, or all of them |
| `dev-scripts/reset_all_approvals.sh` | `tccutil reset` the microphone, Accessibility and Apple Events approvals, to test the first-run permission flow again. Needs `sudo`. |

### Tests

`swift test`, or the test target in Xcode.

## Where your data lives

- **Transcription history** — `~/Library/Application Support/SpeakEase/history.json`
- **Settings, prompts and vocabulary rules** — `UserDefaults`, under the key
  `settings.v1`

Both are plain, readable formats on your own disk. Delete them and SpeakEase
starts fresh.

## License

SpeakEase is released under the MIT License. See [LICENSE](LICENSE).

---

© 2026 Nav Virdi — Liberated.Studio
