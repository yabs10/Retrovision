# Monitor art for Retrovision: slice-able beige/black CRT frames, button strips,
# tube masks, LCD grids, glass glare, degauss rainbow, softer scanlines.
import numpy as np, colorsys
from PIL import Image
OUT = "Retrovision/media/"
rng = np.random.default_rng(2004)

def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(OUT + name + ".tga")

def sd_round_rect(px, py, x0, y0, x1, y1, r):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    bx, by = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = np.abs(px - cx) - bx, np.abs(py - cy) - by
    out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    return out + np.minimum(np.maximum(qx, qy), 0) - r

def grad(d):
    gy, gx = np.gradient(d)
    n = np.hypot(gx, gy) + 1e-9
    return gx / n, gy / n

# ---------------------------------------------------------------- monitor frame
# 512x512 art; slice margins L/T/R 96, B 144 (see FX.lua).
S = 512
SIDE, TOP, BOT = 56, 56, 104   # plastic thickness
RING = 12                      # unlit black glass border inside the opening
OUT_R, IN_R = 22, 30

def frame(base, hi, spec, name):
    y, x = np.mgrid[0:S, 0:S].astype(float) + 0.5
    d_out = sd_round_rect(x, y, 0, 0, S, S, OUT_R)
    d_in = sd_round_rect(x, y, SIDE, TOP, S - SIDE, S - BOT, IN_R)      # opening in the plastic
    d_glass = sd_round_rect(x, y, SIDE + RING, TOP + RING, S - SIDE - RING, S - BOT - RING, IN_R - 6)
    L = np.array([-0.55, -0.83])                                        # light from top-left

    shade = np.ones((S, S))
    shade *= 1.05 - 0.12 * (y / S)                                       # top lighter
    # outer rounded lip
    nx, ny = grad(d_out)
    lip = np.clip(1 + d_out / 7, 0, 1)                                   # 1 at edge -> 0 inside 7px
    shade += lip * (nx * L[0] + ny * L[1]) * hi
    # inner bevel sloping down to the glass (recessed screen)
    nx2, ny2 = grad(d_in)
    bev = np.clip(1 - d_in / 16, 0, 1) * (d_in > 0)
    shade += bev * (-(nx2 * L[0] + ny2 * L[1])) * hi * 0.9
    shade -= bev * 0.10
    # soft sheen band on the top edge (glossy)
    shade += spec * np.exp(-((y - TOP * 0.45) / 10) ** 2) * (d_in > 0) * (y < TOP)
    shade += rng.normal(0, 0.012, (S, S))                                # plastic grain

    rgb = np.stack([base[i] * shade for i in range(3)], -1) * 255
    # outside the plastic = dark room (covers the game at the screen corners)
    inside = np.clip(0.5 - d_out, 0, 1)
    room = np.array([0.035, 0.03, 0.045]) * 255
    for i in range(3): rgb[..., i] = rgb[..., i] * inside + room[i] * (1 - inside)
    a = np.ones((S, S))
    # glass ring: near black with faint reflection at the top-left
    glass = (d_in <= 0)
    gshade = 0.035 + 0.05 * np.clip(-(x - S / 2) / S - (y - S / 2) / S, 0, 1)
    for i in range(3):
        rgb[..., i] = np.where(glass, gshade * 255 * (1.0 if i < 2 else 1.15), rgb[..., i])
    # picture area: fade glass alpha out over 4px into the picture
    a = np.where(glass, np.clip(0.5 + d_glass / 4 + 0.5, 0, 1), a)
    a = np.where(d_glass < -4, 0, a)
    save(np.dstack([rgb, a * 255]), name)

frame((0.86, 0.83, 0.75), 0.22, 0.03, "frame_beige")
frame((0.11, 0.11, 0.12), 0.55, 0.10, "frame_black")

# button strip for the chin: power button, 4 small buttons, LED (LED at x=228,y=32 of 256x64)
def buttons(base, hi, name):
    W, H = 256, 64
    y, x = np.mgrid[0:H, 0:W].astype(float) + 0.5
    rgb = np.zeros((H, W, 3)); a = np.zeros((H, W))
    def blob(d, depth):
        nonlocal rgb, a
        nx, ny = grad(d)
        inside = np.clip(0.5 - d, 0, 1)
        edge = np.clip(1 + d / 3, 0, 1)
        sh = (1 - depth) + edge * (nx * -0.55 + ny * -0.83) * hi * -1     # pressed-in look
        sh += np.clip(-d / 6, 0, 1) * 0.0
        for i in range(3):
            rgb[..., i] = rgb[..., i] * (1 - inside) + base[i] * sh * 255 * inside
        a = np.maximum(a, inside)
    for i in range(4):
        cx = 40 + i * 34
        blob(sd_round_rect(x, y, cx - 11, 26, cx + 11, 38, 5), 0.12)
    blob(np.hypot(x - 196, y - 32) - 12, 0.08)                            # power button
    blob(np.hypot(x - 196, y - 32) - 7, -0.05)
    d = np.hypot(x - 228, y - 32) - 3.5                                   # LED
    led = np.clip(0.5 - d, 0, 1)
    for i, c in enumerate((0.25, 1.0, 0.35)):
        rgb[..., i] = rgb[..., i] * (1 - led) + c * 255 * led
    a = np.maximum(a, led)
    save(np.dstack([rgb, a * 255]), name)

