"""Adds a dark sticker outline + soft shadow to the item icons baked by
`godot -- --bake-icons`. Run after baking:  py -3.13 tools/outline_icons.py
"""
import os
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = ["wheat", "sunflower", "flour", "tomato", "potato", "bread", "seeds", "croissant", "pizza", "fries", "cash"]
INK = (43, 38, 52)

for name in ITEMS:
    path = os.path.join(ROOT, "assets", "icons", name + ".png")
    im = Image.open(path).convert("RGBA")
    # shrink a touch so the outline fits inside the canvas
    W = im.width
    inner = im.resize((int(W * 0.84), int(W * 0.84)), Image.LANCZOS)
    base = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    off = (W - inner.width) // 2
    base.alpha_composite(inner, (off, off - 2))
    a = base.split()[3].point(lambda v: 255 if v > 40 else 0)
    ring = a.filter(ImageFilter.MaxFilter(7))
    ring = ring.filter(ImageFilter.GaussianBlur(0.8))
    outline = Image.new("RGBA", (W, W), INK + (0,))
    outline.putalpha(ring)
    shadow = Image.new("RGBA", (W, W), (20, 10, 30, 0))
    shadow.putalpha(ring.point(lambda v: int(v * 0.35)).filter(ImageFilter.GaussianBlur(2.5)))
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, 4))
    out.alpha_composite(outline)
    out.alpha_composite(base)
    out.save(path)
    print("outlined", name)
