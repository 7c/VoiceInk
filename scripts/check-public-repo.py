#!/usr/bin/env python3
"""Offline publication check. Reports file/line/category, never secret values.

Checks tracked and non-ignored files, or the exact Git index with --staged.
This is a heuristic check, not a guarantee that arbitrary PII is absent.
Upstream attribution and the public product support address are intentional.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RULES = {
    'private absolute path': rb'(?:/(?:Users|Volumes|home)/|/(?:private/)?var/folders/|[A-Za-z]:\\Users\\)[^\s\x00<>"\']+',
    'private key': rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
    'credential token': rb'(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{24,}|AKIA[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]{15,})',
    'credential in URL': rb'https?://[^\s/:@]+:[^\s/@]+@',
    'Apple signing team': rb'(?:DEVELOPMENT_TEAM\s*=\s*"?[A-Z0-9]{10}|<key>teamID</key>\s*<string>[A-Z0-9]{10})',
}
EMAIL = re.compile(rb'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
PUBLIC_EMAILS = {b'support@tryvoiceink.com'}
PRIVATE_SUFFIXES = {'.pem', '.key', '.p8', '.p12', '.pfx', '.mobileprovision', '.log', '.sqlite', '.db', '.pyc', '.profraw', '.profdata'}
PRIVATE_DIRS = {'xcuserdata', '__pycache__', '.local-build', '.review-build', '.local-dependencies', 'recordings', 'transcripts', 'private'}


def findings(path, data):
    path = Path(path)
    if (path.suffix in PRIVATE_SUFFIXES or any(part in PRIVATE_DIRS or part.endswith(('.app', '.dSYM', '.xcarchive', '.xcresult')) for part in path.parts)
            or (path.name.startswith('.env') and path.name not in {'.env.example', '.env.sample'})):
        yield 0, 'private or generated file'
    for label, pattern in RULES.items():
        for match in re.finditer(pattern, data):
            yield data[:match.start()].count(b'\n') + 1, label
    for match in EMAIL.finditer(data):
        address = match.group().lower()
        domain = address.split(b'@')[1]
        if address not in PUBLIC_EMAILS and domain not in {b'example.com', b'example.org', b'example.net', b'users.noreply.github.com'}:
            yield data[:match.start()].count(b'\n') + 1, 'email requiring review'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--staged', action='store_true', help='check the exact contents to be committed')
    args = parser.parse_args()
    options = ['--cached'] if args.staged else ['--cached', '--others', '--exclude-standard']
    names = sorted(set(filter(None, git('ls-files', '-z', *options).decode().split('\0'))))
    failures = checked = 0
    for name in names:
        path = ROOT / name
        if args.staged:
            data = git('show', ':' + name)
        else:
            if not path.exists():
                continue  # A deletion waiting to be staged.
            if path.is_symlink():
                print(f'FAIL {name}: symlink requires manual review')
                failures += 1
                continue
            data = path.read_bytes()
        checked += 1
        for line, category in findings(name, data):
            print(f'FAIL {name}:{line}: {category}')
            failures += 1
    print(f'{"FAIL" if failures else "PASS"}: checked {checked} {"staged" if args.staged else "publishable"} files; {failures} findings.')
    print('Scope: common secrets, personal absolute paths, email addresses, signing teams, and generated artifacts. Review history and media separately.')
    return int(failures != 0)


if __name__ == '__main__':
    sys.exit(main())
