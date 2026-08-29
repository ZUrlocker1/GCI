#!/usr/bin/env python3
"""Generate GCI app icon candidates.

Option A is what ships. To rebuild it:

    python3 tools/make_icon.py icon_options/v2
    python3 -c "from PIL import Image; \
        Image.open('icon_options/v2/a-neon-king-1024.png').convert('RGBA') \
        .save('GalacticChessInvaders/Resources/AppIcon.icns')"

Pillow writes the .icns, not iconutil, which fails on this machine even for an
iconset that already has a working .icns beside it. The entry set Pillow
produces — 16@2x, 32@2x, and 128/256/512 at 1x and 2x — is the same set the
icon it replaced contained.

icon_options/ is gitignored: this script is the source of truth, and the only
generated file the repo keeps is the .icns itself.

Everything is drawn in a 1024-unit design space at 4x supersample and reduced
with LANCZOS, because the icon this replaces was stair-stepped: it had been
traced from a low-resolution source, and the steps are plainly visible at 512.

No numpy here, so gradients are built at 256px and scaled up. A gradient has no
high-frequency detail to lose, which is exactly why that is safe.
"""

import math
import pathlib
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024          # design space
SS = 4            # supersample factor
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

CYAN = (0x12, 0xE0, 0xFF)
MAGENTA = (0xFF, 0x20, 0x60)
WHITE = (0xFF, 0xFF, 0xFF)


# ---------------------------------------------------------------- primitives

def blank(mode="L", size=None, fill=0):
    return Image.new(mode, size or (S * SS, S * SS), fill)


def px(v):
    """Design units -> supersampled pixels."""
    return v * SS


def rrect(draw, box, r, fill=255):
    draw.rounded_rectangle([px(b) for b in box], radius=px(r), fill=fill)


def circle(draw, cx, cy, r, fill=255):
    draw.ellipse([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=fill)


def bezier(p0, p1, p2, p3, steps=120):
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0]
        y = u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]
        out.append((x, y))
    return out


def mirror(pts, axis=512.0):
    return [(2 * axis - x, y) for x, y in reversed(pts)]


# ---------------------------------------------------------------- background

def radial(size, inner, outer, cx=0.5, cy=0.45, power=1.25):
    """Built at 256 and scaled up — a gradient has nothing to lose by it."""
    n = 256
    g = Image.new("RGB", (n, n))
    d = ImageDraw.Draw(g)
    d.rectangle([0, 0, n, n], fill=outer)
    steps = 180
    for i in range(steps, 0, -1):
        t = i / steps
        rad = t * n * 0.78
        k = (1 - t) ** power
        col = tuple(round(outer[c] + (inner[c] - outer[c]) * k) for c in range(3))
        d.ellipse([cx * n - rad, cy * n - rad, cx * n + rad, cy * n + rad], fill=col)
    return g.resize((size, size), Image.LANCZOS)


def vertical(size, top, bottom):
    n = 256
    g = Image.new("RGB", (n, n))
    d = ImageDraw.Draw(g)
    for y in range(n):
        t = y / (n - 1)
        d.line([(0, y), (n, y)], fill=tuple(round(top[c] + (bottom[c] - top[c]) * t) for c in range(3)))
    return g.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------- the pieces

def king_mask():
    """The game's own king, rebuilt as true curves.

    The sprite it follows is drawn with a stepped outline, which is where the
    old icon's blockiness came from — it was traced from 192x288 art. Same
    silhouette, described in beziers instead: cross, neck, rounded shoulders, a
    waist, then a flare to a wide plinth.
    """
    m = blank()
    d = ImageDraw.Draw(m)

    rrect(d, (470, 76, 554, 258), 30)          # cross, upright
    rrect(d, (392, 124, 632, 208), 30)         # cross, arms
    rrect(d, (446, 240, 578, 320), 26)         # neck

    shoulder = bezier((578, 268), (664, 282), (692, 318), (688, 378))
    waist = bezier((688, 378), (682, 452), (610, 462), (602, 536))
    flare = bezier((602, 536), (592, 646), (704, 736), (748, 856))
    right = shoulder + waist + flare

    body = [(512, 268)] + right + [(748, 872), (276, 872)] + mirror(right)
    d.polygon([(px(x), px(y)) for x, y in body], fill=255)

    rrect(d, (238, 856, 786, 944), 34)         # plinth
    return m


