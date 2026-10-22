"""Draws App Store screenshots that show the Lock Screen: a notification from Pip and a focus session's Live Activity.

Run from the repository root: python3 Brand/make_screenshots.py
Uses the drawing helpers and palette from make_brand.py.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import (BG, BLACK, BOLD, CARD, MINT, ORANGE, PINK, SEMI, VIOLET, WHITE, app_icon, dark_backdrop, font, pip,
                        rounded, save)

HERE = os.path.dirname(os.path.abspath(__file__))

# iPhone 6.9" display, the size App Store Connect asks for first.
W, H = 1290, 2796
GREY = (200, 195, 230)
DIM = (150, 145, 185)

HEADLINES = {
    "notification": {"sv": "Pip hejar på dig\nvarje dag", "en": "Pip cheers you on\nevery day"},
    "levels": {"sv": "Från Scrollzombie\ntill Legend", "en": "From Scroll Zombie\nto Legend"},
    "math": {"en": "See what scrolling\nreally costs you"},
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
# PlayerProgress.titles; level n needs 50·(n−1)·n XP.
TITLES = {
    "sv": ["Scrollzombie", "Uppvaknad", "Nyfiken", "Fokusfrö", "Skärmtämjare",
           "Flowjägare", "Zen-ninja", "Dopamindetektiv", "Tidsmästare", "Legend"],
    "en": ["Scroll Zombie", "Awakened", "Curious", "Focus Seed", "Screen Tamer",
           "Flow Hunter", "Zen Ninja", "Dopamine Detective", "Time Master", "Legend"],
}
YOU = {"sv": "DU", "en": "YOU"}
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


def gradient_fill(img, shape_layer, colors, vertical=True):
    """Fills the opaque parts of `shape_layer` with a gradient through `colors`."""
    alpha = np.array(shape_layer)[..., 3]
    h, w = alpha.shape
    t = np.linspace(0, 1, h if vertical else w)
    t = t[:, None] if vertical else t[None, :]
    grad = np.zeros((h, w, 4), np.float32)
    stops = np.linspace(0, 1, len(colors))
    for (t0, c0), (t1, c1) in zip(zip(stops, colors), zip(stops[1:], colors[1:])):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)
        inside = (t >= t0) & (t <= t1)
        for i in range(3):
            grad[..., i] = np.where(inside, c0[i] + (c1[i] - c0[i]) * k, grad[..., i])
    grad[..., 3] = alpha
    img.alpha_composite(Image.fromarray(grad.astype(np.uint8), "RGBA"))


def trophy(img, cx, cy, size):
    """A gold cup with handles, drawn from simple shapes."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    s = size
    d.pieslice([cx - s * 0.42, cy - s * 0.75, cx + s * 0.42, cy + s * 0.15], 0, 180, fill=WHITE)
    d.rectangle([cx - s * 0.42, cy - s * 0.5, cx + s * 0.42, cy - s * 0.3], fill=WHITE)
    for sx in (-1, 1):
        hx = cx + sx * s * 0.42
        d.arc([hx - s * 0.2, cy - s * 0.48, hx + s * 0.2, cy - s * 0.08], -90 if sx > 0 else 90, 90 if sx > 0 else 270,
              fill=WHITE, width=int(s * 0.07))
    d.rectangle([cx - s * 0.07, cy + s * 0.1, cx + s * 0.07, cy + s * 0.32], fill=WHITE)
    d.rounded_rectangle([cx - s * 0.3, cy + s * 0.3, cx + s * 0.3, cy + s * 0.45], int(s * 0.05), fill=WHITE)
    gradient_fill(img, layer, [(255, 226, 120), ORANGE, (240, 130, 40)])
    d = ImageDraw.Draw(img)
    # A star on the cup.
    r = s * 0.13
    pts = []
    for k in range(10):
        a = -np.pi / 2 + k * np.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((cx + rr * np.cos(a), cy - s * 0.28 + rr * np.sin(a)))
    d.polygon(pts, fill=(255, 255, 255, 230))


def pill(img, xy, label, colors):
    f = font(BLACK, 46)
    d = ImageDraw.Draw(img)
    w = d.textlength(label, font=f) + 70
    x, y = xy
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x, y + 14, x + w, y + 94], 40, fill=(0, 0, 0, 150))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20)))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle([x, y, x + w, y + 80], 40, fill=WHITE)
    gradient_fill(img, layer, colors, vertical=False)
    text(ImageDraw.Draw(img), (x + w / 2, y + 40), label, f, WHITE, "mm")


