#!/usr/bin/env python3
"""Standard-library-only local development commands. Never fetches dependencies."""
import argparse
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / '.local-build'
APP = BUILD / 'Build/Products/Release/VoiceInk.app'
BINARY = APP / 'Contents/MacOS/VoiceInk'
BUNDLE_ID = 'local.VoiceInk.Offline'
INSTALLED_APP = Path('/Applications/VoiceInk.app')
GUARD = ROOT / 'VoiceInk/Infrastructure/Privacy/OfflineNetworkGuard.c'
APPLE_SPEECH = ROOT / 'VoiceInk/Infrastructure/Providers/Transcription/AppleSpeech'
ASSET_MANAGER = APPLE_SPEECH / 'NativeAppleSpeechAssetManager.swift'
# BCP-47 language-region such as de-DE or yue-CN; nothing else may reach the probe's arguments.
LANGUAGE_PATTERN = re.compile(r'[a-z]{2,3}-[A-Z]{2}')
LANGUAGE_DOWNLOAD_TIMEOUT = 1800  # seconds; a language is a few hundred megabytes on a slow link
COLOR = not os.environ.get('NO_COLOR') and (
    os.environ.get('COLOR') == 'always' or
    os.environ.get('COLOR') != 'never' and sys.stdout.isatty() and os.environ.get('TERM') != 'dumb')


def paint(text, code):
    return f'\033[{code}m{text}\033[0m' if COLOR else text


def section(title):
    print('\n' + paint(title, '1;35'))


class Report:
    def __init__(self):
        self.passed = self.warnings = self.failed = 0

    def item(self, level, label, detail):
        attribute = {'PASS': 'passed', 'WARN': 'warnings', 'FAIL': 'failed'}[level]
        setattr(self, attribute, getattr(self, attribute) + 1)
        print(f"  {paint(level, {'PASS': '32', 'WARN': '33', 'FAIL': '31'}[level])}  {label}: {detail}")

    def summary(self):
        print(f'\n{self.passed} passed · {self.warnings} warnings · {self.failed} failures')
        return 1 if self.failed else 0


def command(*args, timeout=30):
    return subprocess.run([str(a) for a in args], cwd=ROOT, text=True,
                          capture_output=True, timeout=timeout)


def require(*args, timeout=30):
    result = command(*args, timeout=timeout)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip()[-5000:] or f'{args[0]} failed')
    return result.stdout.strip()


def version(text):
    match = re.search(r'(\d+)\.(\d+)', text)
    return tuple(map(int, match.groups())) if match else (0, 0)


def prerequisites(report):
    section('System & toolchain')
    if platform.system() != 'Darwin':
        report.item('FAIL', 'Operating system', 'VoiceInk requires macOS; use a Mac with Xcode 26+.')
        return False
    macos = platform.mac_ver()[0]
    report.item('PASS' if version(macos) >= (26, 0) else 'FAIL', 'macOS',
                f'{macos}; Apple Speech requires 26 or later')
    report.item('PASS', 'Python', platform.python_version() + ' (standard library only)')
    needed = ['xcodebuild', 'xcrun', 'xcode-select', 'codesign', 'plutil', 'lipo', 'otool', 'nm', 'lsof', 'open', 'sandbox-exec', 'say']
    missing = [name for name in needed if shutil.which(name) is None]
    report.item('FAIL' if missing else 'PASS', 'Commands',
                'Missing: ' + ', '.join(missing) if missing else 'All required Apple build, inspection, and speech tools found')
    if missing:
        return False
    try:
        developer = require('xcode-select', '-p')
        xcode = require('xcodebuild', '-version')
        ok = version(xcode) >= (26, 0) and Path(developer).is_dir() and '/CommandLineTools' not in developer
        report.item('PASS' if ok else 'FAIL', 'Xcode', xcode.replace('\n', ' · ') + f' · {developer}')
        if not ok:
            report.item('FAIL', 'Xcode selection', 'Select full Xcode 26+: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer')
            return False
        first_launch = command('xcodebuild', '-checkFirstLaunchStatus')
        report.item('PASS' if first_launch.returncode == 0 else 'FAIL', 'Xcode setup',
                    'First-launch components and license are ready' if first_launch.returncode == 0 else
                    'Open Xcode and complete its setup/license prompts; doctor does not accept agreements or install components.')
        sdk = require('xcrun', '--sdk', 'macosx', '--show-sdk-version')
        report.item('PASS' if version(sdk) >= (26, 0) else 'FAIL', 'macOS SDK', sdk + ' (26+ required)')
        swift = require('xcrun', 'swiftc', '--version').splitlines()[0]
        report.item('PASS' if version(swift) >= (6, 2) else 'FAIL', 'Swift compiler', swift + ' (6.2+ required)')
        require('xcrun', '--find', 'clang')
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        report.item('FAIL', 'Toolchain inspection', str(error))
    return report.failed == 0


