"""Draws 9:16 ads in the "real life" style: a product shot, the Paus shield, a text-only card, and see-through
overlays to put on top of your own video filmed outdoors.

Everything sits inside the middle band, since Instagram and Facebook cover the top and bottom of a story or reel
with their own controls.

Run from the repository root: python3 Brand/make_real_life_ads.py
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import (BLACK, BOLD, MINT, SEMI, VIOLET, WHITE, font, lockup, pip, rounded, app_icon, lerp, save)

W, H = 1080, 1920
DIM = (205, 200, 230)

COPY = {
    "sv": {
        "product": ("Sluta ge bort", "timmar till mobilen.", "Redo för en paus?",
                    "Lägg undan mobilen ett par timmar.\nPip räknar varje minut du vinner tillbaka."),
        "shield": ("Pip säger nej", "Fokuspass till 18:00.\nStäng nu och få +5 XP.", "Blockerad 5 gånger i dag",
                   "Pausat av: Fokuspass", "Stäng"),
        "text": "Lägg ifrån dig mobilen.",
        "won": ("Vunnet tillbaka i dag", "2 h 41 min", "utan att scrolla.", "Pip är stolt över dig!"),
        "streak": ("Den enda appen som blir glad\nnär du inte använder mobilen.", "DAGAR I RAD",
                   "Tid nog att läsa ut boken."),
    },
    "en": {
        "product": ("Stop giving hours", "to your phone.", "Ready for a pause?",
                    "Put your phone away for a couple of hours.\nPip counts every minute you win back."),
        "shield": ("Pip says no", "Focus session until 6:00 PM.\nClose now and get +5 XP.", "Blocked 5 times today",
                   "Paused by: Focus session", "Close"),
        "text": "Put the phone down.",
        "won": ("Won back today", "2 h 41 min", "without scrolling.", "Pip is proud of you!"),
        "streak": ("The only app that's happy\nwhen you're not using your phone.", "DAY STREAK",
                   "Enough time to finish the book."),
    },
}


def lines(draw, text, y, f, fill, gap, shadow=False):
    """Centred lines from `y`. Returns the y under the last line."""
    for line in text.split("\n"):
        if shadow:
            draw.text((W / 2 + 2, y + 3), line, font=f, fill=(0, 0, 0, 150), anchor="ma")
        draw.text((W / 2, y), line, font=f, fill=fill, anchor="ma")
        y += gap
    return y


def frosted(img, box, radius, tint=(255, 255, 255, 70)):
    """A blurred, see-through card, like an iOS widget."""
    x0, y0, x1, y1 = map(int, box)
    patch = img.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(30))
    layer = Image.new("RGBA", patch.size, tint)
    patch = Image.alpha_composite(patch.convert("RGBA"), layer)
    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, patch.width - 1, patch.height - 1], radius, fill=255)
    img.paste(patch, (x0, y0), mask)


def soft_light(w, h):
    """A pale mint-to-lavender background, the light counterpart to the app's dark look."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip(y / h * 0.8 + x / w * 0.2, 0, 1)[..., None]
    top, bottom = np.array([226, 248, 242], np.float32), np.array([228, 222, 255], np.float32)
    img = top + (bottom - top) * t
    return Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")


# MARK: The ads

