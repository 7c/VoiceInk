#!/usr/bin/env python3
"""Compile and exercise the real snippet matcher using only the local Swift SDK."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='voiceink-snippet-tests-') as directory:
    executable = str(Path(directory) / 'snippet-tests')
    subprocess.run([
        'xcrun', 'swiftc',
        str(root / 'VoiceInk/Features/Recording/Processing/PromptSnippet.swift'),
        str(root / 'Tests/Offline/PromptSnippetTests.swift'),
        '-o', executable,
    ], check=True)
    subprocess.run([executable], check=True)
