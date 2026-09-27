"""Generates the 2D art for Pigeon Bakery Tycoon.

- assets/logo/*       the company logo, cut from the user's pigeon photo
- assets/icons/ui_*   flat UI glyphs (gear, upgrade arrow, hand, ...)
- assets/icons/*.png  coloured card icons for things that are not items

Item icons (bread, seeds, ...) are rendered from the real 3D models by
`godot -- --bake-icons`, not drawn here.

Run with Python 3.13 (needs Pillow):  py -3.13 tools/gen_art.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
PHOTO = os.path.join(ROOT, "tools", "pigeon_photo.webp")
# the repo copy is pre-cropped to the pigeon; crop maths below use the
# original photo's coordinates, so shift them by the crop origin
PHOTO_ORIGIN = (200, 480)
SS = 4  # supersampling factor

INK = (43, 38, 52, 255)
WHITE = (255, 255, 255, 255)


def save(im, *parts):
    path = os.path.join(ASSETS, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", os.path.relpath(path, ROOT))


def down(im, size):
    return im.resize((size, size), Image.LANCZOS)


def circle_mask(size, inset=0):
    m = Image.new("L", (size * SS, size * SS), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((inset * SS, inset * SS, (size - inset) * SS - 1, (size - inset) * SS - 1), fill=255)
    return m.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------- logo ----
def photo_square(size, cx=685, cy=965, half=455):
    im = Image.open(PHOTO).convert("RGB")
    ox, oy = PHOTO_ORIGIN
    crop = im.crop((cx - half - ox, cy - half - oy, cx + half - ox, cy + half - oy))
    return crop.resize((size, size), Image.LANCZOS)


def make_badge(size=512):
    """Round badge: the photo inside a white + orange ring with a soft shadow."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # shadow
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((size * 0.05, size * 0.08, size * 0.97, size * 1.0), fill=(20, 10, 30, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(size * 0.02))
    out.alpha_composite(sh)
    ring = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    S = size * SS
    pad = S * 0.03
    d.ellipse((pad, pad, S - pad, S - pad), fill=(255, 166, 35, 255), outline=INK, width=int(S * 0.012))
    p2 = S * 0.085
    d.ellipse((p2, p2, S - p2, S - p2), fill=WHITE)
    ring = ring.resize((size, size), Image.LANCZOS)
    out.alpha_composite(ring)
    inner = int(size * 0.13)
    ph_size = size - inner * 2
    ph = photo_square(ph_size).convert("RGBA")
    ph.putalpha(circle_mask(ph_size))
    out.alpha_composite(ph, (inner, inner))
    return out


def make_logo_files():
    save(make_badge(512), "logo", "logo_badge.png")
    save(make_badge(256), "logo", "icon.png")
    # square photo for the menu polaroid and the 3D shop sign
    ph = photo_square(512).convert("RGBA")
    save(ph, "logo", "logo_square.png")
    # polaroid
    W, H = 440, 520
    pol = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(pol)
    d.rounded_rectangle((6, 10, W - 2, H - 2), 18, fill=(20, 10, 30, 90))
    pol = pol.filter(ImageFilter.GaussianBlur(6))
    d = ImageDraw.Draw(pol)
    d.rounded_rectangle((0, 0, W - 8, H - 12), 16, fill=(255, 253, 246, 255))
    ph = photo_square(392, cx=700, cy=980, half=500)
    pol.paste(ph, (20, 20))
    save(pol, "logo", "polaroid.png")


# --------------------------------------------------------------- glyphs ---
class G:
    """Tiny helper that draws at SS x resolution in a 0..100 coordinate box."""

    def __init__(self, size=128):
        self.size = size
        self.S = size * SS
        self.im = Image.new("RGBA", (self.S, self.S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def k(self, v):
        return v * self.S / 100.0

    def pts(self, pts):
        return [(self.k(x), self.k(y)) for x, y in pts]

    def poly(self, pts, fill, outline=INK, w=5):
        p = self.pts(pts)
        if outline:
            self.d.polygon(p, fill=outline)
            # fake stroke: draw lines thick
            self.d.line(p + [p[0]], fill=outline, width=int(self.k(w)), joint="curve")
            for x, y in p:
                r = self.k(w) / 2
                self.d.ellipse((x - r, y - r, x + r, y + r), fill=outline)
        self.d.polygon(p, fill=fill)

    def ell(self, x0, y0, x1, y1, fill, outline=INK, w=5):
        if outline:
            o = w / 2
            self.d.ellipse((self.k(x0 - o), self.k(y0 - o), self.k(x1 + o), self.k(y1 + o)), fill=outline)
        self.d.ellipse((self.k(x0), self.k(y0), self.k(x1), self.k(y1)), fill=fill)

    def rect(self, x0, y0, x1, y1, fill, r=4, outline=INK, w=5):
        if outline:
            o = w / 2
            self.d.rounded_rectangle((self.k(x0 - o), self.k(y0 - o), self.k(x1 + o), self.k(y1 + o)),
                                     self.k(r + o), fill=outline)
        self.d.rounded_rectangle((self.k(x0), self.k(y0), self.k(x1), self.k(y1)), self.k(r), fill=fill)

    def line(self, pts, fill, w):
        p = self.pts(pts)
        self.d.line(p, fill=fill, width=int(self.k(w)), joint="curve")
        for x, y in (p[0], p[-1]):
            r = self.k(w) / 2
            self.d.ellipse((x - r, y - r, x + r, y + r), fill=fill)

    def done(self, shadow=True):
        im = self.im.resize((self.size, self.size), Image.LANCZOS)
        if not shadow:
            return im
        a = im.split()[3]
        sh = Image.new("RGBA", im.size, (20, 10, 30, 0))
        sh.putalpha(a.point(lambda v: int(v * 0.45)))
        sh = sh.filter(ImageFilter.GaussianBlur(self.size * 0.02))
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        out.alpha_composite(sh, (0, int(self.size * 0.03)))
        out.alpha_composite(im)
        return out


def gear(fill=WHITE):
    g = G()
    cx = cy = 50
    pts = []
    teeth = 8
    for i in range(teeth * 4):
        a = (i / (teeth * 4)) * math.tau
        r = 40 if (i % 4) in (0, 1) else 30
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    g.poly(pts, fill)
    g.ell(37, 37, 63, 63, (140, 110, 220, 255))
    return g.done()


def arrow_up(fill=WHITE):
    g = G()
    g.poly([(50, 8), (88, 48), (64, 48), (64, 90), (36, 90), (36, 48), (12, 48)], fill)
    return g.done()


def shoe():
    g = G()
    g.poly([(14, 40), (40, 40), (48, 52), (82, 58), (90, 70), (88, 80), (14, 80)], (255, 90, 90, 255))
    g.rect(12, 76, 92, 86, WHITE, r=3)
    g.line([(6, 30), (24, 30)], (255, 255, 255, 255), 6)
    g.line([(2, 44), (18, 44)], (255, 255, 255, 255), 6)
    g.line([(6, 58), (14, 58)], (255, 255, 255, 255), 6)
    return g.done()


def boxes():
    g = G()
    g.rect(18, 56, 82, 88, (230, 170, 100, 255), r=4)
    g.rect(26, 28, 74, 58, (245, 190, 120, 255), r=4)
    g.rect(34, 6, 66, 30, (255, 210, 140, 255), r=4)
    for (a, b, c) in ((50, 56, 88), (50, 28, 58), (50, 6, 30)):
        g.line([(a, b + 2), (a, c - 2)], (200, 140, 80, 255), 4)
    return g.done()


def coin(fill=(255, 205, 40, 255)):
    g = G()
    g.ell(10, 10, 90, 90, (230, 160, 20, 255))
    g.ell(16, 14, 84, 82, fill, outline=None)
    # $ sign
    g.line([(60, 32), (44, 30), (38, 40), (46, 48), (56, 52), (62, 60), (56, 70), (38, 68)], INK, 7)
    g.line([(50, 22), (50, 78)], INK, 6)
    return g.done()


def person(fill=(90, 170, 255, 255), extra=None):
    g = G()
    g.ell(34, 8, 66, 40, (255, 220, 180, 255))
    g.poly([(22, 92), (26, 56), (40, 46), (60, 46), (74, 56), (78, 92)], fill)
    if extra == "bolt":
        g.poly([(70, 30), (92, 30), (80, 50), (94, 50), (66, 84), (74, 58), (60, 58)], (255, 220, 40, 255), w=4)
    elif extra == "box":
        g.rect(56, 52, 92, 86, (230, 170, 100, 255), r=3)
    return g.done()


def bolt(fill=(255, 220, 40, 255)):
    g = G()
    g.poly([(56, 6), (22, 56), (46, 56), (38, 94), (80, 40), (56, 40), (66, 6)], fill)
    return g.done()


def hand():
    """Pointing glove: index finger up on the LEFT so it reads as 'tap here'."""
    g = G(160)
    skin = WHITE
    g.rect(26, 40, 82, 90, skin, r=16)          # fist
    g.rect(48, 36, 62, 56, skin, r=7)           # curled knuckles
    g.rect(60, 38, 73, 58, skin, r=7)
    g.rect(71, 42, 83, 60, skin, r=6)
    g.rect(28, 4, 45, 58, skin, r=8)            # index finger
    g.rect(14, 56, 36, 72, skin, r=8)           # thumb
    g.rect(30, 88, 78, 98, (90, 170, 255, 255), r=3)
    return g.done()


def music_note(on=True):
    g = G()
    g.line([(40, 72), (40, 18), (78, 10), (78, 62)], WHITE, 9)
    g.ell(18, 62, 44, 84, WHITE)
    g.ell(56, 54, 82, 76, WHITE)
    if not on:
        g.line([(14, 14), (88, 88)], (255, 80, 80, 255), 10)
    return g.done()


def speaker(on=True):
    g = G()
    g.poly([(12, 38), (32, 38), (54, 16), (54, 84), (32, 62), (12, 62)], WHITE)
    if on:
        g.line([(66, 34), (72, 50), (66, 66)], WHITE, 7)
        g.line([(78, 22), (88, 50), (78, 78)], WHITE, 7)
    else:
        g.line([(64, 34), (90, 66)], (255, 80, 80, 255), 8)
        g.line([(90, 34), (64, 66)], (255, 80, 80, 255), 8)
    return g.done()


def sun():
    g = G()
    for i in range(8):
        a = i / 8 * math.tau
        g.line([(50 + math.cos(a) * 30, 50 + math.sin(a) * 30), (50 + math.cos(a) * 44, 50 + math.sin(a) * 44)],
               (255, 200, 40, 255), 8)
    g.ell(26, 26, 74, 74, (255, 215, 60, 255))
    return g.done()


def close_x():
    g = G()
    g.line([(24, 24), (76, 76)], WHITE, 16)
    g.line([(76, 24), (24, 76)], WHITE, 16)
    return g.done()


def check():
    g = G()
    g.line([(18, 52), (40, 74), (82, 26)], WHITE, 16)
    return g.done()


def lock():
    g = G()
    g.line([(32, 46), (32, 30), (40, 16), (60, 16), (68, 30), (68, 46)], INK, 14)
    g.line([(32, 46), (32, 30), (40, 16), (60, 16), (68, 30), (68, 46)], (200, 200, 210, 255), 7)
    g.rect(20, 44, 80, 90, (255, 200, 60, 255), r=8)
    g.ell(44, 56, 56, 68, INK, outline=None)
    return g.done()


def star(fill=(255, 210, 40, 255)):
    g = G()
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 44 if i % 2 == 0 else 20
        pts.append((50 + math.cos(a) * r, 54 + math.sin(a) * r))
    g.poly(pts, fill)
    return g.done()


def crown():
    g = G()
    g.poly([(12, 78), (12, 30), (32, 52), (50, 20), (68, 52), (88, 30), (88, 78)], (255, 205, 40, 255))
    g.ell(44, 12, 56, 24, (255, 90, 120, 255), w=3)
    return g.done()


def clock():
    g = G()
    g.ell(10, 10, 90, 90, WHITE)
    g.line([(50, 50), (50, 24)], INK, 7)
    g.line([(50, 50), (68, 58)], INK, 7)
    return g.done()


def table_icon():
    g = G()
    # umbrella
    g.poly([(8, 44), (50, 10), (92, 44)], (240, 80, 80, 255))
    g.poly([(36, 44), (50, 10), (64, 44)], WHITE, outline=None)
    g.line([(50, 44), (50, 84)], INK, 6)
    g.rect(20, 66, 80, 74, (220, 150, 90, 255), r=2)
    g.line([(28, 74), (28, 92)], INK, 5)
    g.line([(72, 74), (72, 92)], INK, 5)
    return g.done()


def fence_icon():
    g = G()
    for x in (16, 42, 68):
        g.poly([(x, 30), (x + 8, 18), (x + 16, 30), (x + 16, 90), (x, 90)], (225, 145, 80, 255))
    g.rect(6, 40, 94, 50, (200, 120, 60, 255), r=2)
    g.rect(6, 66, 94, 76, (200, 120, 60, 255), r=2)
    return g.done()


def fountain_icon():
    g = G()
    g.rect(10, 66, 90, 88, (190, 195, 210, 255), r=6)
    g.rect(16, 64, 84, 72, (90, 190, 255, 255), r=3, outline=None)
    g.rect(44, 34, 56, 66, (190, 195, 210, 255), r=2)
    g.line([(50, 30), (30, 18), (18, 40)], (90, 190, 255, 255), 6)
    g.line([(50, 30), (70, 18), (82, 40)], (90, 190, 255, 255), 6)
    return g.done()


def office_icon():
    g = G()
    g.rect(20, 14, 80, 92, (240, 200, 140, 255), r=6)
    g.rect(28, 24, 72, 86, WHITE, r=3, outline=None)
    g.rect(36, 8, 64, 22, (160, 160, 175, 255), r=4)
    for y in (38, 52, 66):
        g.line([(34, y), (66, y)], (150, 150, 170, 255), 5)
    return g.done()


def broom_icon():
    g = G()
    g.line([(76, 8), (46, 58)], (180, 120, 60, 255), 9)
    g.poly([(30, 50), (58, 64), (48, 94), (10, 78)], (255, 210, 80, 255))
    return g.done()


def hat_icon(kind):
    g = G()
    if kind == "farmer":
        g.ell(6, 52, 94, 80, (240, 210, 120, 255))
        g.rect(28, 26, 72, 66, (240, 210, 120, 255), r=14)
        g.rect(28, 50, 72, 58, (220, 90, 70, 255), r=2, outline=None)
    elif kind == "baker":
        g.ell(20, 10, 56, 44, WHITE)
        g.ell(44, 10, 80, 44, WHITE)
        g.ell(32, 4, 68, 36, WHITE)
        g.rect(28, 36, 72, 76, WHITE, r=4)
        g.rect(26, 70, 74, 84, (240, 240, 240, 255), r=3)
    elif kind == "cashier":
        g.rect(14, 40, 86, 86, (120, 200, 120, 255), r=8)
        g.rect(22, 20, 78, 44, (90, 90, 110, 255), r=6)
        g.rect(28, 26, 72, 38, (160, 255, 170, 255), r=2, outline=None)
        for x in (28, 44, 60):
            g.rect(x, 54, x + 10, 62, WHITE, r=2, outline=None)
            g.rect(x, 68, x + 10, 76, WHITE, r=2, outline=None)
    elif kind == "janitor":
        return broom_icon()
    return g.done()


def statue_icon():
    g = G()
    g.rect(24, 70, 76, 94, (190, 190, 200, 255), r=3)
    g.ell(28, 34, 76, 72, (220, 170, 60, 255))
    g.ell(56, 14, 80, 40, (220, 170, 60, 255))
    g.poly([(78, 24), (92, 28), (78, 32)], (160, 120, 40, 255), w=3)
    return g.done()


def perch_icon():
    g = G()
    g.line([(50, 30), (50, 92)], (220, 170, 40, 255), 8)
    g.line([(20, 34), (80, 34)], (255, 210, 60, 255), 9)
    g.ell(36, 6, 64, 32, WHITE)
    g.poly([(38, 10), (42, 0), (50, 8), (58, 0), (62, 10)], (255, 205, 40, 255), w=3)
    return g.done()


def bubble():
    """Speech bubble for pigeon orders (white, soft outline, tail down)."""
    size = 128
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o = S * 0.035
    d.rounded_rectangle((S * 0.06 - o, S * 0.06 - o, S * 0.94 + o, S * 0.8 + o), S * 0.22, fill=INK)
    d.polygon([(S * 0.38, S * 0.78), (S * 0.62, S * 0.78), (S * 0.5, S * 0.98)], fill=INK)
    d.rounded_rectangle((S * 0.06, S * 0.06, S * 0.94, S * 0.8), S * 0.2, fill=WHITE)
    d.polygon([(S * 0.41, S * 0.76), (S * 0.59, S * 0.76), (S * 0.5, S * 0.92)], fill=WHITE)
    return im.resize((size, size), Image.LANCZOS)


def ground_arrow():
    size = 128
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(0.5, 0.04), (0.92, 0.5), (0.66, 0.5), (0.66, 0.96), (0.34, 0.96), (0.34, 0.5), (0.08, 0.5)]
    d.polygon([(x * S, y * S) for x, y in pts], fill=(255, 255, 255, 235))
    return im.resize((size, size), Image.LANCZOS)


def corner_ring():
    """Soft white ring used under the player / as a pad marker."""
    size = 128
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = S * 0.08
    d.ellipse((w, w, S - w, S - w), outline=(255, 255, 255, 255), width=int(w))
    return im.resize((size, size), Image.LANCZOS)


def soft_dot():
    size = 64
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(32, 0, -1):
        a = int(255 * (1 - i / 32) ** 1.5)
        d.ellipse((32 - i, 32 - i, 32 + i, 32 + i), fill=(255, 255, 255, a))
    return im


def sparkle():
    g = G(64)
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        r = 46 if i % 2 == 0 else 12
        pts.append((50 + math.cos(a) * r, 50 + math.sin(a) * r))
    g.poly(pts, WHITE, outline=None)
    return g.done(shadow=False)


def pad_tex():
    """Ground marker for a hand-off spot: rounded square outline + soft fill."""
    size = 128
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = S * 0.07
    d.rounded_rectangle((w, w, S - w, S - w), S * 0.2, fill=(255, 255, 255, 70), outline=(255, 255, 255, 255), width=int(w))
    return im.resize((size, size), Image.LANCZOS)


def zone_tex():
    """Buy zone: four white corner brackets, like the playable ads."""
    size = 256
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = int(S * 0.075)
    L = S * 0.3
    m = S * 0.06
    r = w // 2
    for cx, cy, sx, sy in ((m, m, 1, 1), (S - m, m, -1, 1), (m, S - m, 1, -1), (S - m, S - m, -1, -1)):
        d.line([(cx, cy + sy * L), (cx, cy), (cx + sx * L, cy)], fill=(255, 255, 255, 255), width=w, joint="curve")
        for px, py in ((cx, cy + sy * L), (cx + sx * L, cy), (cx, cy)):
            d.ellipse((px - r, py - r, px + r, py + r), fill=(255, 255, 255, 255))
    return im.resize((size, size), Image.LANCZOS)


def fill_tex():
    size = 128
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle((S * 0.1, S * 0.1, S * 0.9, S * 0.9), S * 0.14, fill=(255, 255, 255, 255))
    return im.resize((size, size), Image.LANCZOS)


def card_tex():
    """White rounded card with a soft drop shadow (buy-zone price card)."""
    W, H = 160, 190
    S = SS
    im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((8 * S, 14 * S, (W - 6) * S, (H - 4) * S), 30 * S, fill=(30, 20, 40, 90))
    im = im.filter(ImageFilter.GaussianBlur(5 * S))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((6 * S, 6 * S, (W - 6) * S, (H - 12) * S), 28 * S, fill=(255, 255, 255, 250))
    return im.resize((W, H), Image.LANCZOS)


def main():
    make_logo_files()
    icons = {
        "ui_gear": gear(), "ui_up": arrow_up(), "ui_speed": shoe(), "ui_capacity": boxes(),
        "ui_profit": coin(), "ui_staff_speed": person((255, 150, 60, 255), "bolt"),
        "ui_staff_cap": person((90, 200, 120, 255), "box"), "ui_machine": bolt(),
        "ui_hand": hand(), "ui_music_on": music_note(True), "ui_music_off": music_note(False),
        "ui_sfx_on": speaker(True), "ui_sfx_off": speaker(False), "ui_shadows": sun(),
        "ui_close": close_x(), "ui_check": check(), "ui_lock": lock(), "ui_star": star(),
        "ui_crown": crown(), "ui_clock": clock(), "ui_coin": coin(),
        "table": table_icon(), "land": fence_icon(), "fountain": fountain_icon(), "office": office_icon(),
        "hire_farmer": hat_icon("farmer"), "hire_baker": hat_icon("baker"), "hire_cashier": hat_icon("cashier"),
        "hire_janitor": hat_icon("janitor"), "statue": statue_icon(), "perch": perch_icon(),
        "fx_bubble": bubble(), "fx_ground_arrow": ground_arrow(), "fx_ring": corner_ring(),
        "fx_dot": soft_dot(), "fx_sparkle": sparkle(), "fx_pad": pad_tex(), "fx_zone": zone_tex(),
        "fx_fill": fill_tex(), "fx_card": card_tex(),
    }
    for name, im in icons.items():
        save(im, "icons", name + ".png")


if __name__ == "__main__":
    main()