def knight_mask():
    """The knight, because its profile is the one chess silhouette still
    unmistakable at 32 points — every other piece is a round top on a cone.

    One closed path walked clockwise from the base; a self-intersecting polygon
    fills as a bow tie. The features are pushed harder than a real piece would
    have them — ears proud of the poll, muzzle jutting well clear of the chest,
    a narrow throat behind it — because at 32 points a knight drawn to correct
    proportions is just a lump.
    """
    m = blank()
    d = ImageDraw.Draw(m)

    pts = [(742, 846)]
    pts += bezier((742, 846), (722, 726), (710, 640), (702, 556))
    pts += bezier((702, 556), (724, 418), (700, 300), (612, 238))
    pts += [(612, 238), (628, 132), (558, 206), (512, 126), (486, 232)]   # ears
    pts += bezier((486, 232), (408, 268), (330, 322), (286, 394))
    pts += bezier((286, 394), (242, 434), (236, 474), (270, 502))         # muzzle
    pts += bezier((270, 502), (322, 520), (374, 532), (406, 570))         # jaw
    pts += bezier((406, 570), (456, 646), (448, 744), (424, 846))         # throat
    d.polygon([(px(x), px(y)) for x, y in pts], fill=255)

    rrect(d, (300, 830, 724, 878), 20)         # step
    rrect(d, (250, 868, 774, 944), 32)         # plinth
    return m


def bolt_mask():
    """A laser rising from below — the arcade half of the game, in one stroke."""
    m = blank()
    d = ImageDraw.Draw(m)
    rrect(d, (486, 470, 538, 1010), 26)
    return m


# ---------------------------------------------------------------- neon render

