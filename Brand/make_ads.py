"""Draws still image ads for Meta (Facebook and Instagram) in Swedish and English.

Five ideas, each as a 1:1 feed post, a 4:5 feed post and a 9:16 story. Stories keep everything inside
the middle band, since Instagram and Facebook cover the top and bottom of a story with their own controls.

Run from the repository root: python3 Brand/make_ads.py
"""
from PIL import Image, ImageDraw, ImageFilter

from make_brand import (BLACK, BOLD, CARD, CYAN, INK, MINT, ORANGE, PINK, SEMI, VIOLET, WHITE, app_icon, dark_backdrop,
                        font, gradient_text, pip, rounded, save)
from make_screenshots import gradient_fill, translucent, trophy

GREY = (200, 195, 230)
DIM = (150, 145, 185)

COPY = {
    "before-after": {
        "sv": ("Samma mobil.", "Hälften så mycket scroll.", ("Innan", "Med Paus"), "Exempel"),
        "en": ("Same phone.", "Half the scrolling.", ("Before", "With Paus"), "Example"),
    },
    "years": {
        "sv": ("Med 5 timmar om dagen blir det", "18 år", "av ditt vakna liv i mobilen.", "Paus hjälper dig ta tillbaka dem."),
        "en": ("At 5 hours a day, that's", "18 years", "of your waking life on your phone.", "Paus helps you take them back."),
    },
    "bodyguard": {
        "sv": ("Din nya", "skärmtidslivvakt.", "Inte nu. Du klarar det!", "Pip pausar apparna som stjäl din tid."),
        "en": ("Meet your new", "screen time bodyguard.", "Not now. You've got this!", "Pip pauses the apps that steal your time."),
    },
    "league": {
        "sv": ("Den som scrollar minst", "vinner.", "Veckans liga", ("Du", "Alex", "Sam"), "poäng"),
        "en": ("Whoever scrolls the least", "wins.", "This week's league", ("You", "Alex", "Sam"), "pts"),
    },
    "notification": {
        "sv": ("Tänk dig att få", "det här varje dag.", "nu", "Du vann tillbaka 2 h 41 min i dag",
               "Pip är stolt. Fortsätt så!"),
        "en": ("Imagine getting", "this every day.", "now", "You won back 2 h 41 min today", "Pip is proud. Keep it up!"),
    },
}
CTA = {"sv": "Gratis i App Store", "en": "Free on the App Store"}


# MARK: Shared parts

def backdrop(w, h):
    img = dark_backdrop(w, h).convert("RGBA")
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([w * 0.05, h * 0.25, w * 0.95, h * 0.85], fill=(*VIOLET, 70))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(w * 0.18)))
    return img


def headline(img, first, second, y, size):
    """A white line over a line in the brand gradient, both centred. Returns the y under them."""
    w = img.width
    f = font(BLACK, size)
    d = ImageDraw.Draw(img)
    while d.textlength(first, font=f) > w * 0.9:
        size -= 4
        f = font(BLACK, size)
    d.text((w / 2, y), first, font=f, fill=WHITE, anchor="ma")
    y += size * 1.12
    word = gradient_text(second, size)
    if word.width > w * 0.9:
        scale = w * 0.9 / word.width
        word = word.resize((int(word.width * scale), int(word.height * scale)), Image.LANCZOS)
    img.alpha_composite(word, (int((w - word.width) / 2), int(y)))
    return y + word.height


def cta(img, lang, bottom):
    """The app icon, "Paus" and a white "Free on the App Store" pill, centred above `bottom`."""
    w = img.width
    d = ImageDraw.Draw(img)
    icon = rounded(app_icon(96).convert("RGB"))
    name_font, pill_font = font(BLACK, 54), font(BOLD, 36)
    label = CTA[lang]
    pill_w = d.textlength(label, font=pill_font) + 64
    name_w = d.textlength("Paus", font=name_font)
    total = 96 + 18 + name_w + 34 + pill_w
    x = (w - total) / 2
    y = bottom - 96
    img.alpha_composite(icon, (int(x), int(y)))
    d.text((x + 114, y + 48), "Paus", font=name_font, fill=WHITE, anchor="lm")
    px = x + 114 + name_w + 34
    d.rounded_rectangle([px, y + 14, px + pill_w, y + 82], 34, fill=WHITE)
    d.text((px + pill_w / 2, y + 48), label, font=pill_font, fill=INK, anchor="mm")


def bars_card(img, box, title, value, hours, colors, label):
    x0, y0, x1, y1 = box
    translucent(img, lambda d: d.rounded_rectangle(box, 40, fill=(*CARD, 235), outline=(255, 255, 255, 30), width=2))
    d = ImageDraw.Draw(img)
    d.text(((x0 + x1) / 2, y0 + 30), label, font=font(BLACK, 40), fill=WHITE, anchor="ma")
    d.text((x0 + 32, y0 + 100), title, font=font(SEMI, 28), fill=GREY)
    d.text((x0 + 32, y0 + 136), value, font=font(BLACK, 66), fill=WHITE)
    base, top = y1 - 40, y0 + 240
    scale = (base - top) / 8
    slot = (x1 - x0 - 64) / len(hours)
    for i, hrs in enumerate(hours):
        bx = x0 + 32 + slot * i + slot * 0.18
        bar = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(bar).rounded_rectangle([bx, base - hrs * scale, bx + slot * 0.64, base], 10, fill=WHITE)
        gradient_fill(img, bar, colors)


