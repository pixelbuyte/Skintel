"""Build preview.html from the Swift package's MascotRig.json.

The preview draws the same rig with the same pose formulas as
ios/Packages/SkinstelMascot/Sources/SkinstelMascot/MascotPose.swift, so it is the
place to try edits to the JSON without Xcode. Run: python3 build_preview.py
"""
import json
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parents[1]
rig = json.loads((root / 'ios/Packages/SkinstelMascot/Sources/SkinstelMascot/Resources/MascotRig.json').read_text())
template = (here / 'preview.template.html').read_text()
(here / 'preview.html').write_text(template.replace('__RIG__', json.dumps(rig, separators=(',', ':'))))
print('wrote', here / 'preview.html')