def outline_of(mask, width):
    """A ring of even width, taken as the shape minus an eroded copy. MinFilter
    erodes; doing it here rather than stroking a path keeps the band the same
    thickness around every curve."""
    k = max(3, int(px(width)) | 1)
    inner = mask.filter(ImageFilter.MinFilter(min(k, 9)))
    for _ in range(max(0, k // 9)):
        inner = inner.filter(ImageFilter.MinFilter(9))
    return Image.eval(Image.merge("L", [mask]).point(lambda v: v), lambda v: v), inner


def neon(base, mask, color, *, glow=34, glow_alpha=150, core=None, fill=None):
    """Composite a glowing shape onto `base`. Drawn glow-first so the outline
    sits on top of its own halo rather than under it."""
    small = mask.resize((S, S), Image.LANCZOS)

    if fill is not None:
        layer = Image.new("RGB", (S, S), fill)
        base.paste(layer, (0, 0), small)

    halo = small.filter(ImageFilter.GaussianBlur(glow))
    halo = halo.point(lambda v: min(255, int(v * glow_alpha / 255)))
    base.paste(Image.new("RGB", (S, S), color), (0, 0), halo)

    base.paste(Image.new("RGB", (S, S), color), (0, 0), small)
    if core is not None:
        k = max(3, int(px(core)) | 1)
        inner = mask
        for _ in range(max(1, k // 9)):
            inner = inner.filter(ImageFilter.MinFilter(9))
        base.paste(Image.new("RGB", (S, S), WHITE), (0, 0), inner.resize((S, S), Image.LANCZOS))
    return base


def gradient_fill(base, mask, top, bottom, *, glow, glow_alpha=190):
    """A solid piece lit top to bottom, with a halo behind it. An outline is a
    thin line, and a thin line is the first thing to disappear when the icon is
    drawn at 32 points; a filled silhouette keeps its shape all the way down."""
    small = mask.resize((S, S), Image.LANCZOS)
    halo = small.filter(ImageFilter.GaussianBlur(60))
    halo = halo.point(lambda v: min(255, int(v * glow_alpha / 255)))
    base.paste(Image.new("RGB", (S, S), glow), (0, 0), halo)
    base.paste(vertical(S, top, bottom), (0, 0), small)
    return base


def ring(mask, width):
    """Hollow the mask, leaving a band `width` design-units thick."""
    k = max(1, int(px(width) / 9))
    inner = mask
    for _ in range(k):
        inner = inner.filter(ImageFilter.MinFilter(9))
    return Image.composite(Image.new("L", mask.size, 0), mask, inner)


# ---------------------------------------------------------------- squircle

def squircle(size, n=5.0):
    """Apple's icon silhouette is a superellipse, not a rounded rectangle. At
    the sizes ALT-TAB and the Dock use, the difference in the corners is the
    difference between looking native and looking pasted on."""
    ss = size * 2
    m = Image.new("L", (ss, ss), 0)
    d = ImageDraw.Draw(m)
    a = ss / 2
    pts = []
    steps = 720
    for i in range(steps + 1):
        th = 2 * math.pi * i / steps
        c, s = math.cos(th), math.sin(th)
        x = a * math.copysign(abs(c) ** (2 / n), c)
        y = a * math.copysign(abs(s) ** (2 / n), s)
        pts.append((a + x, a + y))
    d.polygon(pts, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def finish(img, inset=0.94):
    """Apple leaves air around the silhouette; content runs to about 824/1024."""
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    body = int(S * inset)
    shaped = img.resize((body, body), Image.LANCZOS)
    mask = squircle(body)
    off = (S - body) // 2
    canvas.paste(shaped, (off, off), mask)
    return canvas


# ---------------------------------------------------------------- the options

def option_a():
    """Neon King. The concept that is already there, executed properly: the
    piece nearly fills the frame, every edge is a real curve, and the ground is
    a lit nebula instead of flat black."""
    bg = radial(S, (0x2A, 0x1B, 0x5C), (0x07, 0x05, 0x18))
    m = king_mask()
    neon(bg, ring(m, 34), CYAN, glow=52, glow_alpha=210, core=12)
    return finish(bg)


def option_b():
    """Solid King. The same piece filled rather than outlined, lit cyan over a
    magenta halo — the game's two colours doing the work. This is the one that
    holds its shape at 16 and 32 points, where a neon line thins to nothing."""
    bg = radial(S, (0x24, 0x10, 0x44), (0x06, 0x03, 0x14), cy=0.5)
    gradient_fill(bg, king_mask(), (0x9C, 0xF4, 0xFF), (0x0E, 0x86, 0xC4),
                  glow=MAGENTA, glow_alpha=150)
    return finish(bg)


def option_c():
    """Knight. A different piece for a different reason: at the smallest sizes a
    king, queen and bishop all collapse into the same blob, and the knight does
    not."""
    bg = radial(S, (0x10, 0x2C, 0x5E), (0x03, 0x06, 0x16), cy=0.5)
    gradient_fill(bg, knight_mask(), (0xB4, 0xF6, 0xFF), (0x10, 0x7A, 0xB8),
                  glow=CYAN, glow_alpha=120)
    return finish(bg)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [("a-neon-king", option_a),
                     ("b-solid-king", option_b),
                     ("c-knight", option_c)]:
        img = fn()
        img.save(OUT / f"{name}-1024.png")
        for sz in (512, 256, 128, 64, 32, 16):
            img.resize((sz, sz), Image.LANCZOS).save(OUT / f"{name}-{sz}.png")

        # A full iconset: every size Apple asks for, each resampled from the
        # 1024 master rather than from the size above it.
        iset = OUT / f"{name}.iconset"
        iset.mkdir(exist_ok=True)
        # iconutil rejects an @2x file that does not claim 144 DPI, and fails
        # with nothing but "Failed to generate ICNS" when it does.
        for base in (16, 32, 128, 256, 512):
            img.resize((base, base), Image.LANCZOS).save(
                iset / f"icon_{base}x{base}.png", dpi=(72, 72))
            img.resize((base * 2, base * 2), Image.LANCZOS).save(
                iset / f"icon_{base}x{base}@2x.png", dpi=(144, 144))
        print("wrote", name)
