"""Validate the updater's external-data boundary without downloading anything."""

import copy
import importlib.util
import json
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/update-spell-ranks.py"
SPEC = importlib.util.spec_from_file_location("spell_ranks", SCRIPT)
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


def source():
    return {
        "license": "CC-BY-4.0",
        "generated": "2026-10-03",
        "spell_desc": {
            "Priest|Shadow Word: Pain|Rank 3": {"s": "beta", "id": 970},
            "Priest|Shadow Word: Pain|Rank 1": {"s": "beta", "id": 589},
            "Priest|Shadow Word: Pain|Rank 2": {"s": "beta", "id": 594},
            "Mage|Polymorph: Pig|Rank 1": {"s": "beta", "id": 28272},
            "Mage|Polymorph|Rank 1": {"s": "beta", "id": 118},
            "Mage|Polymorph|Rank 2": {"s": "beta", "id": 12824},
            "Mage|Ignored|Rank 1": {"s": "classic", "id": 1},
            "Mage|Ignored|Rank 2": {"s": "classic", "id": 2},
            "Mage|Unranked|Passive": {"s": "beta", "id": 3},
        },
    }


class RankGeneratorTests(unittest.TestCase):
    def test_groups_ordered_ranks_and_keeps_variants_separate(self):
        self.assertEqual(
            GENERATOR.collect_families(source()),
            [(('Mage', 'Polymorph'), [118, 12824]), (('Priest', 'Shadow Word: Pain'), [589, 594, 970])],
        )

    def test_same_name_in_another_class_is_separate(self):
        data = source()
        data['spell_desc']['Warrior|Polymorph|Rank 1'] = {'s': 'beta', 'id': 10}
        data['spell_desc']['Warrior|Polymorph|Rank 2'] = {'s': 'beta', 'id': 11}
        self.assertEqual(GENERATOR.collect_families(data)[-1], (('Warrior', 'Polymorph'), [10, 11]))

    def test_rejects_conflicting_ids(self):
        data = source()
        data['spell_desc']['Mage|Polymorph|Rank 2']['id'] = 589
        with self.assertRaisesRegex(ValueError, 'belongs to both'):
            GENERATOR.collect_families(data)

    def test_rejects_incomplete_families(self):
        data = source()
        del data['spell_desc']['Priest|Shadow Word: Pain|Rank 2']
        with self.assertRaisesRegex(ValueError, 'Missing ranks'):
            GENERATOR.collect_families(data)

    def test_rejects_malformed_ids(self):
        for value in [None, True, -1, 0, 1.5, '589', 2147483647]:
            with self.subTest(value=value):
                data = source()
                data['spell_desc']['Priest|Shadow Word: Pain|Rank 1']['id'] = value
                with self.assertRaisesRegex(ValueError, 'Invalid spell ID'):
                    GENERATOR.collect_families(data)

    def test_rejects_changed_license_and_comment_injection(self):
        data = source()
        data['license'] = 'unknown'
        with self.assertRaisesRegex(ValueError, 'license changed'):
            GENERATOR.collect_families(data)
        data = source()
        data['spell_desc']['Mage|Name\nmalformed|Rank 1'] = {'s': 'beta', 'id': 42}
        with self.assertRaisesRegex(ValueError, 'Unexpected spell key'):
            GENERATOR.collect_families(data)

    def test_rejects_empty_or_changed_schema(self):
        data = source()
        data['spell_desc'] = {}
        with self.assertRaisesRegex(ValueError, 'no beta rank families'):
            GENERATOR.collect_families(data)
        del data['spell_desc']
        with self.assertRaises(KeyError):
            GENERATOR.collect_families(data)

    def test_deterministic_output_with_provenance(self):
        raw = json.dumps(source()).encode()
        original = copy.deepcopy(source())
        first = GENERATOR.render(raw)
        self.assertEqual(first, GENERATOR.render(raw))
        self.assertEqual(first[1:], (2, 5))
        self.assertIn('Source SHA-256:', first[0])
        self.assertIn('CC BY 4.0', first[0])
        self.assertIn('{ 589, 594, 970, name = "Shadow Word: Pain" }', first[0])
        self.assertEqual(source(), original)

    def test_escapes_names_for_lua_strings(self):
        data = source()
        name = 'Quoted "spell" \\ path'
        data['spell_desc'][f'Mage|{name}|Rank 1'] = {'s': 'beta', 'id': 10}
        data['spell_desc'][f'Mage|{name}|Rank 2'] = {'s': 'beta', 'id': 11}
        output = GENERATOR.render(json.dumps(data).encode())[0]
        self.assertIn(r'name = "Quoted \"spell\" \\ path"', output)

    def test_rejects_control_characters_in_names(self):
        for character in ['\t', '\b', '\f', '\0']:
            with self.subTest(character=character):
                data = source()
                data['spell_desc'][f'Mage|Name{character}invalid|Rank 1'] = {'s': 'beta', 'id': 10}
                with self.assertRaisesRegex(ValueError, 'Unexpected spell key'):
                    GENERATOR.collect_families(data)


if __name__ == '__main__':
    unittest.main()
