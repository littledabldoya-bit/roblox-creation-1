#!/usr/bin/env python3
"""Rebuild the place while preserving every original non-script XML byte."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = {
    'FN_Config': 'ReplicatedStorage',
    'FN_Server': 'ServerScriptService',
    'FN_WorldDetail': 'ServerScriptService',
    'FN_Client': 'StarterPlayerScripts',
    'FN_ShoulderAim_v2': 'StarterPlayerScripts',
}

def cdata(text):
    return '<![CDATA[' + text.replace(']]>', ']]]]><![CDATA[>') + ']]>'

def build():
    template = (ROOT / 'assets/FartNight.original.rbxlx').read_text()
    seen = set()
    def replace(match):
        chunk = match.group()
        item = ET.fromstring(chunk)
        name = item.find("./Properties/string[@name='Name']").text
        if name not in SCRIPTS or name in seen:
            raise ValueError(f'Unexpected or duplicate embedded script: {name}')
        seen.add(name)
        source = (ROOT / 'src' / SCRIPTS[name] / f'{name}.luau').read_text()
        return re.sub(r'<ProtectedString name="Source">.*?</ProtectedString>',
                      lambda _: '<ProtectedString name="Source">' + cdata(source) + '</ProtectedString>',
                      chunk, count=1, flags=re.S)
    result = re.sub(r'<Item class="(?:ModuleScript|LocalScript|Script)"[^>]*>.*?</Item>',
                    replace, template, flags=re.S)
    if seen != set(SCRIPTS):
        raise ValueError(f'Missing original scripts: {set(SCRIPTS)-seen}')
    # Add a pure, independently testable economy module beside FN_Config.
    economy = (ROOT / 'src/ReplicatedStorage/FN_Economy.luau').read_text()
    config_start = result.index('<Item class="ModuleScript"')
    module = ('<Item class="ModuleScript" referent="FN_Economy_Module">'
              '<Properties><string name="Name">FN_Economy</string>'
              '<ProtectedString name="Source">' + cdata(economy) +
              '</ProtectedString></Properties></Item>')
    result = result[:config_start] + module + result[config_start:]
    ET.fromstring(result)
    output = ROOT / 'FartNight.rbxlx'
    output.write_text(result)
    print(f'Built {output.name}: {len(seen)+1} scripts')
    return output

if __name__ == '__main__':
    build()
