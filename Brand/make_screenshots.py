"""Draws App Store screenshots that show the Lock Screen: a notification from Pip and a focus session's Live Activity.

Run from the repository root: python3 Brand/make_screenshots.py
Uses the drawing helpers and palette from make_brand.py.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import (BG, BLACK, BOLD, CARD, MINT, PINK, SEMI, VIOLET, WHITE, app_icon, dark_backdrop, font, pip,
                        rounded, save)

# iPhone 6.9" display, the size App Store Connect asks for first.
W, H = 1290, 2796
GREY = (200, 195, 230)
DIM = (150, 145, 185)

HEADLINES = {
    "notification": {"sv": "Pip hejar på dig\nvarje dag", "en": "Pip cheers you on\nevery day"},
    "live": {"sv": "Fokuspasset syns\npå låsskärmen", "en": "Your focus, right on\nyour Lock Screen"},
}
DATE = {"sv": "torsdag 23 oktober", "en": "Thursday, October 23"}
NOW = {"sv": "nu", "en": "now"}
NOTIFICATION = {
    "sv": ("Snyggt jobbat, Aron! 🎉", "Du har vunnit tillbaka 4 h 20 min den här veckan. Pip är pigg och glad."),
    "en": ("Nice work, Aron! 🎉", "You've won back 4h 20m this week. Pip is happy and full of energy."),
}
WIDGETS = {
    "sv": [("7", "dagars svit"), ("85 %", "hälsa"), ("4", "nivå")],
    "en": [("7", "day streak"), ("85%", "health"), ("4", "level")],
}
LIVE = {
    "sv": ("Fokuspass", "Pip vaktar dina appar", "24:13", "kvar", "Pips hälsa 85 %"),
    "en": ("Focus session", "Pip is guarding your apps", "24:13", "left", "Pip's health 85%"),
}


def translucent(img, draw):
    """Draws on a separate layer so see-through fills blend with what is below instead of replacing it."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw(ImageDraw.Draw(layer))
    img.alpha_composite(layer)


def text(draw, xy, s, f, fill, anchor="la"):
    draw.text(xy, s, font=f, fill=fill, anchor=anchor)


def centered_lines(draw, lines, y, f, fill, gap):
    for line in lines.split("\n"):
        text(draw, (W / 2, y), line, f, fill, "ma")
        y += gap
    return y


def wrap(draw, s, f, width):
    """Splits `s` into lines no wider than `width`."""
    lines, line = [], ""
    for word in s.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=f) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def emoji_free(s):
    """Inter has no emoji, so they are drawn separately; this strips them from the text."""
    return s.replace(" 🎉", "")


def backdrop():
    img = dark_backdrop(W, H).convert("RGBA")
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([W * 0.1, H * 0.3, W * 0.9, H * 0.75], fill=(*VIOLET, 90))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(220)))
    return img


def phone(img, top):
    """A phone outline running off the bottom edge, with a lit Lock Screen inside. Returns the screen's box."""
    left, right = 150, W - 150
    radius = 150
    screen = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(screen)
    d.rounded_rectangle([left, top, right, H + radius], radius, fill=(*CARD, 255))
    # Lock Screen light: violet at the top fading to the app's background.
    light = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(light).ellipse([left - 200, top - 300, right + 200, top + 1100], fill=(*VIOLET, 120))
    light = light.filter(ImageFilter.GaussianBlur(160))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([left, top, right, H + radius], radius, fill=255)
    screen.alpha_composite(Image.composite(light, Image.new("RGBA", (W, H), (0, 0, 0, 0)), mask))
    img.alpha_composite(screen)
    # Frame with the brand gradient, violet to pink from top to bottom.
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle([left, top, right, H + radius], radius, outline=WHITE, width=16)
    grad = np.zeros((H, W, 4), np.uint8)
    t = np.linspace(0, 1, H)[:, None]
    for i, (a, b) in enumerate(zip(VIOLET, PINK)):
        grad[..., i] = (a + (b - a) * t).astype(np.uint8)
    grad[..., 3] = np.array(frame)[..., 3]
    img.alpha_composite(Image.fromarray(grad, "RGBA"))
    d = ImageDraw.Draw(img)
    # Dynamic Island
    d.rounded_rectangle([W / 2 - 115, top + 45, W / 2 + 115, top + 115], 35, fill=(0, 0, 0, 255))
    return left, top, right


def lock_clock(img, top, lang):
    d = ImageDraw.Draw(img)
    text(d, (W / 2, top + 210), DATE[lang], font(SEMI, 50), (*GREY, 255), "ma")
    text(d, (W / 2, top + 260), "9:41", font(BLACK, 300), (*WHITE, 235), "ma")


def card(img, box, radius=60):
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(shadow).rounded_rectangle([x0, y0 + 20, x1, y1 + 20], radius, fill=(0, 0, 0, 140))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(30)))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius, fill=(40, 34, 78, 235), outline=(255, 255, 255, 40), width=3)
    img.alpha_composite(layer)


def emoji(img, xy, size):
    """A small party popper drawn by hand, since the fonts have no emoji."""
    x, y = xy
    d = ImageDraw.Draw(img)
    d.polygon([(x, y + size), (x + size * 0.35, y + size * 0.2), (x + size * 0.8, y + size * 0.65)], fill=(255, 181, 71, 255))
    for dx, dy, c in [(0.55, 0.05, PINK), (0.85, 0.25, MINT), (0.95, 0.0, VIOLET), (0.7, 0.4, WHITE)]:
        r = size * 0.08
        d.ellipse([x + size * dx - r, y + size * dy - r, x + size * dx + r, y + size * dy + r], fill=(*c, 255))


