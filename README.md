# VoiceInk Offline

A local-only edition of VoiceInk for macOS. The app uses Apple frameworks and the Swift standard library; there are no Swift packages, vendored libraries, downloaded frameworks, or model downloads in the build.

## Changes in this fork

- **Offline transcription:** uses Apple Speech with language assets installed on the Mac. Removed third-party packages, bundled model runtimes, third-party model downloads, cloud providers, licensing requests, updates, and remote announcements.
- **Language downloads on request (2.26.1):** a missing Apple Speech language, such as German, can be downloaded from the Speech Model screen. macOS fetches it from Apple in its own system services; the app process stays network-denied.
- **Network restriction:** the app installs a process sandbox that denies incoming and outgoing networking, including loopback, and refuses to start if that restriction fails. This applies to VoiceInk and its children, not the rest of macOS or applications receiving pasted text.
- **Prompt Snippets:** optional, editable voice commands such as “insert prompt code review” paste a saved prompt. Includes three starters, a command preview, local storage, and settings backup support.
- **Launch at Login:** opt-in startup in Settings, with approval guidance and visible registration errors. Launching the app does not start recording.
- **Local developer commands:** a sectioned, colored `make` help screen, readiness checks with `make doctor`, build/run commands, installation to Applications, `kill-installed`, and an app-scoped permission reset.
- **Verification and publication checks:** tests for offline enforcement, local speech, prompt snippets, and developer commands; `make privacy-check` checks publishable files for common secrets, private paths, and generated artifacts.

AI enhancement and assistant responses are unavailable in this edition. System frameworks and an installed Apple Speech language are still required. Original upstream attribution and Git history are preserved.

## Build and run

Requires Xcode 26 or newer. Transcription requires macOS 26 and an Apple Speech language installed on the Mac; a missing one can be downloaded from the app.

```sh
make          # Show grouped, colored help
make doctor   # Check local readiness without downloading anything
make run      # Build and launch
make install  # Build and copy to /Applications
```

The app is built at `.local-build/Build/Products/Release/VoiceInk.app`, with ad-hoc signing and the separate bundle identifier `local.VoiceInk.Offline`. Its transcript/dictionary database uses `~/Library/Application Support/local.VoiceInk.Offline`. The build does not resolve packages or fetch source. `make clean` removes only this repository's build output.

Use `make open-installed` to open the Applications copy. Enable auto start on demand in **Settings → General → Launch at Login**. `make reset-permissions` resets only VoiceInk’s macOS privacy permissions; settings and history are retained.

Use `make kill-installed` to stop the Applications copy (an active recording may be lost). To upgrade and reopen: `make kill-installed && make install && make open-installed`. These commands also accept `INSTALL_DIR` for a custom installation folder.

Allow microphone access to record. Accessibility access enables global shortcuts and pasting into other apps. On first launch, choose a language and open VoiceInk; a local dictation mode is created automatically. Use the Speech Model screen to check whether a language is installed, and choose **Download** to install a missing one (this step needs an internet connection). Dictating in a language that is not installed produces an error; the app never downloads a language on its own and never falls back to a server.

## Offline behavior

- A C initializer applies a macOS process sandbox denying all network operations before Swift app initialization. Incoming and outgoing connections, including loopback, are blocked. The restriction is inherited by children. If it cannot be installed, the app exits with status 78.
- Cloud transcription, Whisper/FluidAudio/TranscribeCpp runtimes, downloaded LLMs, Ollama, CLI enhancement, custom command execution, automatic updates, remote announcements, license requests, and iCloud sync are removed.
- Links cannot hand networking off to a browser or email client. Only System Settings links are opened.
- Recording, Apple Speech transcription, local audio import, history, dictionary, modes, shortcuts, and local text processing remain. AI enhancement and assistant responses are unavailable. Markdown uses plain text; automatic media pause is unavailable after removal of MediaRemoteAdapter.
- Legacy provider names and some unavailable service interfaces remain only to keep saved settings/history compatible; no external implementation or dependency is included.

The process restriction does not turn off networking for macOS or unrelated applications. Apple Speech uses installed OS assets through local system services. When you choose **Download** for a language, the app asks macOS to install it; macOS downloads the assets from Apple in its own services, while the app process itself remains network-denied. Nothing is downloaded without that explicit request, and audio is never sent anywhere.

## Verification

```sh
make test
```

This tests the developer commands, audits the project and source, tests kernel denial of TCP/IPv6 networking using the production guard, tests abort-on-guard-failure, and checks the signed app's linked libraries when built. See [BUILDING.md](BUILDING.md) for the local speech smoke test and for `make test-language`, which checks that macOS can download a language while the process stays network-denied.

Original VoiceInk attribution and license are preserved in [LICENSE](LICENSE).

## Prompt Snippets

In **Settings → Prompt Snippets**, enable reusable voice prompts. Press your usual recording shortcut, say **“insert prompt code review”**, then stop recording. VoiceInk pastes a ready-to-use review prompt into the focused field. Dictate or paste the code next.

Three editable starters are included: **code review**, **make a plan**, and **clear writing**. Add your own names and prompt text, and use **Try a command** to preview the result without recording or touching your clipboard. Edits save automatically on this Mac and are included in General Settings backups.

Only a complete `insert prompt <name>` command expands, ignoring punctuation and capitalization. Unknown, duplicate, or empty snippets leave your dictated text unchanged. This is an opt-in, local text expansion feature for recording-to-paste; it makes no AI or network calls and follows your existing paste and Auto Send settings. The expanded prompt is saved in transcription history.
