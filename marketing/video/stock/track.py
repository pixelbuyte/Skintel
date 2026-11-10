"""Find the blank phone screen in a stock hand-held clip, frame by frame.

The screen is the largest bright, colourless region; its four corners are the extreme points of
that region (top-left = min x+y, etc.), smoothed over time so the overlay doesn't jitter. The region
itself doubles as the mask, so the notch, rounded corners and any finger over the edge stay real.
"""
import cv2, numpy as np

def screen_mask(frame_bgr, green=False):
    hsv = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2HSV)
    if green:   # chroma green screen
        m = cv2.inRange(hsv, (40, 80, 60), (85, 255, 255))
    else:       # blank white screen
        m = cv2.inRange(hsv, (0, 0, 170), (180, 45, 255))
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m)
    if n < 2: return None
    i = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return (lab == i).astype(np.uint8) * 255

def corners(mask):
    ys, xs = np.nonzero(mask)
    pts = np.stack([xs, ys], 1).astype(np.float32)
    s, d = pts.sum(1), pts[:, 0] - pts[:, 1]
    tl, br = pts[np.argmin(s)], pts[np.argmax(s)]
    tr, bl = pts[np.argmax(d)], pts[np.argmin(d)]
    q = np.array([tl, tr, br, bl], np.float32)
    # Rounded corners pull the extreme points inwards; push them back out a little.
    c = q.mean(0)
    return c + (q - c) * 1.035