def running_pids(binary=None):
    binary = BINARY if binary is None else binary
    paths = {str(binary), str(Path(binary).resolve())}
    pids = []
    for line in require('/bin/ps', '-axo', 'pid=,command=').splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and any(fields[1] == path or fields[1].startswith(path + ' ') for path in paths):
            pids.append(fields[0])
    return pids


def running_status(report):
    pids = running_pids() + running_pids(INSTALLED_APP / 'Contents/MacOS/VoiceInk')
    pids = list(dict.fromkeys(pids))
    if not pids:
        report.item('WARN', 'Running app', 'Not running. Use make run or make open.')
    for pid in pids:
        report.item('PASS', 'Running app', 'PID ' + pid)
        result = command('lsof', '-nP', '-a', '-p', pid, '-i')
        if result.returncode == 1 and not result.stdout.strip() and not result.stderr.strip():
            report.item('PASS', 'Runtime IP sockets', f'None observed for PID {pid} (point-in-time check)')
        elif result.returncode == 0 and result.stdout.strip():
            report.item('FAIL', 'Runtime IP sockets', result.stdout.strip())
        else:
            report.item('WARN', 'Runtime IP sockets', 'Unable to inspect: ' + result.stderr.strip())
    return pids


def app_checks(report):
    section('Built application')
    if not BINARY.exists():
        report.item('WARN', 'Build', 'No Release app yet. Run make build; signing and runtime checks are unavailable until then.')
        return
    report.item('PASS', 'Build', str(APP))
    try:
        archs = require('lipo', '-archs', BINARY).split()
        report.item('PASS' if platform.machine() in archs else 'FAIL', 'Architecture',
                    f"App: {', '.join(archs)} · host: {platform.machine()}")
        require('codesign', '--verify', '--deep', '--strict', APP)
        report.item('PASS', 'Code signature', 'Valid local signature; developer membership is not required')
        result = command('codesign', '-d', '--entitlements', ':-', APP)
        if result.returncode:
            raise RuntimeError(result.stderr)
        entitlements = plistlib.loads(result.stdout.encode())
        forbidden = [key for key, value in entitlements.items()
                     if value and any(word in key for word in ('network', 'icloud', 'ubiquity'))]
        report.item('FAIL' if forbidden else 'PASS', 'Signed entitlements',
                    ', '.join(forbidden) if forbidden else 'No network or iCloud grants')
        inputs = list((ROOT / 'VoiceInk').rglob('*')) + [ROOT / 'VoiceInk.xcodeproj/project.pbxproj']
        newer = [p for p in inputs if p.is_file() and p.stat().st_mtime > BINARY.stat().st_mtime]
        report.item('WARN' if newer else 'PASS', 'Build freshness',
                    f'{len(newer)} source/resource files are newer than the executable; run make build' if newer else
                    'No source or resource files newer than the executable')
        running_status(report)
    except (RuntimeError, ValueError, plistlib.InvalidFileException, subprocess.TimeoutExpired) as error:
        report.item('FAIL', 'Application inspection', str(error))


