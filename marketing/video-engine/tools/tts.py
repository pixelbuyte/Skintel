# tts.py lines.json outdir  -> writes <id>.wav per line, prints JSON {id: seconds}
import json, sys, os
import soundfile as sf
from kokoro_onnx import Kokoro
d = os.path.dirname(os.path.abspath(__file__))
k = Kokoro(os.path.join(d, 'kokoro-v1.0.onnx'), os.path.join(d, 'voices-v1.0.bin'))
lines = json.load(open(sys.argv[1])); out = sys.argv[2]; os.makedirs(out, exist_ok=True); durs = {}
for L in lines:
    samples, sr = k.create(L['text'], voice=L.get('voice', 'af_heart'), speed=L.get('speed', 1.0), lang='en-us')
    sf.write(os.path.join(out, L['id'] + '.wav'), samples, sr); durs[L['id']] = round(len(samples) / sr, 3)
print(json.dumps(durs))
