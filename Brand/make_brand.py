"""Draws the Paus brand kit: logos, profile pictures, banners and a brand sheet.

Run from the repository root: python3 Brand/make_brand.py
Needs Pillow, NumPy and the Inter fonts (Inter Display Black/Bold, Inter SemiBold).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)))
FONTS = "/usr/share/fonts/opentype/inter"
BLACK = f"{FONTS}/InterDisplay-Black.otf"
BOLD = f"{FONTS}/InterDisplay-Bold.otf"
SEMI = f"{FONTS}/Inter-SemiBold.otf"

# The app's palette (Paus/Design/Theme.swift).
BG = (14, 11, 31)
CARD = (27, 22, 54)
VIOLET = (139, 92, 255)
PINK = (255, 79, 163)
ORANGE = (255, 181, 71)
MINT = (60, 240, 176)
CYAN = (56, 200, 240)
INK = (20, 16, 40)
WHITE = (255, 255, 255)

TAGLINE = {"sv": "Ta tillbaka din tid.", "en": "Take back your time."}
SUBLINE = {"sv": "Pip blockerar TikTok, Instagram och YouTube åt dig.", "en": "Pip blocks TikTok, Instagram and YouTube for you."}
SOON = {"sv": "Snart i App Store", "en": "Coming soon to the App Store"}


def font(path, size):
    return ImageFont.truetype(path, size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def brand_gradient(w, h, angle_flip=False):
    """Violet → pink → orange along the diagonal, like the app icon."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (x / max(w - 1, 1) + y / max(h - 1, 1)) / 2
    if angle_flip:
        t = 1 - t
    img = np.zeros((h, w, 3), np.float32)
    stops = [(0.0, VIOLET), (0.55, PINK), (1.0, ORANGE)]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        mask = (t >= t0) & (t <= t1)
        k = ((t - t0) / (t1 - t0))[mask]
        for i in range(3):
            img[..., i][mask] = c0[i] + (c1[i] - c0[i]) * k
    # A soft light in the middle, as on the icon.
    cy, cx = h / 2, w / 2
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (0.6 * min(w, h))
    glow = np.clip(1 - r, 0, 1) ** 2 * 0.35
    img = img + (255 - img) * glow[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def dark_backdrop(w, h):
    """The app's dark background with violet and pink light in the corners."""
    img = Image.new("RGB", (w, h), BG)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    s = min(w, h)
    d.ellipse([-0.3 * s, -0.6 * s, 0.9 * s, 0.6 * s], fill=(*VIOLET, 110))
    d.ellipse([w - 0.8 * s, h - 0.5 * s, w + 0.4 * s, h + 0.7 * s], fill=(*PINK, 90))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.25))
    img.paste(glow, (0, 0), glow)
    return img