# MARK: The five ads

def before_after(w, h, lang):
    first, second, (before, after), note = COPY["before-after"][lang]
    img = backdrop(w, h)
    y = headline(img, first, second, 70, 92)
    top = y + 50
    bottom = h - 190
    card_w = (w - 3 * 50) / 2
    bars_card(img, (50, top, 50 + card_w, bottom), "Daily average" if lang == "en" else "Snitt per dag", "6h 12m",
              [6.8, 5.6, 7.1, 6.2, 6.5], [ORANGE, PINK], before)
    bars_card(img, (100 + card_w, top, w - 50, bottom), "Daily average" if lang == "en" else "Snitt per dag", "3h 04m",
              [3.4, 2.9, 3.1, 2.6, 3.2], [MINT, CYAN], after)
    d = ImageDraw.Draw(img)
    d.text((w - 54, bottom + 14), note, font=font(SEMI, 22), fill=DIM, anchor="ra")
    cta(img, lang, h - 50)
    return img


def years(w, h, lang):
    lead, big, rest, promise = COPY["years"][lang]
    img = backdrop(w, h)
    d = ImageDraw.Draw(img)
    d.text((w / 2, 80), lead, font=font(BOLD, 44), fill=GREY, anchor="ma")
    number = gradient_text(big, 250 if h > 1100 else 210)
    img.alpha_composite(number, (int((w - number.width) / 2), 140))
    y = 140 + number.height + 10
    d.text((w / 2, y), rest, font=font(BLACK, 46), fill=WHITE, anchor="ma")
    size = min(330 if h > 1100 else 230, h - y - 360)
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cy = y + 90 + size / 2
    ImageDraw.Draw(halo).ellipse([w / 2 - size * 0.7, cy - size * 0.7, w / 2 + size * 0.7, cy + size * 0.7], fill=(*PINK, 70))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(size * 0.25)))
    img.alpha_composite(pip(int(size)), (int(w / 2 - size / 2), int(cy - size / 2)))
    d = ImageDraw.Draw(img)
    d.text((w / 2, h - 210), promise, font=font(BOLD, 38), fill=WHITE, anchor="ma")
    cta(img, lang, h - 50)
    return img


def bodyguard(w, h, lang):
    first, second, bubble, line = COPY["bodyguard"][lang]
    img = backdrop(w, h)
    y = headline(img, first, second, 70, 88)
    # Locked app tiles behind Pip.
    tiles = Image.new("RGBA", img.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(tiles)
    colors = [VIOLET, PINK, ORANGE, CYAN, MINT]
    area_top, area_bottom = y + 40, h - 230
    tile = 120
    for row in range(int((area_bottom - area_top) / 150) + 1):
        for col in range(7):
            x = 40 + col * 150 + (75 if row % 2 else 0)
            ty = area_top + row * 150
            if ty + tile > area_bottom:
                continue
            td.rounded_rectangle([x, ty, x + tile, ty + tile], 30, fill=(*colors[(row + col) % 5], 60))
            lx, ly = x + tile / 2, ty + tile / 2
            td.arc([lx - 14, ly - 30, lx + 14, ly + 2], 180, 360, fill=(255, 255, 255, 120), width=6)
            td.rounded_rectangle([lx - 20, ly - 10, lx + 20, ly + 22], 6, fill=(255, 255, 255, 120))
    img.alpha_composite(tiles)
    size = min(380, area_bottom - area_top - 140)
    cx, cy = w / 2, area_top + 110 + size / 2
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([cx - size * 0.8, cy - size * 0.8, cx + size * 0.8, cy + size * 0.8], fill=(*BLACK_BG, 230))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(size * 0.2)))
    img.alpha_composite(pip(int(size)), (int(cx - size / 2), int(cy - size / 2)))
    # Speech bubble.
    d = ImageDraw.Draw(img)
    f = font(BLACK, 40)
    bw = d.textlength(bubble, font=f) + 60
    bx, by = cx - bw / 2, area_top
    d.rounded_rectangle([bx, by, bx + bw, by + 80], 40, fill=WHITE)
    d.polygon([(cx - 18, by + 78), (cx + 18, by + 78), (cx, by + 104)], fill=WHITE)
    d.text((cx, by + 40), bubble, font=f, fill=INK, anchor="mm")
    d.text((w / 2, h - 200), line, font=font(BOLD, 36), fill=WHITE, anchor="ma")
    cta(img, lang, h - 50)
    return img


BLACK_BG = (14, 11, 31)


