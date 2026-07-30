#!/usr/bin/env python3
"""Generate iOS + macOS app icon assets from a single source image.

The source art draws the rounded-square icon inset inside black padding.
Each platform needs that handled differently:

  iOS   - artwork must fill the whole canvas edge to edge, fully opaque.
          The system applies the rounded mask itself, so shipping the padded
          source would render a small rounded icon floating inside a black
          square.
  macOS - icons carry their own shape and sit on TRANSPARENT padding (the
          standard grid puts the rounded square at ~824/1024 of the canvas).
          The source's black padding would show up as a black block in the
          Dock, so the corners are re-masked to alpha.
"""
from PIL import Image, ImageDraw
import sys, os

SRC = sys.argv[1]
OUT = sys.argv[2]

im = Image.open(SRC).convert("RGB")

# --- 1. Find the artwork bounds (the rounded square inside the black padding).
# Threshold well above pure black: the icon body is dark navy (~#101a2e), and
# the surrounding padding is near-black, so scan for the first row/column whose
# brightest pixel clears the threshold.
THRESHOLD = 22
w, h = im.size
px = im.load()


def row_has_art(y):
    return any(sum(px[x, y]) / 3 > THRESHOLD for x in range(0, w, 3))


def col_has_art(x):
    return any(sum(px[x, y]) / 3 > THRESHOLD for y in range(0, h, 3))


top = next(y for y in range(h) if row_has_art(y))
bottom = next(y for y in range(h - 1, -1, -1) if row_has_art(y))
left = next(x for x in range(w) if col_has_art(x))
right = next(x for x in range(w - 1, -1, -1) if col_has_art(x))

# Square it up around the centre so the art is never distorted.
cx, cy = (left + right) / 2, (top + bottom) / 2
side = max(right - left, bottom - top) + 1
half = side / 2
box = (
    max(0, int(round(cx - half))),
    max(0, int(round(cy - half))),
    min(w, int(round(cx + half))),
    min(h, int(round(cy + half))),
)
art = im.crop(box)
print(f"source {w}x{h} -> art bounds {box} ({art.size[0]}x{art.size[1]})")

# --- 2. iOS: edge-to-edge, opaque, 1024x1024.
# The source art is itself a rounded square, so its four corners are black
# background. iOS applies its own squircle mask whose boundary sits within a
# pixel of the art's curve — close enough that a dark fringe could survive
# antialiasing in the corners. Overscanning by OVERSCAN pushes the art's curve
# well outside the mask so every visible pixel is icon body, at the cost of
# trimming a few percent off the edges (the art has margin to spare).
OVERSCAN = 1.06
big = int(round(1024 * OVERSCAN))
inset = (big - 1024) // 2
ios = art.resize((big, big), Image.LANCZOS).crop(
    (inset, inset, inset + 1024, inset + 1024)
)
ios_path = os.path.join(OUT, "icon-ios-1024.png")
ios.save(ios_path)
print("wrote", ios_path, f"(overscan {OVERSCAN}x)")

# --- 3. macOS: rounded shape on transparent padding.
# Apple's grid: content ~824 of a 1024 canvas, corner radius ~0.225 * content.
CANVAS, CONTENT = 1024, 824
RADIUS = int(round(CONTENT * 0.225))
SS = 4  # supersample the mask for clean antialiased corners

body = art.resize((CONTENT, CONTENT), Image.LANCZOS).convert("RGBA")
mask = Image.new("L", (CONTENT * SS, CONTENT * SS), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    (0, 0, CONTENT * SS - 1, CONTENT * SS - 1), radius=RADIUS * SS, fill=255
)
body.putalpha(mask.resize((CONTENT, CONTENT), Image.LANCZOS))

canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
off = (CANVAS - CONTENT) // 2
canvas.paste(body, (off, off), body)

# macOS needs 16/32/128/256/512 at 1x and 2x.
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        px_size = size * scale
        out = canvas.resize((px_size, px_size), Image.LANCZOS)
        name = f"icon-mac-{size}x{size}{'@2x' if scale == 2 else ''}.png"
        out.save(os.path.join(OUT, name))
        print("wrote", name, f"({px_size}px)")