def preferences():
    result = command('defaults', 'export', 'local.VoiceInk.Offline', '-')
    if result.returncode:
        return {}
    return plistlib.loads(result.stdout.encode())


def compile_guard(directory):
    object_file = directory / 'guard.o'
    require('xcrun', 'clang', '-c', GUARD, '-o', object_file)
    return object_file


def capability_probe(directory):
    object_file = compile_guard(directory)
    executable = directory / 'doctor-probe'
    require('xcrun', 'swiftc', '-parse-as-library', ROOT / 'scripts/DoctorProbe.swift',
            object_file, '-o', executable, timeout=60)
    return json.loads(require(executable, timeout=30))


def speech_checks(report):
    section('Dictation readiness')
    try:
        with tempfile.TemporaryDirectory(prefix='voiceink-doctor-') as directory:
            capabilities = capability_probe(Path(directory))
        locales = capabilities['installedLocales']
        report.item('PASS' if locales else 'WARN', 'Installed Apple Speech languages',
                    ', '.join(locales) if locales else 'None. Download a language in VoiceInk → Speech Model; doctor itself never downloads.')
        prefs = preferences()
        locale = prefs.get('SelectedLanguage', 'en-US')
        report.item('PASS' if locale in locales else 'WARN', 'Selected language',
                    f'{locale} is installed' if locale in locales else f'{locale} is not installed; download it or select an installed language in Speech Model. Modes can override this selection.')
        report.item('PASS' if capabilities['hasDefaultInput'] else 'WARN', 'Default microphone',
                    'An input device is available (not activated)' if capabilities['hasDefaultInput'] else
                    f"No default audio input found (CoreAudio status {capabilities['audioStatus']}); connect/select a microphone.")
        shortcut = prefs.get('Shortcut_primaryRecording')
        if shortcut and not prefs.get('Shortcut_primaryRecording_cleared'):
            try:
                decoded = json.loads(shortcut)
                assigned = isinstance(decoded, dict) and bool(decoded)
            except (ValueError, TypeError):
                assigned = False
            report.item('PASS' if assigned else 'WARN', 'Primary shortcut',
                        'Assignment saved; behavior: ' + prefs.get('primaryRecordingShortcutMode', 'hybrid') if assigned else
                        'Saved shortcut could not be decoded; assign it again in Settings.')
        else:
            report.item('WARN', 'Primary shortcut', 'Not assigned. In Settings → Primary Shortcut, click Record and press your key combination.')
        onboarding = prefs.get('hasCompletedOnboardingV2', False)
        report.item('PASS' if onboarding else 'WARN', 'Onboarding',
                    'Completed' if onboarding else 'Open VoiceInk and finish local setup to create the default dictation mode.')
        report.item('WARN', 'App permissions & focus',
                    'This helper cannot verify VoiceInk’s microphone/Accessibility permissions or shortcut conflicts. Check Privacy & Security, selected input in Audio settings, and dictation in a focused text field. No permissions were requested or changed.')
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        report.item('FAIL', 'Speech capability probe', str(error))


