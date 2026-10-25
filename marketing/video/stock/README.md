# Real-footage hook videos

The Fastlane / Cal AI look (a real hand holding a phone, the app doing its thing) without filming
and without fake people:

1. **Hook, 2.2 s:** the hook line in TikTok Sans over faceless stock B-roll (serum dripping, a cream
   jar, a shelf with its labels blurred).
2. **Demo:** a stock clip of a real hand holding a phone with a blank white or green screen. The
   live Skintel UI (`f-*.html?mode=screen`) is tracked onto the screen frame by frame
   (`track.py`, `composite.py`): the screen area is found again on every frame, the app is warped
   into its corners, and the area itself is the mask, so the notch, rounded corners and fingers
   stay real and the glass keeps its own shading.
3. **End card:** Comment SKINSTEL.

```bash
pip install opencv-python-headless numpy
CHROME_PATH=... python3 stock/build_stock.py            # → out/stock-*.mp4
CHROME_PATH=... python3 stock/build_stock.py stock-02   # one video
```

## Clips

`clips.json` lists every clip with its source page and licence. They download into `cache/`
(gitignored) on first use.

Rules for adding a clip:

- **Faceless.** Pexels and Mixkit both forbid using a recognisable person in a way that implies
  they endorse the product; a stock face reacting to Skintel would do exactly that.
- **No readable brands.** Add `"blur": 7` (or more) for clips with legible labels.
- **Phone clips** need a flat white or green screen held fairly still; mark `"screen": "green"` for
  green ones. Search Pexels for "hand holding phone white screen" / "green screen phone vertical".

Finding clips: Pexels search pages block scripts, but web search with `site:pexels.com` finds clip
pages, and `https://www.pexels.com/download/video/<id>/` downloads them. Mixkit search pages
(`mixkit.co/free-stock-video/<topic>/`) list clip ids, and
`assets.mixkit.co/videos/<id>/<id>-720.mp4` downloads them (720p only).

## Adding a video

Add a line to `VIDEOS` in `build_stock.py`: hook number (from `hook.html`), B-roll clip and its
start second, phone clip and crop-in zoom, demo. Check frames before sending.
