"""Publication checks use synthetic values; no real secrets or personal paths."""
import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('public_check', Path(__file__).resolve().parents[2] / 'scripts/check-public-repo.py')
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class PublicRepoTests(unittest.TestCase):
    def categories(self, data, path='sample.swift'):
        return {category for _, category in check.findings(path, data)}

    def test_local_paths_and_private_emails(self):
        path = b'/' + b'Users' + b'/fictional/project'
        self.assertIn('private absolute path', self.categories(path))
        email = b'fictional@' + b'private.invalid'
        self.assertIn('email requiring review', self.categories(email))

    def test_secrets_and_signing_teams(self):
        samples = [
            (b'ghp_' + b'x' * 30, 'credential token'),
            (b'-----BEGIN ' + b'PRIVATE KEY-----', 'private key'),
            (b'https://' + b'name:password' + b'@example.com', 'credential in URL'),
            (b'DEVELOPMENT_TEAM = "' + b'X' * 10 + b'";', 'Apple signing team'),
        ]
        for data, category in samples:
            with self.subTest(category=category):
                self.assertIn(category, self.categories(data))

    def test_generated_and_private_files_even_when_empty(self):
        for path in ['.env', 'recordings/sample.wav', 'debug.log', 'VoiceInk.app/Contents/Info.plist', 'identity.p12']:
            with self.subTest(path=path):
                self.assertIn('private or generated file', self.categories(b'', path))

    def test_public_examples_and_portable_paths(self):
        self.assertFalse(self.categories(b'support@tryvoiceink.com developer@example.com contributor@users.noreply.github.com'))
        self.assertFalse(self.categories(b'$HOME/Applications ~/Library/Application Support /Applications/VoiceInk.app'))
        self.assertFalse(self.categories(b'API_KEY=', '.env.example'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
