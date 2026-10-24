# Skintel 3D bottle and barcode demonstration kit

Four self-contained glTF 2.0 models with embedded label textures and physically based materials. No live app dependencies or routes are modified.

- `ordinary-niacinamide`: The Ordinary Niacinamide 10% + Zinc 1%, 30 mL reference approximation.
- `cerave-cleanser`: CeraVe Hydrating Facial Cleanser, 12 fl oz reference approximation.
- `skintel-jade`: original jade dropper, fictional Skintel serum.
- `skintel-terracotta`: original terracotta pump, fictional Skintel cleanser.

## Other agents: start here

Models are in `models/*.gltf`. They import into Blender, Three.js GLTFLoader, React Three Fiber and video pipelines that accept glTF. Coordinates are Y-up, dimensions in meters, origin on the bottle base. Front faces +Z. Mesh names identify body, closure, ribs, bulb/pump and label. Labels and materials are editable. Generator builds both glTF and GLB; GLB files can be recreated locally.

Run `python3 -m http.server 8080` from this directory, then open http://localhost:8080. Drag to orbit, switch models, rotate and run the barcode animation. Preview fetches pinned Three.js 0.180.0 from jsDelivr, so it requires internet. The model files themselves are self-contained and work offline.

## Barcode behavior

Every model carries a real Code 128 encoding of `SKINTEL-DEMO-01` through `04`, on its reverse label. These are explicitly demo identifiers, not UPC/EAN/retail codes. `manifest.json` provides the fixture mapping. The viewer animates a scan and shows a deterministic fixture result. It does NOT decode camera frames or change Skintel's actual scanner. For a real integration, feed decoded text into the manifest fixture map in development only, and keep production barcode lookup unchanged.

## Accuracy and references

These are recognizable reference-based models, NOT certified 1:1 replicas. Dimensions, pump geometry, reverse text and label typography are approximations. Do not present them as brand-supplied assets or endorsement. Exact replication requires reference photos of every side, dimensions and verified regional packaging/barcodes. Brand trademarks remain with their owners. The two Skintel designs are fictional demo packaging, not actual products for sale.

Official reference pages consulted 2026-10-23:
- https://theordinary.com/en-us/niacinamide-10-zinc-1-serum-100436.html
- https://www.cerave.com/skincare/cleansers/hydrating-facial-cleanser

## Regenerate

Install `trimesh`, `numpy`, `pillow` and `python-barcode`, then run `python3 generate.py`. Generator uses DejaVu Sans at the Linux path declared in `FONT`; change that path on other systems. Geometry is procedural, with closed rounded bodies, ribbed closures, separate pumps/dropper bulbs, and wrapped label UVs. Exported assets include all textures as embedded data. Avoid relying on brand approximations for ingredient or medical information.
