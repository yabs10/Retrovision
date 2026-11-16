# Generates the overlay textures for the Retrovision addon (uncompressed 32-bit TGA).
import math
from PIL import Image
out = "Retrovision/media/"

def save(img, name): img.save(out + name + ".tga")

# Retrovision tiles: 8x8, dark rows, alpha only. period 2 and 4.
for p in (2,):
    im = Image.new("RGBA", (8, 8))
    for y in range(8):
        for x in range(8):
            dark = (y % p) >= p // 2
            im.putpixel((x, y), (0, 0, 0, 255 if dark else 0))
    save(im, f"scan{p}")

# (tube masks + thick scanlines now come from make_monitor.py)

# Vignette: black, alpha rises toward edges/corners. 512x512, stretched over the whole
# screen, so the alpha ramp gets triangular (TPDF, +-1 level) dither before 8-bit
# quantising to break up banding in dark scenes. Fixed seed -> reproducible.
import numpy as np
N = 512
yy, xx = np.mgrid[0:N, 0:N].astype(float) + 0.5
dx, dy = xx / N * 2 - 1, yy / N * 2 - 1
d = (np.abs(dx) ** 4 + np.abs(dy) ** 4) ** 0.25      # rounded-rect distance, hugs the screen edges like a tube
a = np.clip((d - 0.55) / 0.5, 0, 1)
a = a * a * (3 - 2 * a)
drng = np.random.default_rng(1986)
dither = drng.random((N, N)) - drng.random((N, N))   # triangular, -1..+1 levels
av = np.where(a > 0, np.clip(np.round(a * 255 + dither), 0, 255), 0)   # keep the centre exactly clear
vig = np.zeros((N, N, 4), np.uint8); vig[..., 3] = av
save(Image.fromarray(vig, "RGBA"), "vignette")

# Rolling band: soft vertical bell, white.
im = Image.new("RGBA", (8, 64))
for y in range(64):
    t = (y + 0.5) / 64 * 2 - 1
    a = math.exp(-(t * 2.2) ** 2)
    for x in range(8):
        im.putpixel((x, y), (255, 255, 255, int(255 * a)))
save(im, "band")

# ---- GUI art (white, tinted in game) ----
from PIL import ImageDraw, ImageFilter

def aa_shape(size, draw_fn, scale=4):
    big = Image.new("L", (size[0] * scale, size[1] * scale), 0)
    draw_fn(ImageDraw.Draw(big), scale)
    return big.resize(size, Image.LANCZOS)

def white_with_alpha(a):
    im = Image.new("RGBA", a.size, (255, 255, 255, 0)); im.putalpha(a); return im

# rounded rect, radius 6 (slice margins 6)
save(white_with_alpha(aa_shape((24, 24), lambda d, s: d.rounded_rectangle([0, 0, 24*s-1, 24*s-1], 6*s, fill=255))), "round6")
# rounded outline, 1.5px, radius 6
save(white_with_alpha(aa_shape((24, 24), lambda d, s: d.rounded_rectangle([0, 0, 24*s-1, 24*s-1], 6*s, outline=255, width=int(1.5*s)))), "round6line")
# pill 40x20 (slice margins 10)
save(white_with_alpha(aa_shape((40, 20), lambda d, s: d.rounded_rectangle([0, 0, 40*s-1, 20*s-1], 10*s, fill=255))), "pill")
# solid circle
save(white_with_alpha(aa_shape((32, 32), lambda d, s: d.ellipse([0, 0, 32*s-1, 32*s-1], fill=255))), "dot")
# soft radial glow
g = Image.new("L", (64, 64))
for y in range(64):
    for x in range(64):
        r = math.hypot(x - 31.5, y - 31.5) / 32
        g.putpixel((x, y), int(255 * max(0, 1 - r) ** 2))
save(white_with_alpha(g), "glowdot")
# panel glow: soft halo around a rect inset 24px, hollow (slice margins 32)
N = 96
a = Image.new("L", (N, N), 0)
ImageDraw.Draw(a).rounded_rectangle([24, 24, N - 25, N - 25], 8, fill=255)
a = a.filter(ImageFilter.GaussianBlur(9))
hole = Image.new("L", (N, N), 0)
ImageDraw.Draw(hole).rounded_rectangle([25, 25, N - 26, N - 26], 7, fill=255)
a = Image.composite(Image.new("L", (N, N), 0), a, hole)
save(white_with_alpha(a), "panelglow")
# synthwave perspective grid, horizon at the top, fades upward
W, H = 512, 128
grid = Image.new("L", (W * 2, H * 2), 0)
d = ImageDraw.Draw(grid)
cx = W
for i in range(-16, 17):
    d.line([(cx + i * 18, 0), (cx + i * 260, H * 2)], fill=255, width=2)
for k in range(1, 12):
    y = int(H * 2 * (k / 11) ** 2.2)
    d.line([(0, y), (W * 2, y)], fill=255, width=2)
grid = grid.resize((W, H), Image.LANCZOS)
fade = Image.new("L", (W, H))
for y in range(H):
    v = int(255 * (y / H) ** 1.3)
    for x in range(W): fade.putpixel((x, y), v)
from PIL import ImageChops
save(white_with_alpha(ImageChops.multiply(grid, fade)), "grid")

# ---- FX textures ----
import random
random.seed(1985)
# film grain, 128x128: each texel is black or white (half each) with a film-grain-like
# alpha (many faint specks, few strong ones), so at any layer alpha it darkens and
# brightens equally instead of laying a grey fog over the picture.
im = Image.new("RGBA", (128, 128))
for y in range(128):
    for x in range(128):
        v = 255 if random.random() < 0.5 else 0
        a = int(255 * random.random() ** 1.8 + 0.5)
        im.putpixel((x, y), (v, v, v, a))
save(im, "noise")
# TV snow / static, 128x128: dense, mostly opaque, contrasty black/white with some greys
# (VHS tracking bars, bottom noise strip, low-health and channel-change static).
im = Image.new("RGBA", (128, 128))
for y in range(128):
    for x in range(128):
        t = random.random()
        t = 0.5 + 0.5 * math.copysign(abs(2 * t - 1) ** 0.5, t - 0.5)   # push toward black / white
        v = int(255 * t + 0.5)
        a = int(255 * (0.78 + 0.22 * random.random()) + 0.5)
        im.putpixel((x, y), (v, v, v, a))
save(im, "static")
# bezel corner: black outside a quarter circle whose centre is the bottom-right of the texture
N = 128
a = aa_shape((N, N), lambda d, s: d.ellipse([0, 0, 2 * N * s, 2 * N * s], fill=255))
a = Image.eval(a, lambda v: 255 - v)
im = Image.new("RGBA", (N, N), (0, 0, 0, 0)); im.putalpha(a)
im2 = Image.new("RGBA", (N, N), (0, 0, 0, 255)); im2.putalpha(a)
save(im2, "corner")
# play triangle for the OSD
save(white_with_alpha(aa_shape((32, 32), lambda d, s: d.polygon([(4*s, 3*s), (29*s, 16*s), (4*s, 29*s)], fill=255))), "play")
