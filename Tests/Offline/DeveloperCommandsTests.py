"""Failure-path tests; never builds, launches, or cleans the real app."""
import contextlib
import importlib.util
import io
import os
import plistlib
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('voiceink_dev', ROOT / 'scripts/dev.py')
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class DeveloperCommandsTests(unittest.TestCase):
    def setUp(self):
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()

    def tearDown(self):
        self.output.__exit__(None, None, None)

    def make(self, *args, **env):
        environment = dict(os.environ)
        environment.pop('NO_COLOR', None)
        environment.pop('MAKEFLAGS', None)
        environment.update(env)
        return subprocess.run(['make', '--no-print-directory', *args], cwd=ROOT,
                              capture_output=True, text=True, env=environment, check=True).stdout

    def test_plain_make_is_help_only(self):
        plain = self.make(COLOR='never')
        self.assertEqual(plain, self.make('help', COLOR='never'))
        self.assertIn('Help & diagnostics', plain)
        self.assertIn('Housekeeping', plain)
        self.assertNotIn('Build settings from command line', plain)

    def test_forced_and_disabled_colors(self):
        self.assertIn('\x1b[', self.make(COLOR='always'))
        self.assertNotIn('\x1b[', self.make(COLOR='never'))
        self.assertNotIn('\x1b[', self.make(COLOR='always', NO_COLOR='1'))

    def test_unsupported_host_fails_cleanly(self):
        report = dev.Report()
        with patch.object(dev.platform, 'system', return_value='Linux'):
            self.assertFalse(dev.prerequisites(report))
        self.assertEqual(report.failed, 1)

    def test_missing_tools_do_not_run_dependent_commands(self):
        report = dev.Report()
        with patch.object(dev.platform, 'system', return_value='Darwin'), \
             patch.object(dev.platform, 'mac_ver', return_value=('26.0', (), '')), \
             patch.object(dev.shutil, 'which', return_value=None), \
             patch.object(dev, 'require') as require:
            self.assertFalse(dev.prerequisites(report))
            require.assert_not_called()
        self.assertGreater(report.failed, 0)

    def test_old_xcode_fails(self):
        report = dev.Report()
        with patch.object(dev.platform, 'system', return_value='Darwin'), \
             patch.object(dev.platform, 'mac_ver', return_value=('26.0', (), '')), \
             patch.object(dev.shutil, 'which', return_value='/usr/bin/tool'), \
             patch.object(dev.Path, 'is_dir', return_value=True), \
             patch.object(dev, 'require', side_effect=['/Applications/Xcode.app/Contents/Developer', 'Xcode 16.4']):
            self.assertFalse(dev.prerequisites(report))
        self.assertGreater(report.failed, 0)

    def test_warnings_and_failures_have_distinct_exit_codes(self):
        report = dev.Report()
        report.item('WARN', 'Manual check', 'permission')
        self.assertEqual(report.summary(), 0)
        report.item('FAIL', 'Missing dependency', 'Xcode')
        self.assertEqual(report.summary(), 1)

    def test_missing_app_is_actionable(self):
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(dev, 'BINARY', Path(directory) / 'missing'), \
             patch.object(sys, 'argv', ['dev.py', 'open']), \
             patch.object(dev, 'require') as require:
            with self.assertRaisesRegex(RuntimeError, 'make build'):
                dev.main()
            require.assert_not_called()

    def test_clean_refuses_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            outside = root / 'keep'
            outside.mkdir()
            sentinel = outside / 'important.txt'
            sentinel.write_text('keep')
            build = root / '.local-build'
            build.symlink_to(outside, target_is_directory=True)
            with patch.object(dev, 'ROOT', root), patch.object(dev, 'BUILD', build), \
                 patch.object(sys, 'argv', ['dev.py', 'clean']):
                with self.assertRaisesRegex(RuntimeError, 'symlink'):
                    dev.main()
            self.assertEqual(sentinel.read_text(), 'keep')

    def test_clean_refuses_running_app_then_cleans_only_build(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            build = root / '.local-build'
            build.mkdir()
            history = root / 'history'
            history.write_text('keep')
            with patch.object(dev, 'ROOT', root), patch.object(dev, 'BUILD', build), \
                 patch.object(sys, 'argv', ['dev.py', 'clean']):
                with patch.object(dev, 'running_pids', return_value=['123']):
                    with self.assertRaisesRegex(RuntimeError, 'Quit it'):
                        dev.main()
                self.assertTrue(build.exists())
                with patch.object(dev, 'running_pids', return_value=[]):
                    self.assertEqual(dev.main(), 0)
            self.assertFalse(build.exists())
            self.assertEqual(history.read_text(), 'keep')

    def test_process_lookup_handles_arguments_without_matching_other_binaries(self):
        process_list = f'123 {dev.BINARY}\n456 {dev.BINARY} --test\n789 {dev.BINARY}-other\n'
        with patch.object(dev, 'require', return_value=process_list):
            self.assertEqual(dev.running_pids(), ['123', '456'])


    def fake_bundle(self, path, identity=None, content='new'):
        (path / 'Contents/MacOS').mkdir(parents=True)
        (path / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': identity or dev.BUNDLE_ID}))
        (path / 'Contents/MacOS/VoiceInk').write_text(content)
        return path

    def copy_command(self, *args, **kwargs):
        if args[0] == '/usr/bin/ditto':
            shutil.copytree(args[1], args[2])
        return ''

    def test_install_replaces_bundle_without_merging_old_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fake_bundle(root / 'build/VoiceInk.app')
            destination = self.fake_bundle(root / 'Applications With Spaces/VoiceInk.app', content='old')
            (destination / 'obsolete').write_text('old file')
            with patch.object(dev, 'APP', source), patch.object(dev, 'BINARY', source / 'Contents/MacOS/VoiceInk'), \
                 patch.object(dev, 'running_pids', return_value=[]), patch.object(dev, 'require', side_effect=self.copy_command):
                self.assertEqual(dev.install_app(destination.parent), 0)
            self.assertEqual((destination / 'Contents/MacOS/VoiceInk').read_text(), 'new')
            self.assertFalse((destination / 'obsolete').exists())
            self.assertEqual(list(destination.parent.iterdir()), [destination])

    def test_install_rejects_different_app_and_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fake_bundle(root / 'build/VoiceInk.app')
            destination = self.fake_bundle(root / 'Applications/VoiceInk.app', identity='com.someone.Original')
            with patch.object(dev, 'APP', source), patch.object(dev, 'BINARY', source / 'Contents/MacOS/VoiceInk'):
                with self.assertRaisesRegex(RuntimeError, 'different app'):
                    dev.install_app(destination.parent)
                shutil.rmtree(destination)
                destination.symlink_to(source, target_is_directory=True)
                with self.assertRaisesRegex(RuntimeError, 'symlink'):
                    dev.install_app(destination.parent)
            self.assertTrue(source.exists())

    def test_install_refuses_running_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fake_bundle(root / 'build/VoiceInk.app')
            destination = self.fake_bundle(root / 'Applications/VoiceInk.app', content='old')
            with patch.object(dev, 'APP', source), patch.object(dev, 'BINARY', source / 'Contents/MacOS/VoiceInk'), \
                 patch.object(dev, 'running_pids', return_value=['123']), patch.object(dev, 'require') as command:
                with self.assertRaisesRegex(RuntimeError, 'Quit the installed app'):
                    dev.install_app(destination.parent)
                command.assert_not_called()
            self.assertEqual((destination / 'Contents/MacOS/VoiceInk').read_text(), 'old')

    def test_install_copy_failure_preserves_existing_app(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fake_bundle(root / 'build/VoiceInk.app')
            destination = self.fake_bundle(root / 'Applications/VoiceInk.app', content='old')
            def fail_copy(*args, **kwargs):
                if args[0] == '/usr/bin/ditto':
                    raise RuntimeError('copy failed')
                return ''
            with patch.object(dev, 'APP', source), patch.object(dev, 'BINARY', source / 'Contents/MacOS/VoiceInk'), \
                 patch.object(dev, 'running_pids', return_value=[]), patch.object(dev, 'require', side_effect=fail_copy):
                with self.assertRaisesRegex(RuntimeError, 'copy failed'):
                    dev.install_app(destination.parent)
            self.assertEqual((destination / 'Contents/MacOS/VoiceInk').read_text(), 'old')
            self.assertEqual(list(destination.parent.iterdir()), [destination])

    def test_install_final_signature_failure_rolls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fake_bundle(root / 'build/VoiceInk.app')
            destination = self.fake_bundle(root / 'Applications/VoiceInk.app', content='old')
            def fail_final_verification(*args, **kwargs):
                if args[0] == '/usr/bin/codesign' and args[-1] == destination:
                    raise RuntimeError('invalid signature')
                return self.copy_command(*args, **kwargs)
            with patch.object(dev, 'APP', source), patch.object(dev, 'BINARY', source / 'Contents/MacOS/VoiceInk'), \
                 patch.object(dev, 'running_pids', return_value=[]), patch.object(dev, 'require', side_effect=fail_final_verification):
                with self.assertRaisesRegex(RuntimeError, 'invalid signature'):
                    dev.install_app(destination.parent)
            self.assertEqual((destination / 'Contents/MacOS/VoiceInk').read_text(), 'old')
            self.assertEqual(list(destination.parent.iterdir()), [destination])

    def test_permission_reset_is_always_bundle_scoped(self):
        with patch.object(dev, 'require', return_value='Successfully reset') as command:
            self.assertEqual(dev.reset_permissions(), 0)
        command.assert_called_once_with('/usr/bin/tccutil', 'reset', 'All', 'local.VoiceInk.Offline')

    def test_kill_installed_missing_or_stopped_is_success(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(dev.os, 'kill') as kill:
            self.assertEqual(dev.kill_installed(directory), 0)
            self.fake_bundle(Path(directory) / 'VoiceInk.app')
            with patch.object(dev, 'running_pids', return_value=[]):
                self.assertEqual(dev.kill_installed(directory), 0)
            kill.assert_not_called()

    def test_kill_installed_rejects_foreign_app_symlink_and_build(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(dev.os, 'kill') as kill:
            root = Path(directory)
            installed = self.fake_bundle(root / 'Applications/VoiceInk.app', identity='other.app')
            with self.assertRaisesRegex(RuntimeError, 'not the offline'):
                dev.kill_installed(installed.parent)
            shutil.rmtree(installed)
            source = self.fake_bundle(root / 'build/VoiceInk.app')
            installed.symlink_to(source, target_is_directory=True)
            with self.assertRaisesRegex(RuntimeError, 'symlink'):
                dev.kill_installed(installed.parent)
            with patch.object(dev, 'APP', source):
                with self.assertRaisesRegex(RuntimeError, 'development build'):
                    dev.kill_installed(source.parent)
            kill.assert_not_called()

    def test_kill_installed_escalates_only_original_pids(self):
        with tempfile.TemporaryDirectory() as directory:
            installed = self.fake_bundle(Path(directory) / 'VoiceInk.app')
            binary = installed / 'Contents/MacOS/VoiceInk'
            with patch.object(dev, 'running_pids', return_value=['123']) as lookup, \
                 patch.object(dev, 'wait_for_app_exit', side_effect=[['123', '456'], ['456']]), \
                 patch.object(dev.os, 'kill') as kill:
                with self.assertRaisesRegex(RuntimeError, 'restarted'):
                    dev.kill_installed(directory)
                self.assertEqual([call.args for call in kill.call_args_list],
                                 [(123, dev.signal.SIGTERM), (123, dev.signal.SIGKILL)])
                self.assertTrue(all(call.args == (binary,) for call in lookup.call_args_list))

    def test_signal_rechecks_process_identity_and_tolerates_exit(self):
        with patch.object(dev, 'running_pids', return_value=[]), patch.object(dev.os, 'kill') as kill:
            dev.signal_matching_pids(Path('/fake/binary'), ['123'], dev.signal.SIGTERM)
            kill.assert_not_called()
        with patch.object(dev, 'running_pids', return_value=['123']), \
             patch.object(dev.os, 'kill', side_effect=ProcessLookupError):
            dev.signal_matching_pids(Path('/fake/binary'), ['123'], dev.signal.SIGTERM)

    @unittest.skipUnless(shutil.which('clang'), 'requires the local C compiler for a dummy process')
    def test_kill_installed_stops_real_dummy_process_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / 'dummy'
            subprocess.run(['clang', '-x', 'c', '-', '-o', str(executable)],
                           input='#include <unistd.h>\nint main(void) { sleep(30); return 0; }\n',
                           text=True, capture_output=True, check=True)
            installed = self.fake_bundle(root / 'Applications With Spaces/VoiceInk.app')
            other = self.fake_bundle(root / 'build/VoiceInk.app')
            processes = []
            try:
                for app in (installed, other):
                    binary = app / 'Contents/MacOS/VoiceInk'
                    shutil.copyfile(executable, binary)
                    binary.chmod(0o755)
                    processes.append(subprocess.Popen([str(binary), '30']))
                with patch.object(sys, 'argv', ['dev.py', 'kill-installed', '--install-dir', str(installed.parent)]):
                    self.assertEqual(dev.main(), 0)
                self.assertEqual(processes[0].wait(timeout=2), -dev.signal.SIGTERM)
                self.assertIsNone(processes[1].poll(), 'Development process must remain running')
            finally:
                for process in processes:
                    if process.poll() is None:
                        process.kill()
                    process.wait(timeout=2)

    def test_permission_reset_failure_never_retries_globally(self):
        with patch.object(dev, 'require', side_effect=RuntimeError('permission denied')) as command:
            with self.assertRaisesRegex(RuntimeError, 'permission denied'):
                dev.reset_permissions()
        self.assertEqual(command.call_count, 1)
        self.assertEqual(command.call_args.args[-1], 'local.VoiceInk.Offline')


if __name__ == '__main__':
    unittest.main(verbosity=2)