def pip(size, mood="happy"):
    """Pip on a transparent background, drawn at 4x and scaled down for smooth edges."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    cx = cy = s / 2
    r = s * 0.46
    # Body: mint to cyan, top to bottom, inside a white rim.
    body = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    grad = np.zeros((s, s, 4), np.uint8)
    for row in range(s):
        c = lerp(MINT, CYAN, row / (s - 1))
        grad[row, :, :3] = c
        grad[row, :, 3] = 255
    body = Image.fromarray(grad, "RGBA")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r * 0.96, cx + r, cy + r * 0.96], fill=255)
    rim = Image.new("L", (s, s), 0)
    rr = r * 1.035
    ImageDraw.Draw(rim).ellipse([cx - rr, cy - rr * 0.96, cx + rr, cy + rr * 0.96], fill=255)
    img.paste(Image.new("RGBA", (s, s), (*WHITE, 255)), (0, 0), rim)
    img.paste(body, (0, 0), mask)
    d = ImageDraw.Draw(img)
    # Eyes
    for sx in (-1, 1):
        ex, ey = cx + sx * r * 0.36, cy - r * 0.12
        er = r * 0.22
        d.ellipse([ex - er, ey - er * 1.05, ex + er, ey + er * 1.05], fill=WHITE)
        pr = er * 0.52
        d.ellipse([ex - pr, ey - pr, ex + pr, ey + pr], fill=INK)
        hr = er * 0.17
        d.ellipse([ex + er * 0.18 - hr, ey - er * 0.32 - hr, ex + er * 0.18 + hr, ey - er * 0.32 + hr], fill=WHITE)
        # Cheeks
        bx, by = cx + sx * r * 0.62, cy + r * 0.26
        d.ellipse([bx - r * 0.15, by - r * 0.09, bx + r * 0.15, by + r * 0.09], fill=(255, 140, 190))
    # Smile
    w = s * 0.022
    if mood == "happy":
        d.arc([cx - r * 0.27, cy + r * 0.12, cx + r * 0.27, cy + r * 0.52], 25, 155, fill=INK, width=int(w))
    else:  # wink-free "hyped": open mouth
        d.chord([cx - r * 0.22, cy + r * 0.18, cx + r * 0.22, cy + r * 0.55], 0, 180, fill=INK)
    return img.resize((size, size), Image.LANCZOS)


def rounded(img, radius_ratio=0.2237):
    """App-icon style rounded corners on a transparent background."""
    w, h = img.size
    mask = Image.new("L", (w * 4, h * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w * 4 - 1, h * 4 - 1], int(w * 4 * radius_ratio), fill=255)
    mask = mask.resize((w, h), Image.LANCZOS)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def app_icon(size=1024):
    img = brand_gradient(size, size).convert("RGBA")
    p = pip(int(size * 0.56))
    img.alpha_composite(p, ((size - p.width) // 2, (size - p.height) // 2))
    return img


def gradient_text(text, size, path=BLACK):
    """Text filled with the brand gradient, on a transparent background."""
    f = font(path, size)
    l, t, r, b = f.getbbox(text)
    w, h = r - l + 8, b - t + 8
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((-l + 4, -t + 4), text, font=f, fill=255)
    fill = brand_gradient(w, h).convert("RGBA")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(fill, (0, 0), mask)
    return out


def plain_text(text, size, color, path=BLACK):
    f = font(path, size)
    l, t, r, b = f.getbbox(text)
    w, h = r - l + 8, b - t + 8
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(out).text((-l + 4, -t + 4), text, font=f, fill=color)
    return out


def lockup(height, text_color=None):
    """Rounded icon and the word Paus side by side."""
    icon = rounded(app_icon(height))
    word = gradient_text("Paus", int(height * 0.78)) if text_color is None else plain_text("Paus", int(height * 0.78), text_color)
    gap = int(height * 0.28)
    out = Image.new("RGBA", (icon.width + gap + word.width, height), (0, 0, 0, 0))
    out.alpha_composite(icon, (0, 0))
    out.alpha_composite(word, (icon.width + gap, (height - word.height) // 2 + int(height * 0.02)))
    return out


def paste_center(canvas, img, cx, cy):
    canvas.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))


def banner(w, h, lang, safe=None, left=None):
    """Dark banner: Pip with a glow, the lockup and the tagline, kept inside `safe` (w, h) when given.

    `left` moves the content right, for sites whose profile picture covers the banner's left corner.
    """
    img = dark_backdrop(w, h).convert("RGBA")
    sw, sh = safe or (w, h)
    left = (w - sw) / 2 if left is None else left
    cy = h / 2
    unit = sh
    # Pip with a pink glow on the left.
    psize = int(unit * 0.78)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gx = left + sw * 0.16
    ImageDraw.Draw(glow).ellipse([gx - psize * 0.7, cy - psize * 0.7, gx + psize * 0.7, cy + psize * 0.7], fill=(*PINK, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(psize * 0.25)))
    paste_center(img, pip(psize), gx, cy)
    # Text block
    tx = left + sw * 0.33
    word = gradient_text("Paus", int(unit * 0.34))
    img.alpha_composite(word, (int(tx), int(cy - unit * 0.36)))
    tag = plain_text(TAGLINE[lang], int(unit * 0.13), WHITE, BOLD)
    img.alpha_composite(tag, (int(tx), int(cy + unit * 0.02)))
    sub = plain_text(SUBLINE[lang], int(unit * 0.065), (200, 195, 230), SEMI)
    if tx + sub.width > left + sw - unit * 0.05:
        scale = (left + sw - unit * 0.05 - tx) / sub.width
        sub = sub.resize((int(sub.width * scale), int(sub.height * scale)), Image.LANCZOS)
    img.alpha_composite(sub, (int(tx), int(cy + unit * 0.2)))
    return img.convert("RGB")


def profile_picture(size=1080):
    """Pip on the gradient, sized so a round crop never cuts it."""
    img = brand_gradient(size, size).convert("RGBA")
    p = pip(int(size * 0.6))
    paste_center(img, p, size / 2, size / 2)
    return img.convert("RGB")


def launch_post(lang, w=1080, h=1350):
    img = dark_backdrop(w, h).convert("RGBA")
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([w / 2 - 330, 300, w / 2 + 330, 960], fill=(*PINK, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(110)))
    paste_center(img, pip(520), w / 2, 600)
    word = gradient_text("Paus", 190)
    paste_center(img, word, w / 2, 1000)
    tag = plain_text(TAGLINE[lang], 66, WHITE, BOLD)
    paste_center(img, tag, w / 2, 1130)
    pill_text = plain_text(SOON[lang], 40, WHITE, BOLD)
    pw, ph = pill_text.width + 80, pill_text.height + 44
    pill = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    mask = Image.new("L", (pw * 4, ph * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pw * 4 - 1, ph * 4 - 1], ph * 2, fill=255)
    pill.paste(brand_gradient(pw, ph).convert("RGBA"), (0, 0), mask.resize((pw, ph), Image.LANCZOS))
    paste_center(pill, pill_text, pw / 2, ph / 2)
    paste_center(img, pill, w / 2, 1240)
    top = plain_text("6 h/dag = 25 år av ditt vakna liv." if lang == "sv" else "6 h a day = 25 years of your waking life.", 44, (200, 195, 230), SEMI)
    paste_center(img, top, w / 2, 150)
    return img.convert("RGB")


def brand_sheet():
    w, h = 2400, 1500
    img = dark_backdrop(w, h).convert("RGBA")
    d = ImageDraw.Draw(img)
    title = plain_text("Paus – varumärke", 84, WHITE, BLACK)
    img.alpha_composite(title, (120, 100))
    img.alpha_composite(rounded(app_icon(360)), (120, 260))
    img.alpha_composite(lockup(200), (560, 340))
    label = font(SEMI, 34)
    d.text((120, 660), "Färger", font=font(BOLD, 52), fill=WHITE)
    swatches = [("Violett", VIOLET), ("Rosa", PINK), ("Orange", ORANGE), ("Mint", MINT), ("Bakgrund", BG), ("Kort", CARD)]
    for i, (name, color) in enumerate(swatches):
        x = 120 + i * 360
        d.rounded_rectangle([x, 750, x + 320, 990], 36, fill=color, outline=(255, 255, 255, 60), width=2)
        d.text((x, 1010), name, font=label, fill=WHITE)
        d.text((x, 1055), "#%02X%02X%02X" % color, font=label, fill=(200, 195, 230))
    d.text((120, 1170), "Typsnitt", font=font(BOLD, 52), fill=WHITE)
    d.text((120, 1250), "Rubriker: Inter Display Black · Text: Inter SemiBold · I appen: SF Pro Rounded", font=label, fill=(200, 195, 230))
    d.text((120, 1310), "Slogan: Ta tillbaka din tid. / Take back your time.", font=label, fill=(200, 195, 230))
    img.alpha_composite(pip(420), (w - 560, 230))
    return img.convert("RGB")


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print(os.path.relpath(path, OUT))


def main():
    icon = app_icon(1024)
    save(icon.convert("RGB"), "logos", "paus-app-icon-1024.png")
    save(rounded(icon), "logos", "paus-icon-rounded-1024.png")
    save(pip(1024), "logos", "pip-transparent-1024.png")
    save(gradient_text("Paus", 400), "logos", "paus-wordmark-gradient.png")
    save(plain_text("Paus", 400, WHITE), "logos", "paus-wordmark-white.png")
    save(plain_text("Paus", 400, INK), "logos", "paus-wordmark-dark.png")
    save(lockup(300), "logos", "paus-logo-for-dark-backgrounds.png")
    save(lockup(300, INK), "logos", "paus-logo-for-light-backgrounds.png")

    save(profile_picture(1080), "social", "profile-picture-1080.png")
    for lang in ("sv", "en"):
        save(banner(1500, 500, lang, safe=(1150, 440), left=330), "social", lang, "x-twitter-header-1500x500.png")
        save(banner(2560, 1440, lang, safe=(1546, 423)), "social", lang, "youtube-banner-2560x1440.png")
        save(banner(1584, 396, lang, safe=(1220, 360), left=340), "social", lang, "linkedin-cover-1584x396.png")
        save(banner(1640, 624, lang, safe=(1640, 480)), "social", lang, "facebook-cover-1640x624.png")
        save(launch_post(lang), "social", lang, "instagram-launch-post-1080x1350.png")
    save(brand_sheet(), "paus-brand-sheet.png")


if __name__ == "__main__":
    main()
