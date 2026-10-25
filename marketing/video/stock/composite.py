"""Map a rendered app screen onto the blank phone in a stock hand-held clip.

    python3 composite.py STOCK.mp4 SCREEN.mp4 OUT.mp4 --start 0.8 --end 13.0 [--green] [--zoom 1.3]

STOCK is a vertical clip of a hand holding a phone with a white (or green) screen. SCREEN is
f-*.html rendered with ?mode=screen (886×1918). For every output frame the screen region is found
again (track.py), the app frame is warped into its four corners, and the region itself is the mask,
so the notch, rounded corners and any finger over the glass stay real. The stock clip ping-pongs if
it is shorter than the demo; the screen's own shading is kept so it reads as glass, not a sticker.
"""
import argparse, subprocess, sys
import cv2, numpy as np
from track import screen_mask, corners

W, H, FPS = 1080, 1920, 30

def load_stock(path, zoom=1.0, green=False):
    """Frames as JPEG bytes at 1080×1920. zoom > 1 crops in on the phone from the full-resolution
    source (4K clips stay sharp), centred where the screen sits in the first frame."""
    cap = cv2.VideoCapture(path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    frames, centre = [], None
    while True:
        ok, f = cap.read()
        if not ok: break
        h, w = f.shape[:2]
        if w > h:  # landscape: centre crop to 9:16
            cw = int(h * 9 / 16); x = (w - cw) // 2; f = f[:, x:x + cw]; h, w = f.shape[:2]
        if centre is None:
            m = screen_mask(cv2.resize(f, (W, H)), green)
            ys, xs = np.nonzero(m) if m is not None else ([H / 2], [W / 2])
            centre = (float(np.mean(xs)) / W, float(np.mean(ys)) / H)
        if zoom > 1:
            cw, ch = int(w / zoom), int(h / zoom)
            x = int(np.clip(centre[0] * w - cw / 2, 0, w - cw)); y = int(np.clip(centre[1] * h - ch / 2, 0, h - ch))
            f = f[y:y + ch, x:x + cw]
        frames.append(cv2.imencode('.jpg', cv2.resize(f, (W, H), interpolation=cv2.INTER_AREA), [cv2.IMWRITE_JPEG_QUALITY, 94])[1])
    return frames, fps

def smooth(qs, a=0.45):
    """Zero-lag smoothing: exponential forwards then backwards."""
    out = qs.copy()
    for i in range(1, len(out)): out[i] = a * out[i] + (1 - a) * out[i - 1]
    for i in range(len(out) - 2, -1, -1): out[i] = a * out[i] + (1 - a) * out[i + 1]
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stock'); ap.add_argument('screen'); ap.add_argument('out')
    ap.add_argument('--start', type=float, default=0.0); ap.add_argument('--end', type=float, required=True)
    ap.add_argument('--green', action='store_true'); ap.add_argument('--speed', type=float, default=0.9)
    ap.add_argument('--zoom', type=float, default=1.0)
    a = ap.parse_args()

    frames, sfps = load_stock(a.stock, a.zoom, a.green)
    masks, quads = [], []
    for buf in frames:
        m = screen_mask(cv2.imdecode(buf, cv2.IMREAD_COLOR), a.green)
        masks.append(m); quads.append(corners(m) if m is not None else None)
    good = [q for q in quads if q is not None]
    if not good: sys.exit('no screen found in ' + a.stock)
    quads = smooth(np.array([q if q is not None else good[0] for q in quads], np.float32))
    stock_len = len(frames) / sfps

    scr = cv2.VideoCapture(a.screen)
    scr.set(cv2.CAP_PROP_POS_FRAMES, int(round(a.start * FPS)))
    sw, sh = int(scr.get(cv2.CAP_PROP_FRAME_WIDTH)), int(scr.get(cv2.CAP_PROP_FRAME_HEIGHT))
    src = np.array([[0, 0], [sw, 0], [sw, sh], [0, sh]], np.float32)

    enc = subprocess.Popen(['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                            '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', a.out],
                           stdin=subprocess.PIPE)
    n = int(round((a.end - a.start) * FPS))
    for i in range(n):
        ok, app = scr.read()
        if not ok: break
        u = (i / FPS * a.speed) % (2 * stock_len)            # ping-pong through the stock clip
        ts = u if u < stock_len else 2 * stock_len - u
        k = min(len(frames) - 1, int(round(ts * sfps)))
        bg = cv2.imdecode(frames[k], cv2.IMREAD_COLOR)
        m = masks[k]
        warped = cv2.warpPerspective(app, cv2.getPerspectiveTransform(src, quads[k]), (W, H), flags=cv2.INTER_LINEAR)
        alpha = cv2.GaussianBlur(cv2.dilate(m, np.ones((3, 3), np.uint8)), (5, 5), 0).astype(np.float32)[..., None] / 255
        # Keep the glass: the blank screen's own light falloff and reflections tint the app slightly.
        v = cv2.cvtColor(bg, cv2.COLOR_BGR2HSV)[..., 2].astype(np.float32)
        ref = np.percentile(v[m > 0], 95) if a.green is False else 255.0
        shade = np.clip((v / max(ref, 1)) ** 0.5, 0.82, 1.03)[..., None] if not a.green else 1.0
        comp = bg * (1 - alpha) + np.clip(warped * shade, 0, 255) * alpha
        enc.stdin.write(comp.astype(np.uint8).tobytes())
    enc.stdin.close(); enc.wait()
    print('→', a.out)

if __name__ == '__main__':
    main()