def doctor():
    report = Report()
    section('VoiceInk doctor · local checks only')
    ready = prerequisites(report)
    section('Workspace')
    writable = os.access(ROOT, os.W_OK)
    report.item('PASS' if writable else 'FAIL', 'Repository', str(ROOT) + (' is writable' if writable else ' is not writable'))
    space = shutil.disk_usage(ROOT).free / 1024**3
    report.item('PASS' if space >= 5 else 'WARN', 'Free disk space', f'{space:.1f} GiB (5 GiB or more recommended for build output)')
    report.item('FAIL' if BUILD.is_symlink() else 'PASS', 'Build directory',
                'Symlink detected; remove/relocate it manually before building or cleaning' if BUILD.is_symlink() else str(BUILD))
    required = ['VoiceInk.xcodeproj/project.pbxproj', 'VoiceInk.xcodeproj/xcshareddata/xcschemes/VoiceInk.xcscheme',
                'VoiceInk/Info.plist', 'VoiceInk/VoiceInk.local.entitlements',
                'VoiceInk/Infrastructure/Privacy/OfflineNetworkGuard.c', 'scripts/check-offline.py']
    missing = [name for name in required if not (ROOT / name).is_file()]
    report.item('FAIL' if missing else 'PASS', 'Project files', ', '.join(missing) if missing else 'Project, scheme, metadata, entitlements, and offline guard present')
    if ready and not missing:
        section('Offline safeguards')
        try:
            audit = command(sys.executable, '-u', ROOT / 'scripts/check-offline.py', timeout=60)
            report.item('PASS' if audit.returncode == 0 else 'FAIL', 'Offline audit',
                        'Dependency, kernel-denial, fail-closed startup, and binary checks passed' if audit.returncode == 0 else 'Run make test for details')
            if audit.returncode:
                print((audit.stdout + audit.stderr)[-6000:])
        except (OSError, subprocess.TimeoutExpired) as error:
            report.item('FAIL', 'Offline audit', str(error))
        app_checks(report)
        speech_checks(report)
    else:
        report.item('WARN', 'Dependent checks', 'Skipped offline runtime, app, and speech checks until prerequisites are repaired.')
    return report.summary()


def speech_test():
    section('Native speech smoke test · no microphone capture or downloads')
    with tempfile.TemporaryDirectory(prefix='voiceink-speech-test-') as directory:
        directory = Path(directory)
        capabilities = capability_probe(directory)
        if 'en-US' not in capabilities['installedLocales']:
            raise RuntimeError('en-US speech assets are not installed. Download English (United States) in VoiceInk → Speech Model first; this test never downloads assets.')
        # Verify the chosen voice is installed before invoking synthesis.
        voices = require('sandbox-exec', '-p', '(version 1)(allow default)(deny network*)', 'say', '-v', '?')
        if not re.search(r'^Samantha\s+en_US\b', voices, re.M):
            raise RuntimeError('The local Samantha voice is unavailable; no voice download attempted.')
        fixture = directory / 'fixture.aiff'
        require('sandbox-exec', '-p', '(version 1)(allow default)(deny network*)', 'say', '-v', 'Samantha', '-o', fixture,
                'Voice Ink works completely offline. This is a local transcription test.')
        executable = directory / 'speech-test'
        require('xcrun', 'swiftc', '-parse-as-library', '-D', 'ENABLE_NATIVE_SPEECH_ANALYZER',
                ROOT / 'Tests/Offline/NativeSpeechSmoke.swift',
                ASSET_MANAGER, APPLE_SPEECH / 'NativeAppleTranscriptionService.swift',
                directory / 'guard.o', '-o', executable, timeout=60)
        print(require(executable, fixture, timeout=60))
    return 0


def language_download_test(language):
    # Validate before compiling or running anything; the value reaches a subprocess argument.
    if not LANGUAGE_PATTERN.fullmatch(language or ''):
        raise RuntimeError('Name one Apple Speech language, for example: make test-language LANGUAGE=de-DE')
    section('Language download check · macOS downloads, this process stays network-denied')
    with tempfile.TemporaryDirectory(prefix='voiceink-language-test-') as directory:
        directory = Path(directory)
        executable = directory / 'language-download-check'
        require('xcrun', 'swiftc', '-parse-as-library', '-D', 'ENABLE_NATIVE_SPEECH_ANALYZER',
                ROOT / 'Tests/Offline/LanguageDownloadCheck.swift', ASSET_MANAGER,
                compile_guard(directory), '-o', executable, timeout=60)
        print(require(executable, language, timeout=LANGUAGE_DOWNLOAD_TIMEOUT))
    return 0


def bundle_id(app):
    try:
        return plistlib.loads((app / 'Contents/Info.plist').read_bytes()).get('CFBundleIdentifier')
    except (OSError, ValueError, plistlib.InvalidFileException):
        return None


