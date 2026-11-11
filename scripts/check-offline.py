#!/usr/bin/env python3
"""Audit the offline build and test the actual production network guard. Downloads nothing."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)

project = json.loads(subprocess.check_output([
    '/usr/bin/plutil', '-convert', 'json', '-o', '-',
    str(ROOT / 'VoiceInk.xcodeproj/project.pbxproj')
]))
for obj in project['objects'].values():
    assert obj['isa'] not in {'XCRemoteSwiftPackageReference', 'XCLocalSwiftPackageReference', 'XCSwiftPackageProductDependency'}, obj
    assert not obj.get('packageReferences') and not obj.get('packageProductDependencies'), obj
    assert 'xcframework' not in obj.get('path', ''), obj
    assert obj['isa'] != 'PBXShellScriptBuildPhase', 'Unexpected build script'
assert not list(ROOT.rglob('Package.resolved'))

ASSET_MANAGER = 'NativeAppleSpeechAssetManager.swift'
INSTALL_COORDINATOR = 'NativeAppleSpeechAssetInstallCoordinator.swift'
LANGUAGE_CONTROL = 'NativeAppleLanguageAssetControl.swift'
INSTALL_PATH_RULES = [
    (r'assetInstallationRequest|downloadAndInstall', {ASSET_MANAGER}),
    (r'\b(installAsset|prepareAssetForUse)\b', {ASSET_MANAGER, INSTALL_COORDINATOR}),
    (r'\bNativeAppleSpeechAssetInstallCoordinator\b', {INSTALL_COORDINATOR, LANGUAGE_CONTROL}),
]

allowed_modules = {
    'AVFoundation', 'AppIntents', 'AppKit', 'ApplicationServices', 'AudioToolbox', 'Carbon',
    'Charts', 'Cocoa', 'Combine', 'CoreAudio', 'CoreFoundation', 'CoreGraphics', 'Darwin',
    'Foundation', 'IOKit', 'NaturalLanguage', 'OSLog', 'ScreenCaptureKit', 'Security',
    'ServiceManagement', 'Speech', 'SwiftData', 'SwiftUI', 'Synchronization',
    'UniformTypeIdentifiers', 'Vision', 'os'
}
for source in (ROOT / 'VoiceInk').rglob('*.swift'):
    text = source.read_text()
    for module in re.findall(r'^\s*import (\w+)', text, re.M):
        assert module in allowed_modules, (source, module)
    assert not re.search(r'\b(URLSession|URLRequest|NWConnection|NWListener|NSUbiquitousKeyValueStore)\b', text), source
    assert not re.search(r'cloudKitDatabase:\s*\.private', text), source
    # A language install is requested from macOS, which downloads in its own services while this
    # process stays network-denied. Each layer of that path may be referenced only by the next,
    # so the Download button in the language control remains the only way to start one.
    for pattern, allowed in INSTALL_PATH_RULES:
        if re.search(pattern, text):
            assert source.name in allowed, (source, pattern)
    assert not re.search(r'kSecAttrSynchronizable[^\n]*= kCFBooleanTrue', text), source
    if 'NSWorkspace.shared.open(' in text:
        assert source.name == 'OfflineWorkspace.swift', source

for path in (ROOT / 'VoiceInk').glob('*.entitlements'):
    entitlements = plistlib.loads(path.read_bytes())
    assert not any('network' in key or 'icloud' in key or 'ubiquity' in key for key in entitlements), path
print('PASS: no packages, third-party imports, cloud stores, or network clients; language installs go only through macOS')

with tempfile.TemporaryDirectory(prefix='voiceink-offline-check-') as directory:
    directory = Path(directory)
    guard = ROOT / 'VoiceInk/Infrastructure/Privacy/OfflineNetworkGuard.c'
    probe = directory / 'network-probe'
    run('xcrun', 'clang', str(guard), str(ROOT / 'Tests/Offline/NetworkGuardTests.c'), '-o', str(probe))
    run(str(probe))
    # Verify guard installation failure terminates before main, rather than allowing an online launch.
    failure = directory / 'failure.c'
    failure.write_text('''#include <stdint.h>
int voiceink_test_sandbox_init(const char *p, uint64_t f, char **e) { return -1; }
int main(void) { return 0; }
''')
    executable = directory / 'fail-closed'
    run('xcrun', 'clang', '-Dsandbox_init=voiceink_test_sandbox_init', str(guard), str(failure), '-o', str(executable))
    result = subprocess.run([str(executable)], capture_output=True, text=True)
    assert result.returncode == 78, result
    print('PASS: app aborts when the network restriction cannot be installed')

app = ROOT / '.local-build/Build/Products/Release/VoiceInk.app'
executable = app / 'Contents/MacOS/VoiceInk'
if executable.exists():
    linked = subprocess.check_output(['/usr/bin/otool', '-L', str(executable)], text=True)
    for line in linked.splitlines()[1:]:
        library = line.strip().split(' (')[0]
        assert library.startswith(('/System/Library/', '/usr/lib/', '/Library/Apple/System/Library/')), library
    assert not (app / 'Contents/Frameworks').exists() or not list((app / 'Contents/Frameworks').iterdir())
    symbols = subprocess.check_output(['/usr/bin/nm', str(executable)], text=True)
    assert '_enforce_offline_mode' in symbols, 'Network constructor missing from built app'
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
    print('PASS: signed app links only OS libraries and includes its network guard')
