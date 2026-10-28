"""Draws the cover image for the Paus company page on LinkedIn.

LinkedIn shows a company cover at 1128 x 191 and puts the logo over its bottom left corner, so that corner
is left empty. The image is drawn at four times that size and scaled down, which keeps every edge and
letter sharp, and is saved at 2x and 1x.

Run from the repository root: python3 Brand/make_linkedin.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import BLACK, BOLD, MINT, ORANGE, OUT, PINK, SEMI, VIOLET, WHITE, app_icon, font, gradient_text, pip, rounded

HERE = os.path.dirname(os.path.abspath(__file__))
MONO = os.path.join(HERE, "fonts", "JetBrainsMono-Medium.ttf")
MONO_BOLD = os.path.join(HERE, "fonts", "JetBrainsMono-Bold.ttf")

BASE_W, BASE_H = 1128, 191
K = 4  # Drawing scale: four times LinkedIn's size.
W, H = BASE_W * K, BASE_H * K

INK = (7, 6, 15)
GREY = (185, 180, 214)
DIM = (120, 115, 150)


def u(value):
    """Base units (LinkedIn pixels) to drawing pixels."""
    return int(round(value * K))


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def blurred_ellipse(img, cx, cy, rx, ry, color, alpha, blur):
    glow = layer()
    ImageDraw.Draw(glow).ellipse([u(cx - rx), u(cy - ry), u(cx + rx), u(cy + ry)], fill=(*color, alpha))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(u(blur))))


def background():
    img = Image.new("RGBA", (W, H), (*INK, 255))
    # Aurora: violet behind the words, pink and orange behind the product, a touch of mint by Pip.
    blurred_ellipse(img, 330, 30, 260, 120, VIOLET, 95, 70)
    blurred_ellipse(img, 880, 175, 230, 110, PINK, 80, 70)
    blurred_ellipse(img, 1080, 20, 150, 90, ORANGE, 50, 60)
    blurred_ellipse(img, 1040, 70, 70, 50, MINT, 45, 40)

    # A dot grid that fades out towards the edges.
    dots = layer()
    d = ImageDraw.Draw(dots)
    step, r = 12, 0.7
    for y in range(6, BASE_H, step):
        for x in range(6, BASE_W, step):
            d.ellipse([u(x - r), u(y - r), u(x + r), u(y + r)], fill=(255, 255, 255, 255))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    distance = np.sqrt(((xx - u(720)) / u(560)) ** 2 + ((yy - u(95)) / u(150)) ** 2)
    fade = np.clip(1 - distance, 0, 1) ** 1.4 * 0.16
    alpha = np.array(dots.getchannel("A"), np.float32) * fade
    dots.putalpha(Image.fromarray(alpha.astype(np.uint8)))
    img.alpha_composite(dots)

    # A thin line of light along the top edge.
    line = np.zeros((u(1.2), W, 4), np.uint8)
    t = np.linspace(0, 1, W)
    colors = np.stack([np.interp(t, [0, 0.5, 1], [VIOLET[c], PINK[c], ORANGE[c]]) for c in range(3)], -1)
    line[..., :3] = colors.astype(np.uint8)
    line[..., 3] = (np.sin(np.pi * t) * 170).astype(np.uint8)
    img.alpha_composite(Image.fromarray(line, "RGBA"), (0, 0))
    return img


def text(img, xy, s, path, size, fill, anchor="la", spacing=0):
    d = ImageDraw.Draw(img)
    f = font(path, u(size))
    if not spacing:
        d.text((u(xy[0]), u(xy[1])), s, font=f, fill=fill, anchor=anchor)
        return d.textlength(s, font=f) / K
    # Letter-spaced, for small capitals.
    x = u(xy[0])
    for ch in s:
        d.text((x, u(xy[1])), ch, font=f, fill=fill, anchor=anchor)
        x += d.textlength(ch, font=f) + u(spacing)
    return (x - u(xy[0])) / K


def headline(img, x, y):
    # A pill above the headline.
    pill = layer()
    d = ImageDraw.Draw(pill)
    label = "NOW ON THE APP STORE"
    f = font(MONO_BOLD, u(9))
    width = sum(d.textlength(ch, font=f) + u(1.6) for ch in label) / K + 34
    d.rounded_rectangle([u(x), u(y), u(x + width), u(y + 21)], u(10.5), fill=(255, 255, 255, 14), outline=(255, 255, 255, 46), width=u(0.8))
    img.alpha_composite(pill)
    blurred_ellipse(img, x + 13, y + 10.5, 6, 6, MINT, 160, 3)
    ImageDraw.Draw(img).ellipse([u(x + 10), u(y + 7.5), u(x + 16), u(y + 13.5)], fill=MINT)
    text(img, (x + 23, y + 10.8), label, MONO_BOLD, 9, (225, 222, 240), anchor="lm", spacing=1.6)

    # The headline: white, then the brand gradient.
    text(img, (x - 1.5, y + 29), "The off switch", BLACK, 38, WHITE)
    word = gradient_text("for doomscrolling.", u(38))
    img.alpha_composite(word, (u(x - 1.5), u(y + 74)))

    # What it is built on, in monospace for the engineers.
    tags = ["on-device AI", "zero tracking", "built in Stockholm"]
    cx = x
    ty = y + 128
    for i, tag in enumerate(tags):
        if i:
            cx += text(img, (cx, ty), "  /  ", MONO, 11.5, (95, 90, 130))
        cx += text(img, (cx, ty), tag, MONO, 11.5, GREY)


def shadow(img, box, radius, alpha=150, blur=14, offset=8):
    s = layer()
    x0, y0, x1, y1 = box
    ImageDraw.Draw(s).rounded_rectangle([u(x0), u(y0 + offset), u(x1), u(y1 + offset)], u(radius), fill=(0, 0, 0, alpha))
    img.alpha_composite(s.filter(ImageFilter.GaussianBlur(u(blur))))


def terminal(img, x, y, w, h):
    shadow(img, (x, y, x + w, y + h), 12, alpha=170, blur=16, offset=10)
    card = layer()
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([u(x), u(y), u(x + w), u(y + h)], u(12), fill=(14, 12, 28, 238), outline=(255, 255, 255, 34), width=u(0.8))
    img.alpha_composite(card)
    # Title bar, rounded only at the top.
    bar = layer()
    d = ImageDraw.Draw(bar)
    d.rounded_rectangle([u(x + 0.8), u(y + 0.8), u(x + w - 0.8), u(y + 23)], u(11.5), fill=(255, 255, 255, 11))
    d.rectangle([u(x + 0.8), u(y + 12), u(x + w - 0.8), u(y + 23)], fill=(255, 255, 255, 11))
    d.line([u(x + 0.8), u(y + 23), u(x + w - 0.8), u(y + 23)], fill=(255, 255, 255, 26), width=u(0.6))
    img.alpha_composite(bar)
    d = ImageDraw.Draw(img)
    for i, color in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        cx = x + 14 + i * 13
        d.ellipse([u(cx - 3.8), u(y + 11.5 - 3.8), u(cx + 3.8), u(y + 11.5 + 3.8)], fill=color)
    text(img, (x + w / 2, y + 11.8), "~/paus — zsh", MONO, 8.5, DIM, anchor="mm")

    lx, ly, lh = x + 15, y + 33, 21
    size = 12.5
    cx = lx + text(img, (lx, ly), "$ ", MONO_BOLD, size, MINT)
    cx += text(img, (cx, ly), "paus focus ", MONO, size, WHITE)
    text(img, (cx, ly), "--steps 2000", MONO, size, (255, 180, 120))
    cx = lx + text(img, (lx, ly + lh), "✓ ", MONO_BOLD, size, MINT)
    text(img, (cx, ly + lh), "6 apps paused", MONO, size, GREY)
    cx = lx + text(img, (lx, ly + 2 * lh), "→ ", MONO_BOLD, size, (255, 120, 190))
    cx += text(img, (cx, ly + 2 * lh), "walk to unlock", MONO, size, WHITE)
    d = ImageDraw.Draw(img)
    d.rectangle([u(cx + 3), u(ly + 2 * lh + 1), u(cx + 10), u(ly + 2 * lh + 16)], fill=(255, 255, 255, 220))


def live_activity(img, x, y, w, h):
    """The step session as it shows on the Lock Screen."""
    shadow(img, (x, y, x + w, y + h), 18, alpha=190, blur=14, offset=8)
    # Frosted glass: blur what is behind the card.
    box = (u(x), u(y), u(x + w), u(y + h))
    behind = img.crop(box).filter(ImageFilter.GaussianBlur(u(8)))
    mask = Image.new("L", behind.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, behind.width - 1, behind.height - 1], u(18), fill=255)
    img.paste(behind, box[:2], mask)
    card = layer()
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([u(x), u(y), u(x + w), u(y + h)], u(18), fill=(30, 26, 52, 200), outline=(255, 255, 255, 52), width=u(0.8))
    img.alpha_composite(card)

    icon = rounded(app_icon(u(42)).convert("RGB"))
    img.alpha_composite(icon, (u(x + 13), u(y + (h - 42) / 2)))
    tx = x + 66
    text(img, (tx, y + 12), "Step session", BOLD, 14, WHITE)
    text(img, (tx, y + 32), "450 of 2,000 steps", SEMI, 10.5, GREY)
    # Progress.
    bar = layer()
    d = ImageDraw.Draw(bar)
    bx0, by, bx1 = tx, y + 52, tx + 112
    d.rounded_rectangle([u(bx0), u(by), u(bx1), u(by + 5.5)], u(2.75), fill=(255, 255, 255, 30))
    img.alpha_composite(bar)
    fill = gradient_bar(u(bx1 - bx0) * 450 // 2000 + u(5), u(5.5))
    img.alpha_composite(fill, (u(bx0), u(by)))
    number = gradient_text("1,550", u(27))
    img.alpha_composite(number, (u(x + w - 15) - number.width, u(y + 11)))
    text(img, (x + w - 15, y + 46), "steps left", SEMI, 10, GREY, anchor="ra")


def gradient_bar(width, height):
    t = np.linspace(0, 1, max(width, 1))
    colors = np.stack([np.interp(t, [0, 0.55, 1], [VIOLET[c], PINK[c], ORANGE[c]]) for c in range(3)], -1)
    bar = np.zeros((height, max(width, 1), 4), np.uint8)
    bar[..., :3] = colors.astype(np.uint8)
    bar[..., 3] = 255
    img = Image.fromarray(bar, "RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], height // 2, fill=255)
    img.putalpha(mask)
    return img


def pip_on_top(img, cx, cy, size):
    blurred_ellipse(img, cx, cy, size * 0.75, size * 0.6, MINT, 90, size * 0.35)
    p = pip(u(size))
    img.alpha_composite(p, (u(cx) - p.width // 2, u(cy) - p.height // 2))


def grain(img, amount=5):
    rgb = np.array(img.convert("RGB"), np.int16)
    noise = np.random.default_rng(7).normal(0, amount, rgb.shape[:2])[..., None]
    return Image.fromarray(np.clip(rgb + noise, 0, 255).astype(np.uint8), "RGB")


def company_cover():
    img = background()
    headline(img, 248, 14)
    terminal(img, 694, 14, 262, 112)
    live_activity(img, 806, 112, 300, 72)
    pip_on_top(img, 950, 26, 46)
    return grain(img)


def main():
    img = company_cover()
    folder = os.path.join(OUT, "social", "en")
    os.makedirs(folder, exist_ok=True)
    img.resize((BASE_W * 2, BASE_H * 2), Image.LANCZOS).save(os.path.join(folder, "linkedin-company-cover-2256x382.png"), optimize=True)
    img.resize((BASE_W, BASE_H), Image.LANCZOS).save(os.path.join(folder, "linkedin-company-cover-1128x191.png"), optimize=True)


if __name__ == "__main__":
    main()