def install_app(install_dir):
    destination = Path(install_dir).expanduser() / 'VoiceInk.app'
    if not BINARY.is_file() or bundle_id(APP) != BUNDLE_ID:
        raise RuntimeError('No valid offline build found. Run make build first.')
    if destination.is_symlink():
        raise RuntimeError(f'Refusing to replace a symlink: {destination}')
    if destination.resolve() == APP.resolve():
        raise RuntimeError('The install destination is the build itself; choose /Applications or ~/Applications.')
    if destination.exists() and bundle_id(destination) != BUNDLE_ID:
        raise RuntimeError(f'{destination} belongs to a different app or is not a valid offline bundle. Move it aside or choose INSTALL_DIR; it was not changed.')
    if running_pids(destination / 'Contents/MacOS/VoiceInk'):
        raise RuntimeError(f'Quit the installed app before replacing {destination}; it was not changed.')
    require('/usr/bin/codesign', '--verify', '--deep', '--strict', APP)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not os.access(destination.parent, os.W_OK):
        raise RuntimeError(f'Cannot write to {destination.parent}. Use make install INSTALL_DIR="$HOME/Applications", or copy the built app in Finder with administrator approval.')
    staging = Path(tempfile.mkdtemp(prefix='.voiceink-install-', dir=destination.parent))
    staged_app = staging / 'VoiceInk.app'
    backup = staging / 'previous.app'
    try:
        require('/usr/bin/ditto', APP, staged_app, timeout=60)
        require('/usr/bin/codesign', '--verify', '--deep', '--strict', staged_app)
        if bundle_id(staged_app) != BUNDLE_ID:
            raise RuntimeError('The staged app has an unexpected bundle identifier.')
        # Recheck after copying so a newly launched app is never intentionally replaced.
        if running_pids(destination / 'Contents/MacOS/VoiceInk'):
            raise RuntimeError('The installed app started while copying. Quit it and retry.')
        if destination.is_symlink() or (destination.exists() and bundle_id(destination) != BUNDLE_ID):
            raise RuntimeError('The destination changed while copying; no replacement was performed.')
        if destination.exists():
            destination.rename(backup)
        try:
            staged_app.rename(destination)
            require('/usr/bin/codesign', '--verify', '--deep', '--strict', destination)
        except Exception:
            if destination.exists():
                destination.rename(staging / 'failed.app')
            if backup.exists():
                backup.rename(destination)
            raise
    except Exception as error:
        if backup.exists():
            # Never discard the previous app if restoring it itself fails.
            raise RuntimeError(f'Installation failed. Previous app preserved at {backup}: {error}') from error
        shutil.rmtree(staging)
        raise
    else:
        shutil.rmtree(staging)
    print(paint('Installed', '32'), destination)
    print('Quit any other VoiceInk instance, then open this copy to use it. Settings and history are preserved.')
    return 0


def signal_matching_pids(binary, pids, sig):
    for pid in pids:
        # Recheck identity before each signal; never kill by process name alone.
        if pid not in running_pids(binary):
            continue
        try:
            os.kill(int(pid), sig)
        except ProcessLookupError:
            pass  # The app exited between inspection and signaling.


def wait_for_app_exit(binary, timeout):
    deadline = time.monotonic() + timeout
    while True:
        remaining = running_pids(binary)
        if not remaining or time.monotonic() >= deadline:
            return remaining
        time.sleep(0.1)


