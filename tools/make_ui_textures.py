"""Draws the 'ancient spellbook' UI textures (no downloads):
  parchment panel with burnt edges, leather plate with stitches, small paper
  button, and a red wax seal.     python3 tools/make_ui_textures.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
rng = np.random.default_rng(3)


def fbm(w, h, octaves=5, base=8):
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        n = base * 2 ** o
        small = rng.random((n + 1, n + 1))
        img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(img) / 255.0 * amp
        amp *= 0.5
    out -= out.min()
    return out / out.max()


def edge_dist(w, h, margin):
    y, x = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y)).astype(float)
    return np.clip(d / margin, 0, 1)


def save(name, rgba):
    Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))


def parchment(size=256, margin=56):
    n = fbm(size, size)
    fine = fbm(size, size, 3, 48)
    base = np.array([0.93, 0.85, 0.66])
    col = base[None, None, :] * (0.86 + 0.16 * n[..., None]) - 0.05 * fine[..., None]
    # stains
    st = fbm(size, size, 4, 4)
    col *= (1 - 0.12 * np.clip(st - 0.55, 0, 1)[..., None] * 3)
    # burnt, irregular edge
    wobble = fbm(size, size, 4, 6)
    d = edge_dist(size, size, margin) - (wobble - 0.5) * 0.35
    burn = np.clip(1 - d * 2.2, 0, 1) ** 1.4
    col = col * (1 - burn[..., None] * 0.75) + np.array([0.22, 0.11, 0.03]) * burn[..., None] * 0.75
    alpha = np.clip(d * 6.0, 0, 1)
    save("parchment.png", np.dstack([col, alpha]))


def leather(size=128, margin=26):
    n = fbm(size, size, 5, 6)
    grain = fbm(size, size, 2, 64)
    col = np.array([0.36, 0.17, 0.10])[None, None, :] * (0.75 + 0.35 * n[..., None]) * (0.9 + 0.2 * grain[..., None])
    d = edge_dist(size, size, 6)
    col *= (0.55 + 0.45 * d)[..., None]
    img = Image.fromarray((np.dstack([np.clip(col, 0, 1), np.ones((size, size))]) * 255).astype(np.uint8), "RGBA")
    dr = ImageDraw.Draw(img)
    s = 11
    for i in range(s, size - s, 7):  # stitches
        for a, b in [((i, s), (i + 4, s)), ((i, size - s), (i + 4, size - s)), ((s, i), (s, i + 4)), ((size - s, i), (size - s, i + 4))]:
            dr.line([a, b], fill=(222, 196, 140, 255), width=2)
    # rounded corners
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=12, fill=255)
    img.putalpha(mask)
    img.save(os.path.join(OUT, "leather.png"))


def paper_button(w=128, h=64):
    n = fbm(w, h, 4, 6)
    col = np.array([0.95, 0.88, 0.70])[None, None, :] * (0.88 + 0.14 * n[..., None])
    d = edge_dist(w, h, 14)
    col *= (0.7 + 0.3 * d)[..., None]
    img = Image.fromarray((np.dstack([np.clip(col, 0, 1), np.ones((h, w))]) * 255).astype(np.uint8), "RGBA")
    dr = ImageDraw.Draw(img)
    dr.rounded_rectangle([3, 3, w - 4, h - 4], radius=8, outline=(70, 38, 14, 255), width=3)
    dr.rounded_rectangle([8, 8, w - 9, h - 9], radius=5, outline=(160, 112, 40, 255), width=1)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=10, fill=255)
    img.putalpha(mask)
    img.save(os.path.join(OUT, "paper_button.png"))


def wax_seal(size=128):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    c = size / 2
    pts = []
    for i in range(48):
        a = 2 * np.pi * i / 48
        r = c * (0.92 + 0.06 * np.sin(i * 1.7) + 0.03 * rng.random())
        pts.append((c + np.cos(a) * r, c + np.sin(a) * r))
    dr.polygon(pts, fill=(150, 22, 18, 255))
    dr.ellipse([c * 0.32, c * 0.32, size - c * 0.32, size - c * 0.32], outline=(105, 12, 10, 255), width=5)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    arr = np.asarray(img).astype(float) / 255
    y, x = np.mgrid[0:size, 0:size]
    light = np.clip(1.15 - ((x - size * 0.35) ** 2 + (y - size * 0.3) ** 2) / (size * size * 0.5), 0.6, 1.25)
    arr[..., :3] *= light[..., None]
    save("wax_seal.png", arr)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    parchment()
    leather()
    paper_button()
    wax_seal()
    print("UI textures written to", os.path.abspath(OUT))