buttons((0.80, 0.77, 0.69), 0.3, "buttons_beige")
buttons((0.16, 0.16, 0.17), 0.6, "buttons_black")

# ---------------------------------------------------------------- tube masks (MOD blend, 8x8 tiles)
def mod_tile(fn, name):
    t = np.zeros((8, 8, 4)); t[..., 3] = 255
    for yy in range(8):
        for xx in range(8):
            t[yy, xx, :3] = np.array(fn(xx, yy)) * 255
    save(t, name)

# Masks only darken (MOD), so keep them light; real tubes made up for the mask with brightness.
for lvl, d in ((1, 0.93), (2, 0.86), (3, 0.76)):
    g = d * 0.95
    col = [(1, d, d), (d, 1, d), (d, d, 1)]
    # aperture grille: RGB stripes + thin dark gap
    mod_tile(lambda x, y: col[x % 4] if x % 4 < 3 else (g, g, g), f"mask{lvl}")
    # shadow mask: triads in staggered rows with dark gaps between rows
    def dot(x, y):
        if y % 4 == 3: return (g, g, g)
        ph = 0 if (y // 4) % 2 == 0 else 2
        k = (x + ph) % 4
        return col[k] if k < 3 else (g, g, g)
    mod_tile(dot, f"dot{lvl}")
    # LCD: RGB subpixels with a dark grid line between pixels
    mod_tile(lambda x, y: (g, g, g) if y % 4 == 3 else (col[x % 4] if x % 4 < 3 else (g, g, g)), f"lcd{lvl}")
    # handheld grid: plain cells with dark gaps
    mod_tile(lambda x, y: (g * 0.92, g * 0.92, g * 0.92) if (x % 4 == 3 or y % 4 == 3) else (1, 1, 1), f"grid{lvl}")

# ---------------------------------------------------------------- softer thick scanlines (beam profile)
t = np.zeros((8, 8, 4))
for yy, al in enumerate([0.0, 0.35, 1.0, 0.35] * 2):
    t[yy, :, 3] = al * 255
save(t, "scan4")
# 3 px and 6 px spacing: 8 wide, one period tall (non-power-of-two, tile with REPEAT + NEAREST).
# Average darkness close to scan2 (.50) and scan4 (.43): scan3 .42, scan6 .45.
for name, prof in (("scan3", [0.0, 0.25, 1.0]), ("scan6", [0.0, 0.0, 0.35, 1.0, 1.0, 0.35])):
    t = np.zeros((len(prof), 8, 4))
    for yy, al in enumerate(prof):
        t[yy, :, 3] = al * 255
    save(np.round(t), name)

# ---------------------------------------------------------------- glass glare (ADD, white)
G = 512
y, x = np.mgrid[0:G, 0:G].astype(float) / G
u = (x + y) / np.sqrt(2)                       # diagonal coordinate
streak = np.exp(-((u - 0.42) / 0.06) ** 2) * np.exp(-((x - 0.3) / 0.35) ** 2)
soft = np.exp(-(((x - 0.22) / 0.30) ** 2 + ((y - 0.18) / 0.22) ** 2))
glare = np.clip(streak * 0.55 + soft * 0.45, 0, 1)
# TPDF dither (+-1 level, fixed seed) before quantising, against banding when stretched
grng = np.random.default_rng(2005)
ga = np.round(glare * 255 + grng.random((G, G)) - grng.random((G, G)))
save(np.dstack([np.full((G, G, 3), 255), ga]), "glare")

# ---------------------------------------------------------------- degauss rainbow (horizontal hue sweep)
W = 256
rb = np.zeros((8, W, 4))
for i in range(W):
    r, g_, b = colorsys.hsv_to_rgb(i / W, 0.9, 1)
    rb[:, i, :3] = (r * 255, g_ * 255, b * 255)
rb[..., 3] = 255
save(rb, "rainbow")
print("ok")
