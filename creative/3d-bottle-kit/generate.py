"""Rebuild embedded glTF 2.0 assets. Python: trimesh==4.12.2 pillow numpy python-barcode."""
import base64, json, io, math
from pathlib import Path
import numpy as np
import trimesh as tm
from PIL import Image, ImageDraw, ImageFont
from barcode import Code128
from barcode.writer import ImageWriter
OUT=Path(__file__).parent/'models';OUT.mkdir(exist_ok=True)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(n): return ImageFont.truetype(FONT,n)
items=[('ordinary-niacinamide','The Ordinary.','Niacinamide 10%','+ Zinc 1%','#ece9df',False,'reference'),('cerave-cleanser','CeraVe','Hydrating','Facial Cleanser','#f6f7f0',True,'reference'),('skintel-jade','SKINTEL','Daily clarity','Serum','#29584b',False,'original'),('skintel-terracotta','SKINTEL','Soft reset','Cleanser','#aa6250',True,'original')]
manifest=[]
for idx,(slug,brand,line1,line2,color,pump,kind) in enumerate(items):
 scene=tm.Scene(); r=.024 if pump else .017; sy=1 if not pump else .68; h=.125 if pump else .067
 def add(mesh,name,c,rough=.3,metal=0):
  mesh.visual=tm.visual.TextureVisuals(material=tm.visual.material.PBRMaterial(name=name,baseColorFactor=c,metallicFactor=metal,roughnessFactor=rough));scene.add_geometry(mesh,node_name=name,geom_name=name)
 def cylinder(rad,height,y,name,c,rough=.3):
  m=tm.creation.cylinder(rad,height,sections=64);m.apply_transform(tm.transformations.rotation_matrix(-math.pi/2,[1,0,0]));m.apply_translation([0,y,0]);add(m,name,c,rough)
 from PIL import ImageColor
 rgba=list(ImageColor.getrgb(color))+[255]
 # Revolved closed profile: rounded heel and shoulder, actual three-dimensional geometry.
 profile=np.array([[0,0],[r*.84,0],[r*.98,.002],[r,.005],[r,h-.012],[r*.94,h-.006],[r*.63,h],[r*.55,h+.004],[0,h+.004]])
 body=tm.creation.revolve(profile,sections=96);body.apply_scale([1,sy,1]);body.apply_transform(tm.transformations.rotation_matrix(-math.pi/2,[1,0,0]));add(body,'bottle_body',rgba,.22 if kind=='original' else .34)
 capcol=[247,246,238,255] if kind=='reference' else [208,186,144,255]
 cylinder(r*.57,.014,h+.008,'closure',capcol,.22)
 for j in range(48):
  a=j*math.tau/48; m=tm.creation.cylinder(.00035,.011,sections=6);m.apply_transform(tm.transformations.rotation_matrix(-math.pi/2,[1,0,0]));m.apply_translation([r*.575*math.cos(a),h+.008,r*.575*math.sin(a)]);add(m,f'closure_rib_{j}',capcol,.4)
 if pump:
  cylinder(.004,.016,h+.022,'pump_stem',capcol)
  m=tm.creation.box([.036,.007,.012]);m.apply_translation([.009,h+.033,0]);add(m,'pump_head',capcol)
  cylinder(.0015,.002,h+.028,'nozzle_inset',[45,48,42,255])
 else:
  bulb=tm.creation.uv_sphere(radius=1,count=[24,24]);bulb.apply_scale([.008,.016,.008]);bulb.apply_translation([0,h+.025,0]);add(bulb,'rubber_bulb',[242,241,230,255],.65)
 # Full wrap texture, front at UV .25, back barcode at .75.
 tex=Image.new('RGB',(2048,1024),'#faf9f4');d=ImageDraw.Draw(tex)
 if slug=='cerave-cleanser':
  d.rectangle((0,0,1024,90),fill='#267bb6');d.rectangle((0,500,1024,710),fill='#52a940')
 if kind=='original':
  d.rectangle((0,0,1024,100),fill=color);d.text((180,22),'SKINCARE / STUDIO CONCEPT',font=font(24),fill='white')
 d.text((110,170),brand,font=font(65),fill='#1d3733' if kind=='original' else '#262a2d')
 d.line((110,280,910,280),fill='#9ba29b',width=3)
 d.text((110,360),line1,font=font(46),fill='#243e35');d.text((110,425),line2,font=font(46),fill='#243e35')
 d.text((110,750),'355 mL / 12 FL OZ' if pump and kind=='reference' else ('150 mL' if pump else '30 mL / 1 FL OZ'),font=font(27),fill='#58645b')
 code='SKINTEL-DEMO-'+str(idx+1).zfill(2)
 b=Code128(code,writer=ImageWriter()).render({'module_width':.4,'module_height':16,'font_size':0,'quiet_zone':4}).convert('RGB');b.thumbnail((840,350));tex.paste(b,(1110,300))
 d.text((1120,210),'DEMO BARCODE • NOT RETAIL',font=font(29),fill='black');d.text((1120,690),code,font=font(32),fill='black')
 # UV tube positioned above the physical surface to avoid z-fighting.
 n=192;verts=[];uv=[];faces=[]
 for j in range(n+1):
  a=j*math.tau/n
  for k,y in enumerate([h*.18,h*.76]):
   verts.append([(r+.00015)*math.cos(a),y,(r+.00015)*sy*math.sin(a)]);uv.append([j/n,k])
 for j in range(n):
  a=2*j;faces.extend([[a,a+2,a+1],[a+1,a+2,a+3]])
 label=tm.Trimesh(vertices=verts,faces=faces,process=False);label.visual=tm.visual.TextureVisuals(uv=uv,material=tm.visual.material.PBRMaterial(name='editable_label',baseColorTexture=tex,metallicFactor=0,roughnessFactor=.55,doubleSided=True));scene.add_geometry(label,node_name='label_wrap')
 payload=tm.exchange.gltf.export_gltf(scene,merge_buffers=True)
 doc=json.loads(payload['model.gltf'])
 for bfr in doc.get('buffers',[]):
  bfr['uri']='data:application/octet-stream;base64,'+base64.b64encode(payload[bfr['uri']]).decode()
 doc['asset']['extras']={'units':'meters','classification':kind,'demoBarcode':code,'accuracy':'reference approximation; dimensions and packaging are not certified 1:1'}
 (OUT/(slug+'.gltf')).write_text(json.dumps(doc,separators=(',',':')))
 # Portable binary export for local validation; repository ships equivalent self-contained glTF.
 (OUT/(slug+'.glb')).write_bytes(scene.export(file_type='glb'))
 manifest.append({'id':slug,'brand':brand,'type':kind,'model':'models/'+slug+'.gltf','barcode':code,'barcodeType':'CODE_128','retailBarcode':False})
 assert scene.bounds[1][1]>h
 print(slug,len(scene.geometry),'parts')
(Path(__file__).parent/'manifest.json').write_text(json.dumps(manifest,indent=2))
