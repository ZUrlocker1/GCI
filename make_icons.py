#!/usr/bin/env python3
"""
Generate 3 GCI app icon options as .icns files.

Option A – "The King"    : Cyan king, glowing, star field
Option B – "Invasion"    : Magenta fleet vs cyan ship, laser beam
Option C – "The Knight"  : Moody dark board, white knight + magenta glow
"""

from PIL import Image, ImageFilter, ImageDraw, ImageChops, ImageEnhance
import os, subprocess, random

SPRITES = "GalacticChessInvaders/Resources/Sprites"
OUT     = "icon_options"
SZ      = 1024

CYAN    = (18,  224, 255)
MAGENTA = (255,  32,  96)
ORANGE  = (255, 186,  30)
WHITE   = (255, 255, 255)
BLACK   = (0,   0,   0)

os.makedirs(OUT, exist_ok=True)
random.seed(42)

# ── helpers ──────────────────────────────────────────────────────────────────

def new_black():
    return Image.new("RGBA", (SZ, SZ), (0, 0, 0, 255))

def load(name, height):
    img = Image.open(f"{SPRITES}/{name}").convert("RGBA")
    w, h = img.size
    nw   = round(w / h * height)
    return img.resize((nw, height), Image.LANCZOS)

def stars(img, count=90, seed=42):
    rng  = random.Random(seed)
    draw = ImageDraw.Draw(img)
    cols = [(255, 255, 255), (255, 255, 255), (18, 224, 255), (255, 32, 96)]
    for _ in range(count):
        x  = rng.randint(0, SZ)
        y  = rng.randint(0, SZ)
        r  = rng.choice([1, 1, 1, 2, 2, 3])
        a  = rng.randint(80, 220)
        c  = rng.choice(cols)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(*c, a))
    return img

def glow(sprite, color, radius=55, strength=2.2):
    """Blurred colored halo from the sprite's alpha."""
    _, _, _, a = sprite.split()
    g = Image.merge("RGBA", [
        Image.new("L", sprite.size, color[0]),
        Image.new("L", sprite.size, color[1]),
        Image.new("L", sprite.size, color[2]),
        a,
    ])
    g = g.filter(ImageFilter.GaussianBlur(radius))
    g = ImageEnhance.Brightness(g).enhance(strength)
    return g

def tint(sprite, color, opacity=0.35):
    """Overlay a flat color tint on a sprite (preserves luminosity)."""
    r, g, b, a = sprite.split()
    overlay = Image.new("RGBA", sprite.size, (*color, round(255 * opacity)))
    result  = Image.composite(overlay, sprite, overlay)
    result.putalpha(a)
    return result

def paste(base, layer, cx, cy):
    """Paste layer centered at (cx, cy)."""
    x = cx - layer.width  // 2
    y = cy - layer.height // 2
    base.paste(layer, (x, y), layer)

def border_ring(img, color, thickness=8, inset=0):
    draw = ImageDraw.Draw(img)
    t = inset
    draw.rectangle([t, t, SZ - 1 - t, SZ - 1 - t],
                   outline=(*color, 180), width=thickness)

def vignette(img, strength=0.55):
    mask = Image.new("L", (SZ, SZ), 0)
    draw = ImageDraw.Draw(mask)
    steps = 120
    for i in range(steps):
        alpha = int(255 * strength * (i / steps) ** 2)
        draw.rectangle([i, i, SZ - 1 - i, SZ - 1 - i],
                       outline=255 - alpha, width=1)
    dark = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    draw2 = ImageDraw.Draw(dark)
    for i in range(steps):
        alpha = int(200 * strength * ((steps - i) / steps) ** 2)
        draw2.rectangle([i, i, SZ - 1 - i, SZ - 1 - i],
                        outline=(0, 0, 0, alpha), width=1)
    img.paste(dark, (0, 0), dark)
    return img

def save_icns(img, name):
    base = f"{OUT}/{name}"
    iconset = f"{base}.iconset"
    os.makedirs(iconset, exist_ok=True)
    for s in [16, 32, 64, 128, 256, 512, 1024]:
        resized = img.resize((s, s), Image.LANCZOS)
        resized.save(f"{iconset}/icon_{s}x{s}.png")
        if s <= 512:
            img.resize((s * 2, s * 2), Image.LANCZOS).save(
                f"{iconset}/icon_{s}x{s}@2x.png")
    img.save(f"{base}_preview.png")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", f"{base}.icns"],
                   check=True)
    print(f"✓  {base}.icns")

