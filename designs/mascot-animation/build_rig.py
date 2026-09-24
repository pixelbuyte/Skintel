import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
parts=[]
def part(name, fill, d, pivot=(160,210), stroke='#482631', width=4):
 import re
 tokens=re.findall(r'[MLCQZ]|-?\d+(?:\.\d+)?',d)
 commands=[]; i=0; arity={'M':2,'L':2,'C':6,'Q':4,'Z':0}
 while i<len(tokens):
  op=tokens[i]; n=arity[op]; commands.append({'op':op,'values':list(map(float,tokens[i+1:i+1+n]))}); i+=n+1
 parts.append(dict(name=name,fill=fill,stroke=stroke,width=width,pivot=list(pivot),commands=commands))
part('leftLeg','#C86D58','M 124 312 L 126 352 Q 107 370 125 373 Q 150 379 153 359 L 157 313 Z',(140,315))
part('rightLeg','#C86D58','M 176 313 L 181 353 Q 166 377 185 380 Q 210 382 211 359 L 211 308 Z',(194,315))
part('body','#CE765F','M 205 38 C 199 14 189 25 177 37 C 139 77 74 143 65 216 C 53 291 101 330 164 332 C 242 334 282 283 265 218 C 250 164 224 114 205 38 Z')
part('shade','#B55F50','M 205 38 C 223 135 245 202 236 255 C 227 302 181 323 132 323 C 214 347 281 298 265 218 C 250 164 224 114 205 38 Z',stroke='',width=0)
part('shine','#EAA994','M 183 55 C 157 83 117 126 108 151 C 99 169 113 172 123 157 C 137 136 161 92 183 55 Z',stroke='',width=0)
part('leftEye','#482631','M 129 184 C 129 169 110 169 110 184 C 110 198 129 198 129 184 Z',(119.5,184),stroke='',width=0)
part('rightEye','#482631','M 207 188 C 207 174 188 174 188 188 C 188 202 207 202 207 188 Z',(197.5,188),stroke='',width=0)
part('cheekL','#C46553','M 116 210 C 116 195 80 195 80 210 C 80 224 116 224 116 210 Z',stroke='',width=0)
part('cheekR','#C46553','M 229 215 C 229 200 192 200 192 215 C 192 230 229 230 229 215 Z',stroke='',width=0)
part('smile','','M 139 202 Q 157 226 178 205',width=5)
part('bottle','#F2CED0','M 68 200 L 99 198 L 105 216 Q 120 220 121 235 L 127 289 Q 127 299 116 301 L 64 307 Q 54 307 53 295 L 47 239 Q 45 226 62 221 Z')
part('serum','#E4B2B7','M 53 245 Q 85 251 121 239 L 127 289 Q 127 299 116 301 L 64 307 Q 54 307 53 295 Z',stroke='',width=0)
part('glassShine','#FFF1EC','M 59 238 L 64 287 Q 65 292 69 290 L 65 238 Z',stroke='',width=0)
part('pipette','#FFF1EC','M 77 204 L 82 245 L 88 244 L 85 203 Z',width=2)
part('dropper','#BD6756','M 62 193 L 58 171 Q 54 158 65 156 Q 77 153 80 168 L 85 190 Z')
part('cap','#CA7560','M 52 194 L 100 187 L 108 211 L 60 218 Z')
part('labelDrop','#E6BD59','M 88 252 C 87 264 76 268 80 279 C 84 292 101 285 99 275 Q 98 265 88 252 Z',width=2)
part('labelShine','#FFF4D0','M 88 264 Q 84 276 88 279 Q 93 279 88 264 Z',stroke='',width=0)
part('leftHand','#CE765F','M 61 245 C 47 235 36 250 43 266 Q 48 278 58 270 Q 70 263 62 257 Q 72 249 61 245 Z')
part('rightArm','#CE765F','M 224 260 C 198 284 153 290 121 276 Q 110 273 108 282 Q 94 280 99 294 C 117 317 188 315 225 289',(224,260))
path=root/'ios/Packages/SkinstelMascot/Sources/SkinstelMascot/Resources'
path.mkdir(parents=True,exist_ok=True)
(path/'MascotRig.json').write_text(json.dumps(parts,indent=2)+'\n')
