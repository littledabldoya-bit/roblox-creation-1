#!/usr/bin/env python3
"""Build and run the complete offline release checks, preserving failure status."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
commands = [
    [sys.executable, 'tools/build_place.py'],
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py'],
    ['/workspace/roblox-tools/luau/build/luau', 'tests/economy.luau'],
    *[[sys.executable, f'tests/run_{suite}_tests.py'] for suite in
      ['server', 'catalog', 'audio', 'combat', 'integration']],
    [sys.executable, '/workspace/roblox-tools/check_place.py', 'fartnightv6.rbxlx'],
]
for command in commands:
    print('\nRunning ' + ' '.join(command), flush=True)
    subprocess.run(command, cwd=root, check=True)
print('\nAll offline release checks passed. Roblox engine/private playtesting remains required.')
