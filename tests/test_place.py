import collections
import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_place', ROOT / 'tools/build_place.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

def canonical(node):
    if node.tag == 'ProtectedString' and node.get('name') == 'Source':
        return ('script-source',)
    if node.tag == 'Item' and node.get('referent') == 'FN_Economy_Module':
        return None
    children = [canonical(child) for child in node]
    return (node.tag, tuple(sorted(node.attrib.items())), (node.text or '').strip(),
            tuple(child for child in children if child is not None))

class PlaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output = builder.build()
        cls.current = ET.parse(cls.output).getroot()
        cls.original = ET.parse(ROOT / 'assets/FartNight.original.rbxlx').getroot()

    def test_arena_and_original_non_script_properties_are_preserved(self):
        expected = ET.fromstring(builder.soften_visuals(ET.tostring(self.original, encoding="unicode")))
        self.assertEqual(canonical(expected), canonical(self.current))

    def test_only_thin_accent_parts_retain_neon_material(self):
        retained = 0
        for item in self.current.iter('Item'):
            if item.get('class') not in {'Part', 'SpawnLocation'}:
                continue
            material = item.find("./Properties/token[@name='Material']")
            if material is not None and material.text == '288':
                name = item.find("./Properties/string[@name='Name']").text
                self.assertIn(name, builder.ACCENT_NAMES)
                retained += 1
        self.assertGreater(retained, 0)
        self.assertLess(retained, 100)

    def test_every_embedded_source_matches_editable_source(self):
        items = {node.find("./Properties/string[@name='Name']").text: node
                 for node in self.current.iter('Item')
                 if node.get('class') in {'Script', 'LocalScript', 'ModuleScript'}}
        self.assertEqual(len(items), 6)
        for name, directory in {**builder.SCRIPTS, 'FN_Economy': 'ReplicatedStorage'}.items():
            expected = (ROOT / 'src' / directory / f'{name}.luau').read_text()
            self.assertEqual(items[name].find("./Properties/ProtectedString[@name='Source']").text, expected)

    def test_new_module_is_in_replicated_storage(self):
        storage = next(item for item in self.current.findall('Item') if item.get('class') == 'ReplicatedStorage')
        self.assertEqual(sum(item.get('referent') == 'FN_Economy_Module' for item in storage.findall('Item')), 1)

    def test_unique_referents_and_original_instance_counts(self):
        ids = [item.get('referent') for item in self.current.iter('Item')]
        self.assertEqual(len(ids), len(set(ids)))
        original = collections.Counter(item.get('class') for item in self.original.iter('Item'))
        current = collections.Counter(item.get('class') for item in self.current.iter('Item'))
        original['ModuleScript'] += 1
        self.assertEqual(original, current)

    def test_repeat_build_produces_identical_place(self):
        first = self.output.read_bytes()
        builder.build()
        self.assertEqual(first, self.output.read_bytes())

if __name__ == '__main__':
    unittest.main()