# ── Option A – "The King" ────────────────────────────────────────────────────
# Lone white king, cyan halo, star field, cyan border ring

img = new_black()
stars(img, count=110)

king = load("chess-w-king.png", 640)
g    = glow(king, CYAN, radius=70, strength=3.5)

paste(img, g,    SZ // 2, SZ // 2 + 30)   # glow slightly below center
paste(img, king, SZ // 2, SZ // 2 + 20)   # piece above glow centroid

border_ring(img, CYAN, thickness=10)
vignette(img, 0.45)

save_icns(img, "option-a-king")

# ── Option B – "Invasion" ────────────────────────────────────────────────────
# Magenta fleet of 8 pawns across the top, cyan player ship at bottom,
# white laser beam connecting them

img = new_black()
stars(img, count=70, seed=77)

# Fleet: 8 black pawns, magenta tint
pawn   = load("chess-b-pawn.png", 130)
pawn_t = tint(pawn, MAGENTA, opacity=0.55)
gp     = glow(pawn_t, MAGENTA, radius=30, strength=2.5)

fleet_y = 210
n_pawns = 8
spacing = SZ // (n_pawns + 1)
for i in range(n_pawns):
    px = spacing * (i + 1)
    paste(img, gp,     px, fleet_y)
    paste(img, pawn_t, px, fleet_y)

# Player ship, cyan
ship   = load("ship-player.png", 180)
ship_t = tint(ship, CYAN, opacity=0.45)
gs     = glow(ship_t, CYAN, radius=50, strength=2.8)
ship_y = SZ - 230
paste(img, gs,     SZ // 2, ship_y)
paste(img, ship_t, SZ // 2, ship_y)

# Laser beam — thin vertical line from ship to fleet
draw = ImageDraw.Draw(img)
beam_x = SZ // 2
beam_top    = fleet_y + 65    # just below pawn bases
beam_bottom = ship_y  - 90   # just above ship top
for w_offset, alpha, width in [(0, 255, 3), (0, 140, 8), (0, 60, 18)]:
    draw.line([(beam_x + w_offset, beam_bottom),
               (beam_x + w_offset, beam_top)],
              fill=(255, 255, 255, alpha), width=width)

# Magenta line at top, cyan line at bottom of beam (to reinforce teams)
draw.line([(beam_x, beam_top - 4), (beam_x, beam_top + 4)],
          fill=(*MAGENTA, 200), width=5)
draw.line([(beam_x, beam_bottom - 4), (beam_x, beam_bottom + 4)],
          fill=(*CYAN, 200), width=5)

border_ring(img, MAGENTA, thickness=10)
vignette(img, 0.5)
save_icns(img, "option-b-invasion")

# ── Option C – "The Knight" ──────────────────────────────────────────────────
# Dark chess board grid, large white knight off-center, magenta glow + orange accent

img = new_black()

# Subtle checkerboard background
draw = ImageDraw.Draw(img)
cell = SZ // 8
for row in range(8):
    for col in range(8):
        if (row + col) % 2 == 0:
            x0, y0 = col * cell, row * cell
            draw.rectangle([x0, y0, x0 + cell, y0 + cell],
                           fill=(18, 18, 28, 255))   # very dark blue-black

stars(img, count=60, seed=13)

knight = load("chess-w-knight.png", 700)

# Magenta glow
gm = glow(knight, MAGENTA, radius=75, strength=3.0)
# Second softer cyan outer glow
gc = glow(knight, CYAN,    radius=120, strength=1.2)

cx = SZ // 2 + 20
cy = SZ // 2 + 40

paste(img, gc,     cx, cy)
paste(img, gm,     cx, cy)
paste(img, knight, cx, cy)

# Thin orange accent line at bottom (retro stripe)
draw.rectangle([0, SZ - 18, SZ, SZ], fill=(*ORANGE, 200))
draw.rectangle([0, SZ - 18, SZ, SZ - 16], fill=(255, 255, 255, 80))

border_ring(img, ORANGE, thickness=8)
vignette(img, 0.5)
save_icns(img, "option-c-knight")

print("\nAll icons written to icon_options/")
print("Previews: option-a-king_preview.png  option-b-invasion_preview.png  option-c-knight_preview.png")