def product(lang):
    title, title2, card_title, card_body = COPY[lang]["product"]
    img = soft_light(W, H)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([180, 330, 900, 1050], fill=(*MINT, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))

    p = pip(560)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([380, 950, 700, 1000], fill=(60, 40, 120, 70))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20)))
    img.alpha_composite(p, ((W - p.width) // 2, 420))

    logo = lockup(110, text_color=(20, 16, 40))
    img.alpha_composite(logo, ((W - logo.width) // 2, 1090))
    d = ImageDraw.Draw(img)
    y = lines(d, f"{title}\n{title2}", 1250, font(BOLD, 54), (40, 34, 70), 66)

    # A notification-style card, like the ones Paus sends.
    box = (90, y + 50, W - 90, y + 290)
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([box[0], box[1] + 10, box[2], box[3] + 10], 44, fill=(60, 40, 120, 40))
    card = card.filter(ImageFilter.GaussianBlur(16))
    ImageDraw.Draw(card).rounded_rectangle(box, 44, fill=(255, 255, 255, 215))
    img.alpha_composite(card)
    icon = rounded(app_icon(110))
    img.alpha_composite(icon, (box[0] + 36, box[1] + 36))
    d = ImageDraw.Draw(img)
    d.text((box[0] + 176, box[1] + 40), card_title, font=font(BOLD, 40), fill=(20, 16, 40))
    by = box[1] + 100
    for line in card_body.split("\n"):
        d.text((box[0] + 176, by), line, font=font(SEMI, 27), fill=(90, 84, 120))
        by += 38
    return img


def shield(lang):
    title, body, count, by, button = COPY[lang]["shield"]
    img = Image.new("RGBA", (W, H), (12, 10, 20, 255))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([240, 260, 840, 860], fill=(*VIOLET, 90))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(140)))

    p = pip(300, mood="hyped")
    img.alpha_composite(p, ((W - p.width) // 2, 400))
    d = ImageDraw.Draw(img)
    d.text((W / 2, 780), title, font=font(BLACK, 84), fill=WHITE, anchor="ma")
    y = lines(d, body, 920, font(SEMI, 38), DIM, 54)
    lines(d, f"{count}\n{by}", y + 50, font(SEMI, 34), (*MINT,), 52)

    bw, bh, bt = 360, 104, 1420
    d.rounded_rectangle([(W - bw) / 2, bt, (W + bw) / 2, bt + bh], bh / 2, fill=WHITE)
    d.text((W / 2, bt + bh / 2), button, font=font(BOLD, 40), fill=(12, 10, 20), anchor="mm")
    return img


def text_only(lang):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    lines(ImageDraw.Draw(img), COPY[lang]["text"], H / 2 - 22, font(SEMI, 42), WHITE, 56)
    return img


def won_overlay(lang):
    """Top-of-frame numbers for a clip of you outside, phone nowhere in sight."""
    label, value, under, proud = COPY[lang]["won"]
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lines(d, label, 330, font(BOLD, 46), WHITE, 0, shadow=True)
    value_font = font(BLACK, 128)
    d.text((W / 2 + 3, 395), value, font=value_font, fill=(0, 0, 0, 120), anchor="ma")
    d.text((W / 2, 392), value, font=value_font, fill=(150, 255, 215), anchor="ma")
    lines(d, under, 545, font(BOLD, 46), WHITE, 0, shadow=True)
    lines(d, proud, 620, font(SEMI, 36), (255, 255, 255, 215), 0, shadow=True)
    return img


def streak_overlay(lang, background=None):
    """A caption and a streak widget. The widget's frosted glass needs the video behind it, so the
    see-through version uses a plain tint and `background` gives a preview with real blur."""
    caption, unit, sub = COPY[lang]["streak"]
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0)) if background is None else background.copy()
    d = ImageDraw.Draw(img)
    lines(d, caption, 560, font(BOLD, 46), WHITE, 58, shadow=True)

    box = (300, 720, 780, 1260)
    if background is None:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle(box, 64, fill=(30, 22, 60, 150))
        img.alpha_composite(layer)
    else:
        frosted(img, box, 64, tint=(40, 28, 80, 110))
    p = pip(190)
    img.alpha_composite(p, ((W - p.width) // 2, box[1] + 50))
    d = ImageDraw.Draw(img)
    num = font(BLACK, 150)
    d.text((W / 2, box[1] + 245), "20", font=num, fill=(255, 214, 110), anchor="ma")
    d.text((W / 2, box[1] + 405), unit, font=font(BLACK, 44), fill=(255, 214, 110), anchor="ma")
    d.text((W / 2, box[1] + 465), sub, font=font(SEMI, 25), fill=(255, 255, 255, 200), anchor="ma")
    return img


def stand_in_background():
    """A blurred green-and-sky stand-in for the outdoor clip, only for previews."""
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    sky, hills, grass = np.array([170, 190, 205]), np.array([90, 120, 110]), np.array([70, 110, 50])
    img = np.where(y < 0.35, sky + (hills - sky) * (y / 0.35), hills + (grass - hills) * ((y - 0.35) / 0.65))
    img = np.broadcast_to(img, (H, W, 3)).astype(np.uint8)
    return Image.fromarray(img, "RGB").convert("RGBA")


def main():
    for lang in ("sv", "en"):
        save(product(lang).convert("RGB"), "ads", lang, "real-life", "product-1080x1920.png")
        save(shield(lang).convert("RGB"), "ads", lang, "real-life", "shield-1080x1920.png")
        save(text_only(lang).convert("RGB"), "ads", lang, "real-life", "text-1080x1920.png")
        save(won_overlay(lang), "ads", lang, "real-life", "overlay-won-back-1080x1920.png")
        save(streak_overlay(lang), "ads", lang, "real-life", "overlay-streak-1080x1920.png")

        # A contact sheet to look at, with the overlays on a stand-in background.
        bg = stand_in_background()
        won = bg.copy()
        won.alpha_composite(won_overlay(lang))
        frames = [product(lang), shield(lang), text_only(lang), won, streak_overlay(lang, bg)]
        tw, th, gap = 360, 640, 20
        sheet = Image.new("RGB", (len(frames) * (tw + gap) + gap, th + 2 * gap), (30, 30, 30))
        for i, f in enumerate(frames):
            sheet.paste(f.convert("RGB").resize((tw, th), Image.LANCZOS), (gap + i * (tw + gap), gap))
        save(sheet, "ads", lang, "real-life", "preview.png")


if __name__ == "__main__":
    main()
