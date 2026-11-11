# Building the offline edition

Install Xcode 26 or newer and select it with `xcode-select`. No package manager, third-party source, downloaded framework, API key, developer membership, or model download is needed.

Run commands from the repository root. Plain `make` prints help and does not build anything.

| Command | Action |
| --- | --- |
| `make` / `make help` | Grouped command list with terminal colors |
| `make doctor` | Full local readiness report with PASS / WARN / FAIL results |
| `make check` / `make healthcheck` | Fast OS, Xcode, SDK, compiler, and tool checks |
| `make build` / `make local` / `make all` | Build the Release app with ad-hoc signing |
| `make run` / `make dev` | Build and open the app |
| `make install` | Build and install `/Applications/VoiceInk.app` |
| `make open-installed` | Open the installed copy |
| `make kill-installed` | Stop only the installed copy; force-kill after 5 seconds |
| `make reset-permissions` | Reset macOS privacy decisions for `local.VoiceInk.Offline` only |
| `make privacy-check` | Scan tracked and non-ignored files for common publication risks |
| `make open` | Open the existing build without rebuilding |
| `make status` | Show the build, running PIDs, and open IP sockets |
| `make logs` | Show the last five minutes of local VoiceInk logs |
| `make test` | Developer-command tests plus dependency, offline, and binary audits |
| `make test-tools` | Test help, colors, diagnostics, process matching, and safe cleanup |
| `make test-speech` | Transcribe a generated local speech fixture; no microphone capture |
| `make test-language LANGUAGE=de-DE` | Have macOS download one language while the probe process stays network-denied |
| `make clean` | Remove only `.local-build`; refuse if that app is running or the path is a symlink |
| `make rebuild` | Clean, then build, sequentially even with parallel make |

Colors are automatic in terminals and disabled when redirected. Use `make COLOR=always`, `make COLOR=never`, or `NO_COLOR=1 make`. `PYTHON=/path/to/python3` selects the Python interpreter for diagnostics; help itself needs only awk.

`doctor` checks macOS/Xcode versions, Xcode first-launch readiness, SDK/compiler/tools, write access and free space, required project files, dependency removal, kernel network denial and fail-closed startup, app architecture/signature/entitlements/freshness, running app sockets, installed speech languages, the selected language, default microphone availability, saved primary shortcut, and onboarding. It never downloads anything, starts recording, accepts a license, requests privacy access, or changes settings. Native probes are compiled in temporary directories and run with the production network guard.

Failures return exit status 1; warnings return 0. A missing build or closed app is a warning. App-specific Microphone/Accessibility permissions, shortcut conflicts with other apps, selected-device overrides, and actual pasting into a focused field require an interactive check; `doctor` explicitly reports these limits. It does not claim to verify every possible OS or application condition. `make test-speech` separately exercises transcription with already installed en-US assets and the Samantha voice.

If `make run` finds an existing instance, it opens that instance. After rebuilding, quit VoiceInk and use `make open` to load the new executable; the command does not interrupt a recording automatically.

Open `VoiceInk.xcodeproj` to build from Xcode. Both configurations include the same offline guard and have no package dependencies. The application remains offline when opened directly from Finder. Signing entitlements grant microphone and Apple Events access, not networking or iCloud. The process sandbox is installed unconditionally by `OfflineNetworkGuard.c`.

The underlying `sandbox_init` API is deprecated by Apple, but is available on the tested macOS 26 host. Failure to apply it prevents launch; there is no online fallback. Re-run `make test` after macOS or Xcode upgrades.

## Before publishing

Run `make privacy-check` to scan tracked and non-ignored files. After staging, run `python3 scripts/check-public-repo.py --staged` to check the exact index contents. The check reports file names, line numbers, and finding categories without printing secret values. It checks common credential formats, private absolute paths, unexpected emails, signing teams, and private/generated artifacts; it is not a comprehensive PII detector.

Build products, recordings, transcripts, local databases, environment files, signing keys, logs, and Xcode user settings are ignored. Ignoring a file does not remove it from existing commits. Review newly added media and Git history separately, and use a GitHub no-reply commit address if you do not want to publish your email. Upstream attribution and public contributor history are retained.

