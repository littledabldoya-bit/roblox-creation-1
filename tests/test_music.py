import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

class MusicTests(unittest.TestCase):
    def test_soundtrack_duration_stereo_size_and_complete_decoding(self):
        path = ROOT / 'assets/music/NeonCircuit.mp3'
        metadata = json.loads(subprocess.check_output([
            'ffprobe', '-v', 'error', '-show_entries', 'format=duration,size:stream=channels',
            '-of', 'json', str(path)], text=True))
        self.assertGreater(float(metadata['format']['duration']), 200)
        self.assertLess(float(metadata['format']['duration']), 210)
        self.assertEqual(metadata['streams'][0]['channels'], 2)
        self.assertLess(int(metadata['format']['size']), 20_000_000)
        subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(path), '-f', 'null', '-'], check=True)

if __name__ == '__main__':
    unittest.main()
