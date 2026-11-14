#!/usr/bin/env python3
"""Run after Godot Web export: publish music separately and refresh loader sizes."""
from pathlib import Path
import json
import re
import shutil

root = Path(__file__).resolve().parents[1]
web = root / 'build/web'
html = web / 'index.html'
if not html.is_file():
    raise SystemExit('Export the Web preset before preparing the build.')
(web / '.gdignore').touch()
(web / 'music').mkdir(exist_ok=True)
for source in (root / 'assets/audio').iterdir():
    if source.suffix == '.ogg' or source.name == 'CREDITS.txt':
        shutil.copy2(source, web / 'music' / source.name)
sizes = {p.name: p.stat().st_size for p in web.iterdir() if p.suffix in ['.pck', '.wasm']}
html.write_text(re.sub(r'"fileSizes":\{[^}]*\}', '"fileSizes":' + json.dumps(sizes, separators=(',', ':')), html.read_text()))
print('Web ready, including three external music tracks.')