def levels_shot(lang):
    img = backdrop()
    d = ImageDraw.Draw(img)
    centered_lines(d, HEADLINES["levels"][lang], 200, font(BLACK, 108), WHITE, 128)
    current = 5
    count = 10
    top_y, bottom_y = 820, 2600
    nodes = []
    for i in range(count):
        y = bottom_y - (bottom_y - top_y) * i / (count - 1)
        x = W / 2 + 300 * np.sin(i * 0.95 + 0.4)
        nodes.append((x, y))
    # The road: a glowing gradient up to the current level, a faint line after it.
    road = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dim = Image.new("RGBA", img.size, (0, 0, 0, 0))
    steps = 40
    for i in range(count - 1):
        (x0, y0), (x1, y1) = nodes[i], nodes[i + 1]
        target = road if i < current - 1 else dim
        pts = []
        for k in range(steps + 1):
            t = k / steps
            # Ease between the nodes so the road curves.
            e = t * t * (3 - 2 * t)
            pts.append((x0 + (x1 - x0) * e, y0 + (y1 - y0) * t))
        ImageDraw.Draw(target).line(pts, fill=WHITE if target is road else (255, 255, 255, 50), width=34, joint="curve")
    img.alpha_composite(dim)
    glow = road.filter(ImageFilter.GaussianBlur(40))
    gradient_fill(img, glow, [ORANGE, PINK, VIOLET])
    gradient_fill(img, road, [ORANGE, PINK, VIOLET])
    titles = TITLES[lang]
    title_font, xp_font = font(BOLD, 52), font(SEMI, 38)
    for i, (x, y) in enumerate(nodes):
        level = i + 1
        xp = 50 * i * level
        xp_text = (f"{xp:,}".replace(",", " " if lang == "sv" else ",")) + " XP"
        done = level < current
        d = ImageDraw.Draw(img)
        if level == count:
            halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(halo).ellipse([x - 190, y - 190, x + 190, y + 190], fill=(*ORANGE, 110))
            img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(60)))
            trophy(img, x, y + 20, 230)
        elif level == current:
            halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(halo).ellipse([x - 200, y - 200, x + 200, y + 200], fill=(*MINT, 100))
            img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(60)))
            p = pip(250)
            img.alpha_composite(p, (int(x - 125), int(y - 125)))
        else:
            r = 66
            if done:
                disc = Image.new("RGBA", img.size, (0, 0, 0, 0))
                ImageDraw.Draw(disc).ellipse([x - r, y - r, x + r, y + r], fill=WHITE)
                gradient_fill(img, disc, [VIOLET, PINK])
            else:
                translucent(img, lambda dr: dr.ellipse([x - r, y - r, x + r, y + r], fill=(*CARD, 255),
                                                       outline=(255, 255, 255, 60), width=4))
            d = ImageDraw.Draw(img)
            text(d, (x, y), str(level), font(BLACK, 62), WHITE if done else (150, 145, 185), "mm")
        # Label on the roomier side of the road.
        d = ImageDraw.Draw(img)
        right = x < W / 2
        gap = 165 if level in (current, count) else 100
        lx = x + gap if right else x - gap
        anchor_t = "ls" if right else "rs"
        color = WHITE if level <= current or level == count else (170, 165, 205)
        text(d, (lx, y + 2), titles[i], title_font, color, anchor_t)
        text(d, (lx, y + 52), xp_text, xp_font, ORANGE if level == count else (150, 145, 185), anchor_t)
        if level == current:
            chip_f = font(BLACK, 36)
            label_w = d.textlength(titles[i], font=title_font)
            cw = d.textlength(YOU[lang], font=chip_f) + 44
            cx0 = lx + label_w + 24 if right else lx - label_w - 24 - cw
            d.rounded_rectangle([cx0, y - 50, cx0 + cw, y + 4], 27, fill=(20, 70, 60))
            text(d, (cx0 + cw / 2, y - 23), YOU[lang], chip_f, MINT, "mm")
    # XP that just came in.
    pill(img, (nodes[1][0] + 90, nodes[1][1] - 150), "+25 XP", [VIOLET, PINK])
    pill(img, (nodes[3][0] - 330, nodes[3][1] + 70), "+50 XP", [PINK, ORANGE])
    return img.convert("RGB")


def framed_shot(name, lang, source):
    """A real screenshot from the app inside the phone frame, under a headline."""
    img = backdrop()
    d = ImageDraw.Draw(img)
    centered_lines(d, HEADLINES[name][lang], 200, font(BLACK, 108), WHITE, 128)
    shot = Image.open(source).convert("RGBA")
    sw = 940
    sh = round(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    x0, y0 = (W - sw) // 2, 560
    pad, radius = 22, 110
    # Glow behind the phone, then the gradient frame, then the screen.
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle([x0 - 60, y0 - 60, x0 + sw + 60, y0 + sh + 60], radius, fill=(*PINK, 90))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))
    body = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([x0 - pad, y0 - pad, x0 + sw + pad, y0 + sh + pad], radius + pad, fill=WHITE)
    gradient_fill(img, body, [VIOLET, PINK, ORANGE])
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius, fill=255)
    shot.putalpha(mask)
    img.alpha_composite(shot, (x0, y0))
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
    shot = framed_shot("math", "en", os.path.join(HERE, "source", "intro-life-math-en.jpg"))
    for w, h in SIZES:
        save(fit(shot, (w, h)), "appstore", "en", f"screenshot-life-math-{w}x{h}.png")
    for lang in ("sv", "en"):
        for name, shot in (("notification", notification_shot(lang)), ("lock-screen", live_shot(lang)),
                           ("levels", levels_shot(lang))):
            for w, h in SIZES:
                save(fit(shot, (w, h)), "appstore", lang, f"screenshot-{name}-{w}x{h}.png")


if __name__ == "__main__":
    main()
