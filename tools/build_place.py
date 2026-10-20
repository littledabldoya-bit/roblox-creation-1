#!/usr/bin/env python3
"""Rebuild the place while preserving geometry and applying explicit lighting material overrides."""
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

ACCENT_NAMES = {'FN_SpawnGlow', 'FN_PavementLight', 'FN_CoverGlow'}

def soften_visuals(xml):
    def properties(match):
        text = match.group(2)
        props = ET.fromstring('<Properties>' + text + '</Properties>')
        name = props.find("string[@name='Name']")
        material = props.find("token[@name='Material']")
        if name is None or material is None:
            return match.group()
        if material.text == '288' and name.text not in ACCENT_NAMES:
            text = text.replace('<token name="Material">288</token>', '<token name="Material">272</token>')
        if name.text in ACCENT_NAMES:
            color = '<Color3 name="Color"><R>' + str(48/255) + '</R><G>' + str(145/255) + '</G><B>' + str(175/255) + '</B></Color3>'
            text = re.sub(r'<Color3 name="Color">.*?</Color3>', lambda _: color, text, count=1, flags=re.S)
        return match.group(1) + text + match.group(3)
    return re.sub(r'(<Item class="(?:Part|SpawnLocation)"[^>]*>\s*<Properties>)(.*?)(</Properties>)', properties, xml, flags=re.S)

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
    result = soften_visuals(result)
    ET.fromstring(result)
    output = ROOT / 'FartNight.rbxlx'
    output.write_text(result)
    print(f'Built {output.name}: {len(seen)+1} scripts')
    return output

if __name__ == '__main__':
    build()
