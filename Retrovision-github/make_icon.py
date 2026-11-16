# Neon CRT TV icon for Retrovision (minimap button / addon list). 64x64 TGA + preview PNG.
from PIL import Image, ImageDraw, ImageFilter, ImageChops
S = 512
PINK, HOT, VIOLET, CYAN = (255, 47, 168), (255, 79, 216), (138, 61, 255), (46, 230, 255)
BG1, BG2 = (10, 6, 18), (34, 14, 58)

img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):  # vertical violet gradient background
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(BG1[i] + (BG2[i] - BG1[i]) * t) for i in range(3)))

def glow_layer(draw_fn, color, blur):
    m = Image.new("L", (S, S)); draw_fn(ImageDraw.Draw(m))
    g = m.filter(ImageFilter.GaussianBlur(blur))
    return Image.composite(Image.new("RGB", (S, S), color), Image.new("RGB", (S, S)), g), m

def add_neon(draw_fn, color, core=(255, 255, 255), blur=22, strength=1.0):
    global img
    g, m = glow_layer(draw_fn, color, blur)
    img = ImageChops.add(img, g.point(lambda v: int(v * strength)))
    col, _ = glow_layer(draw_fn, color, 0)
    img = Image.composite(Image.blend(Image.new("RGB", (S, S), color), Image.new("RGB", (S, S), core), 0.25), img, m)

# screen fill: dark with cyan scanlines and a little sunset
screen = (128, 170, 384, 380)
scr = Image.new("RGB", (S, S), (16, 8, 34))
sd = ImageDraw.Draw(scr)
sd.ellipse([196, 220, 316, 340], fill=(255, 120, 60))               # sun
for i, y in enumerate(range(286, 345, 14)):                          # sun stripes cut out
    sd.rectangle([180, y, 330, y + 4 + i], fill=(16, 8, 34))
sd.rectangle([128, 330, 384, 380], fill=(30, 10, 60))                # ground
for k in range(-6, 7):                                                # grid lines
    sd.line([(256 + k * 12, 330), (256 + k * 60, 380)], fill=VIOLET, width=3)
for y in (338, 350, 366):
    sd.line([(128, y), (384, y)], fill=VIOLET, width=3)
for y in range(170, 380, 8):                                          # scanlines
    sd.line([(128, y), (384, y)], fill=(0, 0, 0), width=3)
mask = Image.new("L", (S, S)); ImageDraw.Draw(mask).rounded_rectangle(screen, 40, fill=255)
img = Image.composite(scr, img, mask)

# antennas (cyan), body (pink), knobs (cyan)
add_neon(lambda dr: (dr.line([(256, 120), (176, 48)], fill=255, width=14),
                     dr.line([(256, 120), (336, 48)], fill=255, width=14),
                     dr.ellipse([162, 34, 190, 62], fill=255), dr.ellipse([322, 34, 350, 62], fill=255)), CYAN, blur=16)
add_neon(lambda dr: dr.rounded_rectangle([84, 126, 428, 424], 56, outline=255, width=22), PINK, blur=26, strength=1.3)
add_neon(lambda dr: dr.rounded_rectangle(screen, 40, outline=255, width=8), HOT, blur=10)
add_neon(lambda dr: (dr.rectangle([196, 424, 222, 462], fill=255), dr.rectangle([290, 424, 316, 462], fill=255)), PINK, blur=12)

# shrink the art so round minimap masks don't clip the antennas
final = Image.new("RGB", (S, S)); fd = ImageDraw.Draw(final)
for y in range(S):
    t = y / S
    fd.line([(0, y), (S, y)], fill=tuple(int(BG1[i] + (BG2[i] - BG1[i]) * t) for i in range(3)))
k = 0.8; n = int(S * k); off = (S - n) // 2
final.paste(img.resize((n, n), Image.LANCZOS), (off, off + 10))
img = final
icon = img.resize((64, 64), Image.LANCZOS)
icon.convert("RGBA").save("Retrovision/media/icon.tga")
img.resize((256, 256), Image.LANCZOS).save("/tmp/retrovision_icon_preview.png")
img.resize((400, 400), Image.LANCZOS).save("curseforge/logo.png")   # CurseForge project logo
