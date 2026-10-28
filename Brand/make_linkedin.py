"""Draws the cover image for the Paus company page on LinkedIn.

A clean, technical look: black, hairline grid, restrained type, one chart. LinkedIn shows a company cover
at 1128 x 191 and puts the logo over its bottom left corner, so that corner stays empty. The image is
drawn at four times that size and scaled down, which keeps hairlines and letters sharp, and is saved at
2x and 1x.

Run from the repository root: python3 Brand/make_linkedin.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import FONTS, MINT, ORANGE, OUT, PINK, VIOLET, font

HERE = os.path.dirname(os.path.abspath(__file__))
MONO = os.path.join(HERE, "fonts", "JetBrainsMono-Medium.ttf")
MONO_BOLD = os.path.join(HERE, "fonts", "JetBrainsMono-Bold.ttf")
DISPLAY = f"{FONTS}/InterDisplay-SemiBold.otf"
DISPLAY_MEDIUM = f"{FONTS}/InterDisplay-Medium.otf"

BASE_W, BASE_H = 1128, 191
K = 4  # Drawing scale: four times LinkedIn's size.
W, H = BASE_W * K, BASE_H * K
HAIR = 0.5  # A hairline: one pixel in the 2x image.

BG = (5, 5, 8)
WHITE = (242, 242, 246)
GREY = (128, 128, 140)
FAINT = (88, 88, 100)

# The illustrated 8-week goal: from 6h 12m a day down to 3h 04m, half the screen time.
WEEKS = [6.2, 5.95, 5.4, 4.85, 4.3, 3.8, 3.4, 3.07]


def u(value):
    """Base units (LinkedIn pixels) to drawing pixels."""
    return int(round(value * K))


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def text(img, xy, s, path, size, fill, anchor="la", spacing=0.0):
    """Draws `s`, letter-spaced by `spacing` base units when given, and returns its width in base units."""
    d = ImageDraw.Draw(img)
    f = font(path, u(size))
    if not spacing:
        d.text((u(xy[0]), u(xy[1])), s, font=f, fill=fill, anchor=anchor)
        return d.textlength(s, font=f) / K
    width = sum(d.textlength(ch, font=f) for ch in s) + u(spacing) * (len(s) - 1)
    x = u(xy[0]) - (width if anchor[0] == "r" else 0)
    for ch in s:
        d.text((x, u(xy[1])), ch, font=f, fill=fill, anchor="l" + anchor[1])
        x += d.textlength(ch, font=f) + u(spacing)
    return width / K


def radial_fade(cx, cy, rx, ry, power=1.6):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    distance = np.sqrt(((xx - u(cx)) / u(rx)) ** 2 + ((yy - u(cy)) / u(ry)) ** 2)
    return np.clip(1 - distance, 0, 1) ** power


def with_alpha(img, fade, strength):
    alpha = np.array(img.getchannel("A"), np.float32) * fade * strength
    img.putalpha(Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8)))
    return img


def background():
    img = Image.new("RGBA", (W, H), (*BG, 255))

    # An engineering grid, strongest behind the chart and fading towards the edges.
    grid = layer()
    d = ImageDraw.Draw(grid)
    step = 24
    for x in range(0, BASE_W + 1, step):
        d.line([(u(x), 0), (u(x), H)], fill=(255, 255, 255, 255), width=u(HAIR))
    for y in range(-1, BASE_H + 1, step):
        d.line([(0, u(y)), (W, u(y))], fill=(255, 255, 255, 255), width=u(HAIR))
    img.alpha_composite(with_alpha(grid, radial_fade(820, 95, 520, 170, 1.2), 0.07))

    # Registration crosses on a few grid points.
    marks = layer()
    d = ImageDraw.Draw(marks)
    for x, y in [(96, 23), (672, 23), (672, 167)]:
        d.line([(u(x - 4), u(y)), (u(x + 4), u(y))], fill=(255, 255, 255, 120), width=u(HAIR))
        d.line([(u(x), u(y - 4)), (u(x), u(y + 4))], fill=(255, 255, 255, 120), width=u(HAIR))
    # Corner brackets, like the frame of an instrument.
    for cx, cy, sx, sy in [(10, 10, 1, 1), (BASE_W - 10, 10, -1, 1), (BASE_W - 10, BASE_H - 10, -1, -1)]:
        d.line([(u(cx), u(cy)), (u(cx + 10 * sx), u(cy))], fill=(255, 255, 255, 110), width=u(HAIR))
        d.line([(u(cx), u(cy)), (u(cx), u(cy + 10 * sy))], fill=(255, 255, 255, 110), width=u(HAIR))
    img.alpha_composite(marks)

    # A barely-there light from above the headline, so the black has depth.
    light = layer()
    ImageDraw.Draw(light).ellipse([u(150), u(-140), u(760), u(120)], fill=(120, 110, 200, 40))
    img.alpha_composite(light.filter(ImageFilter.GaussianBlur(u(60))))

    # The only colour in the frame: a hairline of the brand gradient along the top.
    t = np.linspace(0, 1, W)
    line = np.zeros((u(HAIR), W, 4), np.uint8)
    line[..., :3] = np.stack([np.interp(t, [0, 0.5, 1], [VIOLET[c], PINK[c], ORANGE[c]]) for c in range(3)], -1).astype(np.uint8)
    line[..., 3] = (np.clip(np.sin(np.pi * t) * 1.4, 0, 1) * 200).astype(np.uint8)
    img.alpha_composite(Image.fromarray(line, "RGBA"), (0, 0))
    return img


def headline(img, x, y):
    # Status line.
    glow = layer()
    ImageDraw.Draw(glow).ellipse([u(x - 1), u(y + 1), u(x + 7), u(y + 9)], fill=(*MINT, 150))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(u(2.5))))
    d = ImageDraw.Draw(img)
    d.ellipse([u(x + 0.8), u(y + 2.8), u(x + 5.2), u(y + 7.2)], fill=MINT)
    cx = x + 12
    cx += text(img, (cx, y + 5), "LIVE ON THE APP STORE", MONO_BOLD, 9, (210, 210, 220), anchor="lm", spacing=1.7)
    cx += text(img, (cx + 10, y + 5), "/", MONO, 9, FAINT, anchor="lm") + 20
    text(img, (cx, y + 5), "STOCKHOLM, SE", MONO_BOLD, 9, GREY, anchor="lm", spacing=1.7)

    # Two lines, white then grey: confident, quiet type.
    text(img, (x - 1.5, y + 20), "The off switch", DISPLAY, 37, WHITE)
    text(img, (x - 1.5, y + 62), "for doomscrolling.", DISPLAY, 37, (108, 108, 122))

    # What it is built on.
    tags = ["Screen Time API", "On-device intelligence", "Zero tracking"]
    cx = x
    for i, tag in enumerate(tags):
        if i:
            cx += text(img, (cx, y + 121), "  ·  ", MONO, 10.5, FAINT)
        cx += text(img, (cx, y + 121), tag, MONO, 10.5, GREY)


def smooth(points, samples=24):
    """A Catmull-Rom curve through `points`."""
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (np.array(p, float) for p in pts[i - 1:i + 3])
        for s in range(samples):
            t = s / samples
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ** 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(np.array(points[-1], float))
    return [tuple(p) for p in out]


def chart(img, x0, y0, x1, y1):
    top_hours = 7.0

    def py(hours):
        return y1 - hours / top_hours * (y1 - y0)

    # Gridlines and their labels.
    rules = layer()
    rd = ImageDraw.Draw(rules)
    for hours in (2, 4, 6):
        rd.line([(u(x0), u(py(hours))), (u(x1), u(py(hours)))], fill=(255, 255, 255, 22), width=u(HAIR))
        text(img, (x0 - 8, py(hours)), f"{hours}h", MONO, 8.5, FAINT, anchor="rm")
    rd.line([(u(x0), u(y1)), (u(x1), u(y1))], fill=(255, 255, 255, 60), width=u(HAIR))
    img.alpha_composite(rules)
    text(img, (x0, y1 + 9), "W1", MONO, 8.5, FAINT, anchor="lm")
    text(img, (x1, y1 + 9), "W8", MONO, 8.5, FAINT, anchor="rm")

    xs = np.linspace(x0, x1, len(WEEKS))
    points = [(float(x), py(h)) for x, h in zip(xs, WEEKS)]
    curve = smooth(points)

    # A soft fill under the line, fading towards the axis.
    fill = layer()
    ImageDraw.Draw(fill).polygon([(u(px), u(qy)) for px, qy in curve] + [(u(x1), u(y1)), (u(x0), u(y1))], fill=(255, 255, 255, 255))
    rows = np.arange(H, dtype=np.float32)[:, None]
    vertical = np.clip((u(y1) - rows) / (u(y1) - u(y0)), 0, 1) * np.ones((1, W), np.float32)
    img.alpha_composite(with_alpha(fill, vertical, 0.07))

    # The line itself.
    line = layer()
    ImageDraw.Draw(line).line([(u(px), u(qy)) for px, qy in curve], fill=WHITE, width=u(1.2), joint="curve")
    img.alpha_composite(line)

    # Week ticks along the line.
    d = ImageDraw.Draw(img)
    for px, qy in points[1:-1]:
        d.ellipse([u(px - 1.3), u(qy - 1.3), u(px + 1.3), u(qy + 1.3)], fill=BG, outline=(200, 200, 210), width=u(HAIR))

    # Start: a hollow point and today's number.
    sx, sy = points[0]
    d.ellipse([u(sx - 2.2), u(sy - 2.2), u(sx + 2.2), u(sy + 2.2)], fill=BG, outline=WHITE, width=u(0.8))
    text(img, (sx + 7, sy - 9), "6h 12m", MONO, 9, GREY, anchor="lm")

    # End: the goal, marked in the brand pink.
    ex, ey = points[-1]
    halo = layer()
    ImageDraw.Draw(halo).ellipse([u(ex - 9), u(ey - 9), u(ex + 9), u(ey + 9)], fill=(*PINK, 70))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(u(3))))
    d = ImageDraw.Draw(img)
    d.ellipse([u(ex - 6), u(ey - 6), u(ex + 6), u(ey + 6)], outline=(*PINK, 200), width=u(HAIR))
    d.ellipse([u(ex - 2.6), u(ey - 2.6), u(ex + 2.6), u(ey + 2.6)], fill=PINK)
    text(img, (ex - 12, ey - 13), "3h 04m", MONO_BOLD, 9, WHITE, anchor="rm")

    # The headline number, above the plot on the right.
    text(img, (x1, y0 - 62), "−50%", DISPLAY_MEDIUM, 30, WHITE, anchor="ra")
    text(img, (x1, y0 - 20), "DAILY SCREEN TIME · 8-WEEK GOAL", MONO_BOLD, 7.5, GREY, anchor="rm", spacing=1.2)


def grain(img, amount=3.0):
    rgb = np.array(img.convert("RGB"), np.int16)
    noise = np.random.default_rng(7).normal(0, amount, rgb.shape[:2])[..., None]
    return Image.fromarray(np.clip(rgb + noise, 0, 255).astype(np.uint8), "RGB")


def company_cover():
    img = background()
    headline(img, 248, 26)
    chart(img, 742, 76, 1080, 150)
    text(img, (BASE_W - 24, BASE_H - 15), "59.3293° N  18.0686° E", MONO, 7.5, FAINT, anchor="rm", spacing=0.6)
    return grain(img)


def main():
    img = company_cover()
    folder = os.path.join(OUT, "social", "en")
    os.makedirs(folder, exist_ok=True)
    img.resize((BASE_W * 2, BASE_H * 2), Image.LANCZOS).save(os.path.join(folder, "linkedin-company-cover-2256x382.png"), optimize=True)
    img.resize((BASE_W, BASE_H), Image.LANCZOS).save(os.path.join(folder, "linkedin-company-cover-1128x191.png"), optimize=True)


if __name__ == "__main__":
    main()