def league(w, h, lang):
    first, second, title, names, unit = COPY["league"][lang]
    img = backdrop(w, h)
    y = headline(img, first, second, 70, 84)
    top, bottom = y + 50, h - 200
    x0, x1 = 90, w - 90
    translucent(img, lambda d: d.rounded_rectangle([x0, top, x1, bottom], 48, fill=(*CARD, 240), outline=(255, 255, 255, 30), width=2))
    d = ImageDraw.Draw(img)
    d.text((x0 + 44, top + 40), title, font=font(BLACK, 44), fill=WHITE)
    trophy(img, x1 - 90, top + 70, 110)
    rows = [(names[0], 1240, [VIOLET, PINK]), (names[1], 980, None), (names[2], 870, None)]
    row_h = (bottom - top - 150) / 3
    for i, (name, points, colors) in enumerate(rows):
        ry = top + 130 + i * row_h
        if colors:
            highlight = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(highlight).rounded_rectangle([x0 + 24, ry, x1 - 24, ry + row_h - 16], 32, fill=WHITE)
            gradient_fill(img, highlight, colors, vertical=False)
        d = ImageDraw.Draw(img)
        mid = ry + (row_h - 16) / 2
        d.text((x0 + 70, mid), str(i + 1), font=font(BLACK, 54), fill=WHITE, anchor="mm")
        avatar = int(min(96, row_h - 40))
        if i == 0:
            img.alpha_composite(pip(avatar), (int(x0 + 120), int(mid - avatar / 2)))
        else:
            d.ellipse([x0 + 120, mid - avatar / 2, x0 + 120 + avatar, mid + avatar / 2], fill=(*(ORANGE if i == 1 else CYAN), 255))
            d.text((x0 + 120 + avatar / 2, mid), name[0], font=font(BLACK, 44), fill=WHITE, anchor="mm")
        d = ImageDraw.Draw(img)
        d.text((x0 + 150 + avatar, mid), name, font=font(BLACK, 48), fill=WHITE, anchor="lm")
        d.text((x1 - 60, mid), f"{points:,}".replace(",", " ") + f" {unit}", font=font(BOLD, 40), fill=WHITE if colors else GREY, anchor="rm")
    cta(img, lang, h - 50)
    return img


def notification(w, h, lang):
    first, second, now, title, body = COPY["notification"][lang]
    img = backdrop(w, h)
    y = headline(img, first, second, 70, 92)
    # A lock screen style notification, big.
    x0, x1 = 60, w - 60
    top = y + (90 if h > 1100 else 50)
    card_h = 250
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x0, top + 24, x1, top + card_h + 24], 56, fill=(0, 0, 0, 160))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(30)))
    translucent(img, lambda d: d.rounded_rectangle([x0, top, x1, top + card_h], 56, fill=(48, 40, 92, 245), outline=(255, 255, 255, 50), width=3))
    icon = rounded(app_icon(130).convert("RGB"))
    img.alpha_composite(icon, (x0 + 40, int(top + (card_h - 130) / 2)))
    d = ImageDraw.Draw(img)
    tx = x0 + 200
    d.text((tx, top + 56), "Paus", font=font(BOLD, 36), fill=GREY)
    d.text((x1 - 44, top + 58), now, font=font(SEMI, 32), fill=DIM, anchor="ra")
    tf = font(BLACK, 44)
    while d.textlength(title, font=tf) > x1 - tx - 40:
        tf = font(BLACK, tf.size - 2)
    d.text((tx, top + 108), title, font=tf, fill=WHITE)
    d.text((tx, top + 170), body, font=font(SEMI, 34), fill=GREY)
    # Pip, glowing with pride, under the notification.
    size = min(360 if h > 1100 else 240, h - (top + card_h) - 300)
    cy = top + card_h + 60 + size / 2
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([w / 2 - size * 0.75, cy - size * 0.75, w / 2 + size * 0.75, cy + size * 0.75], fill=(*MINT, 80))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(size * 0.22)))
    img.alpha_composite(pip(int(size)), (int(w / 2 - size / 2), int(cy - size / 2)))
    cta(img, lang, h - 50)
    return img


ADS = {
    "before-after": before_after,
    "years": years,
    "bodyguard": bodyguard,
    "league": league,
    "notification": notification,
}


def story(draw, lang):
    """A 9:16 story: the 1:1 ad in the band Instagram and Facebook leave free, over a matching background."""
    w, h = 1080, 1920
    img = backdrop(w, h)
    square = draw(1080, 1080, lang)
    # Fade the square's top and bottom edges into the story's own background.
    mask = Image.new("L", square.size, 255)
    md = ImageDraw.Draw(mask)
    for i in range(80):
        md.line([(0, i), (1080, i)], fill=int(255 * i / 80))
        md.line([(0, 1079 - i), (1080, 1079 - i)], fill=int(255 * i / 80))
    square.putalpha(mask)
    img.alpha_composite(square, (0, 300))
    return img


def main():
    for lang in ("sv", "en"):
        for name, draw in ADS.items():
            save(draw(1080, 1080, lang).convert("RGB"), "ads", lang, f"{name}-1080x1080.png")
            save(draw(1080, 1350, lang).convert("RGB"), "ads", lang, f"{name}-1080x1350.png")
            save(story(draw, lang).convert("RGB"), "ads", lang, f"{name}-story-1080x1920.png")


if __name__ == "__main__":
    main()