## Installing and managing startup

Run `make install` to build, verify, and copy the app into `/Applications/VoiceInk.app`. The copy is staged and signature-checked before replacement; failed installation restores the previous offline app. The command refuses to overwrite a different VoiceInk edition, follow an app symlink, or replace the installed app while it is running. Quit that copy before upgrading. It preserves app settings and history and does not enable startup automatically.

The build is ad-hoc signed, so macOS ties its privacy grants to that exact build. After installing a new build, Accessibility is off for it and the global shortcut does not respond until you grant it again: in **System Settings → Privacy & Security → Accessibility**, remove VoiceInk and add `/Applications/VoiceInk.app` again (or run `make reset-permissions` and approve the prompts), then quit and reopen the app. macOS may also ask for Microphone access again.

For a per-user installation, use `make install INSTALL_DIR="$HOME/Applications"`. Pass the same `INSTALL_DIR` to `make open-installed` and `make kill-installed` when using a custom destination. No automatic sudo or privilege escalation is used.

`make kill-installed` sends SIGTERM to the exact installed executable, waits up to five seconds, then sends SIGKILL to any surviving original instances. It succeeds when the app is already stopped, refuses other app bundles and app symlinks, and leaves development copies alone. An active recording may be lost; saved settings and history are retained. To update and reopen, run `make kill-installed && make install && make open-installed` (sequentially, not with `make -j`).

Open the installed copy and use **Settings → General → Launch at Login** to opt in or opt out. If macOS requires approval, the app shows **Open Login Items**. Failures are displayed in Settings, and returning from System Settings refreshes the toggle. Enabling startup opens VoiceInk at login; it does not start recording.

`make reset-permissions` runs `tccutil reset All local.VoiceInk.Offline` for the current user. Quit and reopen VoiceInk afterward, then allow Microphone and Accessibility again as needed. Check Input Monitoring if shortcuts do not respond. This resets privacy grants and denials only; it does not delete transcripts/settings, disable Launch at Login, or reset permissions for unrelated apps. The automated tests mock this action; they never reset real permissions.

## Language downloads

Apple Speech languages that macOS has not installed yet (German, for example) can be downloaded from **Speech Model**, onboarding, or a mode's language row with the **Download** button. The app only asks macOS to install the language through `AssetInventory`; macOS downloads the assets from Apple in its own system services. The app process keeps its network denial the whole time; only that one step needs an internet connection. A download keeps running if you leave the screen, and the status picks it up again when you return.

Nothing is downloaded automatically: dictating in a missing language reports "Download required" instead, and `make test-speech` checks that it leaves the installed languages unchanged. The audit in `make test` keeps the install path narrow: Apple's install API may appear only in `NativeAppleSpeechAssetManager.swift`, that manager's install functions only in `NativeAppleSpeechAssetInstallCoordinator.swift`, and the coordinator only in the language control that owns the Download button.

macOS limits how many languages one app can keep reserved (five on the tested macOS 26 host). When that limit is reached, installing another language releases one of the earlier reservations, and macOS may later remove that language's assets. Download it again if you need it back.

To check the mechanism itself, run `make test-language LANGUAGE=de-DE` with a language that is not installed yet. It links the production asset manager with the production network guard, confirms the probe cannot open even a loopback connection, asks macOS for the language, and passes only if the language ends up installed. This is the one command here that downloads something, so it is not part of `make test`; for an already installed language it reports that nothing was downloaded. Re-run it after macOS upgrades.

## Native speech smoke test

This uses the production Apple Speech source and an already installed en-US language. It synthesizes a short local fixture using the installed Samantha voice, then checks transcription and that an unsupported language is rejected. If some supported language is not installed, it also checks that the language is reported as downloadable and that dictating in it fails with "Download required" without installing anything. The test itself never requests a model or voice download.

```sh
make test-speech
```

Microphone recording and global paste still require the user's macOS privacy permissions. The smoke test does not access the microphone or other apps.
