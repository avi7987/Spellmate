"""Creates team-coloured versions of the KayKit palette textures.

KayKit characters use one small "swatch" texture. We recolour it per team:
  light  = Kingdom of Light: royal blue cloth, silver/gold metal
  shadow = Kingdom of Shadow: purple cloth, dark steel metal
  *_king = the king variant: metal becomes gold (light) / dark gold (shadow)

Usage: python3 tools/recolor_textures.py <source_dir> <output_dir>
"""
import colorsys
import os
import sys

import numpy as np
from PIL import Image

CLOTH_HUE = {"light": 222 / 360, "shadow": 282 / 360}


def recolor(img: Image.Image, team: str, king: bool) -> Image.Image:
    rgba = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    rgb, alpha = rgba[..., :3], rgba[..., 3:]
    hsv = np.zeros_like(rgb)
    flat = rgb.reshape(-1, 3)
    hsv_flat = np.array([colorsys.rgb_to_hsv(*p) for p in flat])
    hsv = hsv_flat.reshape(rgb.shape)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    hue_deg = h * 360

    is_grey = s < 0.16
    is_skin_or_wood = (hue_deg >= 12) & (hue_deg < 42) & ~is_grey
    is_gold = (hue_deg >= 42) & (hue_deg < 65) & (s > 0.35)
    is_cloth = ~is_grey & ~is_skin_or_wood & ~is_gold & (s > 0.25)

    out_h, out_s, out_v = h.copy(), s.copy(), v.copy()
    # Cloth -> team colour
    out_h[is_cloth] = CLOTH_HUE[team]
    out_s[is_cloth] = np.clip(s[is_cloth] * 1.05 + 0.1, 0, 1)
    out_v[is_cloth] = v[is_cloth] * 0.78  # deeper, more medieval tones
    metal = is_grey & (v > 0.25) & (v < 0.97)
    if team == "light":
        if king:
            out_h[metal] = 44 / 360
            out_s[metal] = 0.75
            out_v[metal] = np.clip(v[metal] * 1.05 + 0.08, 0, 1)
    else:
        out_h[metal] = 250 / 360
        out_s[metal] = 0.18
        out_v[metal] = v[metal] * 0.62
        if king:
            out_h[metal] = 38 / 360
            out_s[metal] = 0.55
            out_v[metal] = v[metal] * 0.8
        else:
            out_s[is_gold] = 0.08  # gold trims become silver

    res = np.array([colorsys.hsv_to_rgb(*p) for p in np.stack([out_h, out_s, out_v], -1).reshape(-1, 3)])
    res = res.reshape(rgb.shape)
    out = np.concatenate([res, alpha], -1)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for name in sorted(os.listdir(src)):
        # only the original swatch textures (e.g. "knight_texture.png"), not Godot copies
        if not name.endswith("_texture.png") or not name[0].islower():
            continue
        img = Image.open(os.path.join(src, name)).resize((256, 256), Image.NEAREST)
        base = name[: -len(".png")]
        for team in ("light", "shadow"):
            recolor(img, team, False).save(os.path.join(dst, f"{base}_{team}.png"))
            if name.startswith("knight"):
                recolor(img, team, True).save(os.path.join(dst, f"{base}_{team}_king.png"))
        print("recoloured", name)


if __name__ == "__main__":
    main()
