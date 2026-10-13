#!/usr/bin/env python3
"""Genera el icono de la app (1024x1024): anillo de 16 LEDs de colores con resplandor."""
import colorsys
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "AuroraRemote/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
S, N, R = 1024, 16, 300
bg = Image.new("RGB", (S, S), (9, 10, 14))
d = ImageDraw.Draw(bg)
for y in range(S):  # degradado vertical sutil
    k = y / S
    d.line([(0, y), (S, y)], fill=(int(14 - 6 * k), int(12 - 4 * k), int(26 - 12 * k)))
glow = Image.new("RGB", (S, S), (0, 0, 0))
dots = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd, dd = ImageDraw.Draw(glow), ImageDraw.Draw(dots)
for i in range(N):
    a = i / N * 2 * math.pi - math.pi / 2
    x, y = S / 2 + R * math.cos(a), S / 2 + R * math.sin(a)
    rgb = tuple(int(c * 255) for c in colorsys.hsv_to_rgb(i / N, 0.85, 1))
    gd.ellipse([x - 70, y - 70, x + 70, y + 70], fill=rgb)
    dd.ellipse([x - 34, y - 34, x + 34, y + 34], fill=rgb + (255,))
    hi = tuple(int(c + (255 - c) * 0.6) for c in rgb)  # nucleo mas claro del mismo color
    dd.ellipse([x - 15, y - 15, x + 15, y + 15], fill=hi + (255,))
glow = glow.filter(ImageFilter.GaussianBlur(60))
img = Image.blend(bg, glow, 0.55)
img.paste(dots, (0, 0), dots)
ImageDraw.Draw(img).ellipse([S / 2 - 150, S / 2 - 150, S / 2 + 150, S / 2 + 150], outline=(235, 238, 245), width=6)
img.save(OUT)
print("icono:", OUT)
