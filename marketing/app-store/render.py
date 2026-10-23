#!/usr/bin/env python3
"""Render the App Store slides to out/NN-name.png at 1290x2796 (the 6.9" iPhone slot).

Usage (from the repo root):  python3 marketing/app-store/render.py

To refresh the slides, replace a capture in raw/ with a new iPhone screenshot of the same
name and run this again. Most slides are mocks in slides.html; raw/ supplies
the scanner slide and the real tab bar / composer crops laid over the mocks. Captures are cleaned first: the real status bar (time, battery,
bell) is painted out so slides.html can draw a uniform 9:41 one.
"""
import pathlib
import shutil
import subprocess
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
RAW, CLEAN, OUT = HERE / "raw", HERE / "_clean", HERE / "out"
SLIDES = ["01-verdict", "02-triggers", "03-today", "04-ask", "05-scan"]
# Real UI cropped from captures for the mock screens: (output, capture, top row as a fraction).
CROPS = [
    ("tab-today", "02-today", 2232 / 2532),
    ("tab-insights", "03-insights", 2232 / 2532),
    ("composer-ask", "01-ask", 1790 / 2532),
]
STATUS_ROWS = 0.052  # top 5.2% of an iPhone capture holds the status bar
CHROME_CANDIDATES = [
    "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    shutil.which("chromium") or "",
    shutil.which("google-chrome") or "",
]


def clean(name: str) -> None:
    im = Image.open(RAW / f"{name}.png").convert("RGB")
    w, h = im.size
    cut = int(h * STATUS_ROWS)
    # Repeat the first row under the status bar upwards; the background there is a plain gradient.
    row = im.crop((0, cut, w, cut + 1))
    for y in range(cut):
        im.paste(row, (0, y))
    im.save(CLEAN / f"{name}.png")


def main() -> None:
    chrome = next((c for c in CHROME_CANDIDATES if c and pathlib.Path(c).exists()), None)
    if not chrome:
        sys.exit("No Chromium found; set CHROME_CANDIDATES")
    CLEAN.mkdir(exist_ok=True)
    OUT.mkdir(exist_ok=True)
    for name in ["04-scan"]:
        clean(name)
    for out, capture, top in CROPS:
        im = Image.open(RAW / f"{capture}.png").convert("RGB")
        im.crop((0, int(im.height * top), im.width, im.height)).save(CLEAN / f"{out}.png")
    for old in OUT.glob("*.png"):
        old.unlink()
    for i, name in enumerate(SLIDES, 1):
        target = OUT / f"{name}.png"
        subprocess.run([
            chrome, "--headless", "--no-sandbox", "--hide-scrollbars", "--disable-gpu",
            "--allow-file-access-from-files", "--force-device-scale-factor=1",
            "--window-size=1290,2796", "--virtual-time-budget=4000",
            f"--screenshot={target}", f"file://{HERE / 'slides.html'}?n={i}",
        ], check=True, capture_output=True)
        size = Image.open(target).size
        assert size == (1290, 2796), f"{target.name} is {size}"
        print(f"{target.relative_to(HERE)}  {size[0]}x{size[1]}")
    shutil.rmtree(CLEAN)


if __name__ == "__main__":
    main()