def kill_installed(install_dir):
    installed = Path(install_dir).expanduser().absolute() / 'VoiceInk.app'
    if installed.is_symlink() or installed.resolve() == APP.resolve():
        raise RuntimeError('Refusing to stop a symlink or the development build; choose the installed copy.')
    if not installed.exists():
        print('No installed VoiceInk app at', installed, '— nothing to stop.')
        return 0
    if bundle_id(installed) != BUNDLE_ID:
        raise RuntimeError(f'{installed} is not the offline VoiceInk app; no processes were stopped.')
    binary = installed / 'Contents/MacOS/VoiceInk'
    pids = running_pids(binary)
    if not pids:
        print('Installed VoiceInk is already stopped.')
        return 0
    print('Stopping', installed, '— an active recording may be lost.')
    signal_matching_pids(binary, pids, signal.SIGTERM)
    remaining = wait_for_app_exit(binary, 5)
    if remaining:
        # Do not terminate a new instance that launched while we were waiting.
        survivors = [pid for pid in remaining if pid in pids]
        signal_matching_pids(binary, survivors, signal.SIGKILL)
        remaining = wait_for_app_exit(binary, 2)
    if remaining:
        raise RuntimeError('Installed VoiceInk is still running or restarted (PID ' + ', '.join(remaining) + ').')
    print(paint('Stopped', '32'), installed)
    return 0


def reset_permissions():
    # Always include the fixed offline bundle ID; never reset other apps' grants.
    output = require('/usr/bin/tccutil', 'reset', 'All', BUNDLE_ID)
    if output:
        print(output)
    print(paint('Reset privacy permissions for', '32'), BUNDLE_ID)
    print('Quit and reopen VoiceInk. Allow Microphone and Accessibility again when needed; check Input Monitoring if shortcuts do not respond.')
    print('Settings, history, and Launch at Login were not reset.')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['doctor', 'check', 'built', 'open', 'status', 'clean', 'test-speech', 'test-language', 'install', 'open-installed', 'kill-installed', 'reset-permissions'])
    parser.add_argument('--install-dir', default='/Applications')
    parser.add_argument('--language', default='')
    args = parser.parse_args()
    action = args.action
    if action == 'install':
        return install_app(args.install_dir)
    if action == 'kill-installed':
        return kill_installed(args.install_dir)
    if action == 'reset-permissions':
        return reset_permissions()
    if action == 'open-installed':
        installed = Path(args.install_dir).expanduser() / 'VoiceInk.app'
        if bundle_id(installed) != BUNDLE_ID:
            raise RuntimeError('Offline VoiceInk is not installed there. Run make install first.')
        require('open', installed)
        print(paint('Opened', '32'), installed)
        return 0
    if action == 'doctor':
        return doctor()
    if action == 'check':
        report = Report()
        prerequisites(report)
        if BUILD.is_symlink():
            report.item('FAIL', 'Build directory', '.local-build is a symlink; refusing to write outside the repository.')
        return report.summary()
    if action == 'test-speech':
        return speech_test()
    if action == 'test-language':
        return language_download_test(args.language)
    if action == 'clean':
        if BUILD.is_symlink() or BUILD.resolve() != ROOT / '.local-build':
            raise RuntimeError('Refusing to clean a symlink or a build path outside this repository.')
        if running_pids():
            raise RuntimeError('VoiceInk is running from .local-build. Quit it before make clean or make rebuild; no files were removed.')
        if BUILD.exists():
            shutil.rmtree(BUILD)
        print(paint('Cleaned', '32'), BUILD, '— settings and transcription history preserved.')
        return 0
    if action == 'status':
        report = Report()
        print('App:', APP)
        report.item('PASS' if BINARY.exists() else 'WARN', 'Build', 'Present' if BINARY.exists() else 'Missing; run make build')
        running_status(report)
        return report.summary()
    if not BINARY.exists():
        raise RuntimeError('No built VoiceInk app found. Run make build first.')
    if action == 'built':
        print(paint('Built', '32'), APP)
    elif action == 'open':
        already_running = bool(running_pids())
        require('open', APP)
        print(paint('Opened', '32'), APP)
        if already_running:
            print('An existing instance is running. To load a newly rebuilt binary, quit VoiceInk and run make open.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        print(paint('FAIL', '31') + '  ' + str(error), file=sys.stderr)
        sys.exit(1)