def notification_shot(lang):
    img = backdrop()
    d = ImageDraw.Draw(img)
    centered_lines(d, HEADLINES["notification"][lang], 200, font(BLACK, 108), WHITE, 128)
    top = 620
    phone(img, top)
    lock_clock(img, top, lang)
    # The notification, a little wider than the phone so it stands out.
    x0, x1 = 90, W - 90
    y0 = top + 720
    title, body = NOTIFICATION[lang]
    body_font = font(SEMI, 46)
    lines = wrap(d, body, body_font, x1 - x0 - 300)
    y1 = y0 + 150 + len(lines) * 60
    card(img, (x0, y0, x1, y1))
    icon = rounded(app_icon(150).convert("RGB"))
    img.alpha_composite(icon, (x0 + 50, y0 + (y1 - y0 - 150) // 2))
    d = ImageDraw.Draw(img)
    tx = x0 + 240
    title_font = font(BOLD, 54)
    text(d, (tx, y0 + 50), emoji_free(title), title_font, WHITE)
    emoji(img, (tx + d.textlength(emoji_free(title), font=title_font) + 18, y0 + 52), 48)
    text(d, (x1 - 50, y0 + 58), NOW[lang], font(SEMI, 40), DIM, "ra")
    for i, line in enumerate(lines):
        text(d, (tx, y0 + 128 + i * 60), line, body_font, GREY)
    # Pip below, happy about it.
    p = pip(420)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gy = y1 + 520
    ImageDraw.Draw(glow).ellipse([W / 2 - 300, gy - 300, W / 2 + 300, gy + 300], fill=(*MINT, 70))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    img.alpha_composite(p, (int(W / 2 - 210), int(gy - 210)))
    return img.convert("RGB")


def live_shot(lang):
    img = backdrop()
    d = ImageDraw.Draw(img)
    centered_lines(d, HEADLINES["live"][lang], 200, font(BLACK, 108), WHITE, 128)
    top = 620
    phone(img, top)
    lock_clock(img, top, lang)
    title, subtitle, remaining, left_word, health = LIVE[lang]
    x0, x1 = 90, W - 90
    y0 = top + 720
    y1 = y0 + 470
    card(img, (x0, y0, x1, y1))
    img.alpha_composite(pip(190), (x0 + 50, y0 + 50))
    d = ImageDraw.Draw(img)
    tx = x0 + 280
    text(d, (tx, y0 + 62), title, font(BOLD, 58), WHITE)
    text(d, (tx, y0 + 140), subtitle, font(SEMI, 42), GREY)
    text(d, (x1 - 50, y0 + 48), remaining, font(BLACK, 92), PINK, "ra")
    text(d, (x1 - 50, y0 + 150), left_word, font(SEMI, 40), DIM, "ra")
    # Progress bar, a little over half way.
    by = y0 + 300
    translucent(img, lambda d: d.rounded_rectangle([x0 + 50, by, x1 - 50, by + 34], 17, fill=(255, 255, 255, 40)))
    fill_to = x0 + 50 + (x1 - x0 - 100) * 0.52
    bar = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(bar).rounded_rectangle([x0 + 50, by, fill_to, by + 34], 17, fill=WHITE)
    grad = np.zeros((H, W, 4), np.uint8)
    t = np.clip((np.arange(W) - (x0 + 50)) / max(fill_to - x0 - 50, 1), 0, 1)[None, :]
    for i, (a, b) in enumerate(zip(VIOLET, PINK)):
        grad[..., i] = (a + (b - a) * t).astype(np.uint8)
    grad[..., 3] = np.array(bar)[..., 3]
    img.alpha_composite(Image.fromarray(grad, "RGBA"))
    d = ImageDraw.Draw(img)
    hy = by + 70
    d.ellipse([x0 + 50, hy + 4, x0 + 86, hy + 40], fill=MINT)
    text(d, (x0 + 110, hy), health, font(SEMI, 42), MINT)
    # Lock Screen widgets under the Live Activity: streak, Pip's health and level.
    wy = y1 + 90
    for i, (value, label) in enumerate(WIDGETS[lang]):
        cx = W / 2 + (i - 1) * 300
        translucent(img, lambda d: d.ellipse([cx - 115, wy, cx + 115, wy + 230], fill=(255, 255, 255, 30),
                                             outline=(255, 255, 255, 70), width=3))
        d = ImageDraw.Draw(img)
        text(d, (cx, wy + 100), value, font(BOLD, 64), WHITE, "mm")
        text(d, (cx, wy + 162), label, font(SEMI, 34), GREY, "mm")
    return img.convert("RGB")


# Other display sizes App Store Connect asks for, made by scaling the 6.9" screenshot and trimming the sides.
SIZES = [(1290, 2796), (1206, 2622)]


def fit(img, size):
    w, h = size
    scale = max(w / img.width, h / img.height)
    scaled = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    left, top = (scaled.width - w) // 2, (scaled.height - h) // 2
    return scaled.crop((left, top, left + w, top + h))


def main():
    for lang in ("sv", "en"):
        for name, shot in (("notification", notification_shot(lang)), ("lock-screen", live_shot(lang))):
            for w, h in SIZES:
                save(fit(shot, (w, h)), "appstore", lang, f"screenshot-{name}-{w}x{h}.png")


if __name__ == "__main__":
    main()
