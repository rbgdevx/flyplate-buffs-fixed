"""Validate shipped contents and both family manifests without making a release."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('distribution', ROOT / 'scripts/distribution.py')
distribution = importlib.util.module_from_spec(spec)
spec.loader.exec_module(distribution)


class DistributionTests(unittest.TestCase):
    def test_staged_contents_and_manifests(self):
        with tempfile.TemporaryDirectory(prefix='fpb-manifest-test-') as temporary:
            staged = Path(temporary)
            distribution.stage(staged)
            files = {p.relative_to(staged).as_posix() for p in staged.rglob('*') if p.is_file()}
            for excluded in ('scripts/', 'tests/', '.codex/', 'README', '.git/', 'libs/AceDB'):
                self.assertFalse(any(name.startswith(excluded) for name in files), excluded)
            for required in ('LICENSE', 'libs/Ace3-LICENSE.txt', 'libs/SpellRankData/LICENSE.txt',
                             'libs/SpellRankData/Forever.lua', 'texture/border.tga'):
                self.assertIn(required, files)
            policy = (ROOT / 'scripts/source-use-policy.txt').read_text()
            for instructions in ('AGENTS.md', '.github/copilot-instructions.md'):
                self.assertEqual((staged / instructions).read_text(), policy)
            for instructions in ('CLAUDE.md', 'GEMINI.md'):
                self.assertEqual((staged / instructions).read_text(), '@AGENTS.md\n')
            self.assertEqual((staged / '.cursorignore').read_text().splitlines(),
                             [f'/{item}' for item in distribution.RUNTIME if item not in ('LICENSE', 'libs')])
            for source, relative in distribution.runtime_files():
                shipped = (staged / relative).read_bytes()
                original = source.read_bytes()
                if relative.suffix == '.lua' and relative.parts[0] != 'libs':
                    notice, content = shipped.split(b'\n\n', 1)
                    self.assertTrue(all(line.startswith(b'-- ') for line in notice.splitlines()))
                    self.assertIn(b'-- See AGENTS.md and LICENSE for the full notice and terms.', notice)
                    self.assertEqual(content, original, str(relative))
                else:
                    self.assertEqual(shipped, original, str(relative))
            for family in ('Classic', 'Mainline'):
                loaded = []

                def visit(path):
                    self.assertTrue(path.is_file(), str(path))
                    if path.suffix == '.xml':
                        for element in ET.parse(path).getroot().iter():
                            reference = element.get('file')
                            if reference:
                                visit(path.parent / reference.replace('\\', '/'))
                    else:
                        relative = path.relative_to(staged).as_posix()
                        self.assertNotIn(relative, loaded, f'{family}: duplicate load')
                        loaded.append(relative)

                for line in (staged / 'flyPlateBuffsFixed.toc').read_text().splitlines():
                    line = line.strip()
                    if line and not line.startswith('#'):
                        visit(staged / line.replace('[Family]', family))
                other = 'Mainline' if family == 'Classic' else 'Classic'
                self.assertFalse(any(p.startswith(f'runtime/{other}/') for p in loaded))
                self.assertIn(f'runtime/{family}/nameplates.lua', loaded)
                self.assertLess(loaded.index(f'runtime/{family}/nameplates.lua'), loaded.index('core/settings.lua'))
                self.assertLess(loaded.index('options/controller.lua'), loaded.index('interface/preview.lua'))
                self.assertLess(loaded.index('interface/preview-nameplate.lua'), loaded.index('interface/preview-scene.lua'))
                self.assertEqual(loaded[-1], 'flyPlateBuffsFixed.lua')

    def test_deploy_and_package_match(self):
        toc = (ROOT / 'flyPlateBuffsFixed.toc').read_bytes()
        with tempfile.TemporaryDirectory(prefix='fpb-distribution-test-') as temporary:
            folder = Path(temporary)
            addons = folder / 'Interface/AddOns'
            addons.mkdir(parents=True)
            output = folder / 'test.zip'
            command = [sys.executable, '-B', str(ROOT / 'scripts/distribution.py')]
            subprocess.run(command + ['--deploy', str(addons)], check=True, capture_output=True)
            subprocess.run(command + ['--package', str(output)], check=True, capture_output=True)
            installed = addons / distribution.ADDON
            deployed = {p.relative_to(addons).as_posix(): p.read_bytes()
                        for p in installed.rglob('*') if p.is_file()}
            with zipfile.ZipFile(output) as archive:
                packaged = {name: archive.read(name) for name in archive.namelist()}
            self.assertEqual(packaged, deployed)
            original_zip = output.read_bytes()
            result = subprocess.run(command + ['--package', str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_bytes(), original_zip)
        self.assertEqual((ROOT / 'flyPlateBuffsFixed.toc').read_bytes(), toc)


if __name__ == '__main__':
    unittest.main()
