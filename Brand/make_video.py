"""Draws "The thumb", an animated 9:16 video ad for Reels, Stories and TikTok, in Swedish and English.

A thumb scrolls through every night, dinner and sunset until Pip pauses it. The camera then pulls back to the
sunset it was missing, and the results and the call to action follow. The music and sound effects are made here
too, so the file is ready to post.

Run from the repository root: python3 Brand/make_video.py
Stills for checking a few moments: python3 Brand/make_video.py --stills 1,5,9 [out_dir]
"""
import functools
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

from make_ads import COPY, DIM, GREY, backdrop, cta
from make_brand import BLACK, BOLD, CARD, CYAN, INK, MINT, ORANGE, OUT, PINK, SEMI, TAGLINE, VIOLET, WHITE, app_icon, \
    font, gradient_text, pip, rounded
from make_screenshots import gradient_fill, translucent, trophy

W, H, FPS = 1080, 1920, 30
DURATION = 25.5
RATE = 44100

VIDEO = {
    "sv": {
        "hook": ("Den här tummen har tagit", "18 år av mitt liv."),
        "counter": "Skärmtid i dag",
        "lines": ("Varje kväll.", "Varje middag.", "Varje solnedgång."),
        "listen": "…lyssnar du?",
        "reveal": ("Det var här", "hela tiden."),
        "average": "Snitt per dag",
    },
    "en": {
        "hook": ("This thumb has taken", "18 years of my life."),
        "counter": "Screen time today",
        "lines": ("Every night.", "Every dinner.", "Every sunset."),
        "listen": "…are you listening?",
        "reveal": ("It was here", "all along."),
        "average": "Daily average",
    },
}

# When things happen, in seconds.
SWIPES_END = 7.3
TAP = 7.6
PAUSED = 7.8
PIP_POPS = 8.0
REVEAL = 11.0
PROOF = 16.0
LEAGUE = 18.5
NOTIFY = 20.1
END = 21.6
CROSSFADE = 0.3
SWIPE_START, SWIPE_EVERY, SWIPE_DISTANCE = 0.15, 0.62, 600


# MARK: Timing

def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def seg(t, a, b):
    return clamp((t - a) / (b - a))


def ease_out(x):
    return 1 - (1 - x) ** 3


def smooth(x):
    return x * x * (3 - 2 * x)


def back(x):
    """Overshoots a little before settling, for things that pop in."""
    c = 1.7
    return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2


# MARK: Drawing helpers

def faded(layer, k):
    if k >= 1:
        return layer
    out = layer.copy()
    out.putalpha(layer.getchannel("A").point(lambda v: int(v * k)))
    return out


def put(img, layer, x, y, k=1.0):
    """Composites `layer` at (x, y) with opacity `k`, clipping whatever falls outside the frame."""
    if k <= 0:
        return
    x, y = int(round(x)), int(round(y))
    left, top = max(0, -x), max(0, -y)
    if left >= layer.width or top >= layer.height or x >= img.width or y >= img.height:
        return
    part = layer.crop((left, top, layer.width, layer.height)) if left or top else layer
    img.alpha_composite(faded(part, k), (x + left, y + top))


def scaled(layer, s):
    if abs(s - 1) < 0.01:
        return layer
    return layer.resize((max(1, int(layer.width * s)), max(1, int(layer.height * s))), Image.BICUBIC)


def put_center(img, layer, cx, cy, s=1.0, k=1.0):
    if s <= 0.01:
        return
    layer = scaled(layer, s)
    put(img, layer, cx - layer.width / 2, cy - layer.height / 2, k)


def vgrad(w, h, stops):
    t = np.linspace(0, 1, h)
    pos = [p for p, _ in stops]
    cols = np.stack([np.interp(t, pos, [c[i] for _, c in stops]) for i in range(3)], -1)
    return Image.fromarray(np.repeat(cols[:, None, :], w, 1).astype(np.uint8), "RGB")


def overlay(img, draw, blur=0):
    """Draws see-through shapes on an RGB image, optionally softened."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw(ImageDraw.Draw(layer))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.paste(layer, (0, 0), layer)


def glow(img, cx, cy, r, color, alpha):
    overlay(img, lambda d: d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, alpha)), blur=r * 0.45)


def person(d, x, feet, color, scale=1.0, wave_arm=False):
    """A simple silhouette: a head over rounded shoulders."""
    s = scale
    d.ellipse([x - 44 * s, feet - 250 * s, x + 44 * s, feet - 162 * s], fill=color)
    d.rounded_rectangle([x - 62 * s, feet - 150 * s, x + 62 * s, feet + 40 * s], int(50 * s), fill=color)
    if wave_arm:
        d.line([(x + 50 * s, feet - 120 * s), (x + 110 * s, feet - 230 * s)], fill=color, width=int(30 * s))
        d.ellipse([x + 92 * s, feet - 262 * s, x + 132 * s, feet - 222 * s], fill=color)


@functools.lru_cache(None)
def title(first, second=None, size=80, gradient=True):
    """One or two centred lines with a soft shadow, so they read on any background."""
    lines = [first] + ([second] if second else [])
    f = font(BLACK, size)
    while max(f.getlength(s) for s in lines) > W * 0.88:
        size -= 4
        f = font(BLACK, size)
    gap = int(size * 1.16)
    layer = Image.new("RGBA", (W, gap * len(lines) + 70), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((W / 2, 30), first, font=f, fill=WHITE, anchor="ma")
    if second:
        if gradient:
            word = gradient_text(second, size)
            put(layer, word, (W - word.width) / 2, 30 + gap + f.getbbox(second)[1] - 4)
        else:
            d.text((W / 2, 30 + gap), second, font=f, fill=WHITE, anchor="ma")
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel("A").point(lambda v: int(v * 0.8)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    shadow.alpha_composite(layer)
    return shadow


def bubble(text_, size=40, tail="down"):
    f = font(BLACK, size)
    bw = int(f.getlength(text_) + 64)
    bh = int(size * 2)
    img = Image.new("RGBA", (bw + 40, bh + 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([20, 0, 20 + bw, bh], bh // 2, fill=WHITE)
    if tail == "down":
        cx = 20 + bw / 2
        d.polygon([(cx - 18, bh - 2), (cx + 18, bh - 2), (cx, bh + 26)], fill=WHITE)
    else:  # from the left
        d.polygon([(28, bh * 0.55), (52, bh * 0.85), (0, bh + 18)], fill=WHITE)
    d.text((20 + bw / 2, bh / 2), text_, font=f, fill=INK, anchor="mm")
    return img


# MARK: The scenes behind the phone

def bed_scene():
    img = vgrad(W, H, [(0, (8, 10, 32)), (1, (26, 28, 74))])
    rng = np.random.default_rng(3)
    d = ImageDraw.Draw(img)
    for _ in range(80):
        x, y, r = rng.uniform(0, W), rng.uniform(0, 620), rng.uniform(1.5, 3.5)
        c = int(rng.uniform(110, 230))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(c, c, c + 20 if c < 235 else 255))
    # A window with the moon, left of the phone.
    d.rounded_rectangle([24, 640, 210, 990], 18, fill=(52, 62, 130))
    d.rectangle([40, 656, 194, 974], fill=(20, 26, 70))
    d.ellipse([70, 700, 160, 790], fill=(246, 240, 210))
    d.ellipse([96, 688, 186, 778], fill=(20, 26, 70))
    d.rectangle([113, 656, 121, 974], fill=(52, 62, 130))
    d.rectangle([40, 812, 194, 820], fill=(52, 62, 130))
    # Headboard, nightstand with a clock, pillows and the duvet.
    d.rounded_rectangle([-60, 1040, W + 60, 1700], 60, fill=(58, 44, 108))
    d.rectangle([870, 1250, W, 1520], fill=(40, 32, 78))
    d.rounded_rectangle([884, 1150, 1066, 1246], 22, fill=(16, 14, 36))
    glow(img, 975, 1198, 120, (255, 70, 80), 70)
    d = ImageDraw.Draw(img)
    d.text((975, 1198), "01:12", font=font(BOLD, 58), fill=(255, 92, 92), anchor="mm")
    d.rounded_rectangle([-40, 1420, 250, 1580], 60, fill=(206, 200, 236))
    d.rounded_rectangle([830, 1440, W + 40, 1600], 60, fill=(206, 200, 236))
    d.rounded_rectangle([-80, 1560, W + 80, H + 200], 90, fill=(92, 72, 176))
    for y in (1680, 1790):
        d.arc([-200, y, W + 200, y + 220], 200, 340, fill=(76, 58, 150), width=10)
    return img


def dinner_scene():
    img = vgrad(W, H, [(0, (58, 34, 30)), (1, (124, 72, 46))])
    glow(img, 540, 300, 420, (255, 190, 110), 110)
    d = ImageDraw.Draw(img)
    d.line([(540, 0), (540, 150)], fill=(30, 18, 16), width=6)
    d.polygon([(450, 240), (630, 240), (580, 150), (500, 150)], fill=(40, 26, 22))
    d.rectangle([40, 640, 196, 860], fill=(160, 104, 70))
    d.rectangle([56, 656, 180, 844], fill=(214, 160, 104))
    person(d, 120, 1450, (44, 24, 22), 1.2)
    person(d, 965, 1450, (44, 24, 22), 1.15)
    d.rectangle([0, 1430, W, H], fill=(168, 104, 64))
    d.rectangle([0, 1430, W, 1470], fill=(196, 128, 82))
    for x in (130, 950):
        d.ellipse([x - 120, 1550, x + 120, 1650], fill=(246, 244, 238))
        d.ellipse([x - 80, 1566, x + 80, 1634], fill=(226, 222, 214))
        d.ellipse([x - 44, 1578, x + 30, 1618], fill=(222, 120, 70))
    d.rounded_rectangle([880, 1380, 930, 1500], 10, fill=(196, 214, 236))
    return img


def sunset_scene():
    horizon = int(H * 0.66)
    img = vgrad(W, H, [(0, (48, 26, 108)), (0.36, (170, 58, 140)), (0.58, (255, 108, 110)), (0.66, (255, 176, 92)),
                       (1, (255, 176, 92))])
    glow(img, 540, 1150, 520, (255, 170, 90), 140)
    d = ImageDraw.Draw(img)
    d.ellipse([390, 1020, 690, 1320], fill=(255, 226, 154))
    overlay(img, lambda d: [d.rounded_rectangle([x, y, x + w, y + 46], 23, fill=(255, 150, 170, 120))
                            for x, y, w in [(40, 540, 380), (620, 660, 420), (120, 860, 300)]], blur=6)
    sea = vgrad(W, H - horizon, [(0, (110, 44, 112)), (1, (26, 16, 56))])
    img.paste(sea, (0, horizon))
    d = ImageDraw.Draw(img)
    for i in range(14):
        y = horizon + 18 + i * 34
        half = 170 - i * 9
        d.rounded_rectangle([540 - half, y, 540 + half, y + 8], 4, fill=(255, 200 - i * 6, 140 - i * 4))
    for bx, by, s in [(800, 470, 1.0), (870, 420, 0.8), (740, 400, 0.7), (300, 300, 0.6)]:
        d.arc([bx - 30 * s, by - 14 * s, bx, by + 14 * s], 200, 340, fill=(40, 20, 50), width=int(6 * s) + 1)
        d.arc([bx, by - 14 * s, bx + 30 * s, by + 14 * s], 200, 340, fill=(40, 20, 50), width=int(6 * s) + 1)
    # The beach and two friends, which the phone hides until the reveal.
    d.ellipse([-400, 1640, W + 400, 2600], fill=(32, 18, 44))
    person(d, 150, 1700, (24, 12, 34), 1.0)
    person(d, 930, 1700, (24, 12, 34), 1.0, wave_arm=True)
    return img


def dimmed(img):
    """The world as the scroller sees it: grey and dark."""
    return ImageEnhance.Brightness(ImageEnhance.Color(img).enhance(0.3)).enhance(0.5)


def zoom(img, z):
    cw, ch = W / z, H / z
    box = ((W - cw) / 2, (H - ch) / 2, (W + cw) / 2, (H + ch) / 2)
    return img.resize((W, H), Image.BILINEAR, box=box)


ZOOM_BEFORE = 1.25


@functools.lru_cache(None)
def scenes():
    full = {"bed": bed_scene(), "dinner": dinner_scene(), "sunset": sunset_scene()}
    dim = {name: dimmed(img) for name, img in full.items()}
    # Only the sunset starts zoomed in, so the camera can pull back from it at the reveal.
    zoomed = {**dim, "sunset": zoom(dim["sunset"], ZOOM_BEFORE)}
    return full, dim, zoomed


# MARK: The phone

PW, PH, BEZEL = 620, 1240, 16
SW, SH = PW - 2 * BEZEL, PH - 2 * BEZEL
PHONE_CX, PHONE_CY = W / 2, 600 + PH / 2


@functools.lru_cache(None)
def phone_parts():
    frame = Image.new("RGBA", (PW + 12, PH), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    for y0, y1 in [(250, 330), (370, 450)]:
        d.rounded_rectangle([0, y0, 10, y1], 4, fill=(60, 56, 84))
    d.rounded_rectangle([PW + 2, 300, PW + 12, 420], 4, fill=(60, 56, 84))
    d.rounded_rectangle([6, 0, PW + 5, PH - 1], 96, fill=(20, 18, 32), outline=(96, 90, 128), width=4)
    mask = Image.new("L", (SW * 2, SH * 2), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SW * 2 - 1, SH * 2 - 1], 160, fill=255)
    mask = mask.resize((SW, SH), Image.LANCZOS)
    island = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    ImageDraw.Draw(island).rounded_rectangle([SW / 2 - 90, 22, SW / 2 + 90, 72], 25, fill=(0, 0, 0))
    return frame, mask, island


@functools.lru_cache(None)
def feed_strip():
    """A generic, blurred social feed: no real apps, just cards, faces and pictures in brand colours."""
    rng = np.random.default_rng(7)
    palette = [VIOLET, PINK, ORANGE, CYAN, MINT, (255, 120, 90), (120, 150, 255), (250, 210, 90)]
    pick = lambda: palette[rng.integers(len(palette))]
    tile = Image.new("RGB", (SW, 4000), (16, 14, 28))
    d = ImageDraw.Draw(tile)
    y = 90
    while y < 2900:
        d.ellipse([24, y, 84, y + 60], fill=pick())
        d.rounded_rectangle([100, y + 10, 100 + rng.uniform(140, 260), y + 30], 10, fill=(126, 120, 156))
        d.rounded_rectangle([100, y + 40, 100 + rng.uniform(80, 160), y + 54], 7, fill=(74, 70, 100))
        ph = int(rng.uniform(380, 540))
        top = y + 80
        a, b = pick(), pick()
        pic = Image.composite(Image.new("RGB", (SW - 32, ph), a), Image.new("RGB", (SW - 32, ph), b),
                              Image.linear_gradient("L").resize((SW - 32, ph)))
        pd = ImageDraw.Draw(pic)
        for _ in range(3):
            r = rng.uniform(50, 130)
            x0, y0 = rng.uniform(0, SW - 32), rng.uniform(0, ph)
            pd.ellipse([x0 - r, y0 - r, x0 + r, y0 + r], fill=pick())
        tile.paste(rounded(pic, 0.06).convert("RGB"), (16, top), rounded(pic, 0.06))
        y = top + ph + 24
        for k in range(3):
            d.ellipse([24 + k * 64, y, 64 + k * 64, y + 40], outline=(150, 145, 180), width=4)
        d.rounded_rectangle([24, y + 64, 24 + rng.uniform(300, 520), y + 84], 10, fill=(100, 96, 130))
        y += 150
    tile = tile.crop((0, 0, SW, y)).filter(ImageFilter.GaussianBlur(5))
    strip = Image.new("RGB", (SW, y * 3))
    for i in range(3):
        strip.paste(tile, (0, y * i))
    return strip, y


def scroll_offset(t):
    if t < SWIPE_START:
        return 0.0
    t = min(t, SWIPES_END)
    n, u = divmod(t - SWIPE_START, SWIPE_EVERY)
    return n * SWIPE_DISTANCE + SWIPE_DISTANCE * ease_out(clamp(u / (SWIPE_EVERY * 0.8)))


@functools.lru_cache(None)
def pip_big():
    return pip(400)


def screen(t, lang):
    if t < PAUSED:
        strip, tile_h = feed_strip()
        y = int(scroll_offset(t)) % tile_h
        return strip.crop((0, y, SW, y + SH)).convert("RGBA")
    img = vgrad(SW, SH, [(0, (22, 16, 52)), (1, (12, 10, 28))])
    if t >= PIP_POPS:
        glow(img, SW / 2, SH * 0.52, 260, VIOLET, int(120 * seg(t, PIP_POPS, PIP_POPS + 0.4)))
    img = img.convert("RGBA")
    if t >= PIP_POPS:
        s = back(seg(t, PIP_POPS, PIP_POPS + 0.35))
        bob = math.sin((t - PIP_POPS) * 3) * 8
        put_center(img, pip_big(), SW / 2, SH * 0.52 + bob, 0.82 * s)
        b = speech(COPY["bodyguard"][lang][2])
        put_center(img, b, SW / 2, SH * 0.52 - 270, back(seg(t, PIP_POPS + 0.35, PIP_POPS + 0.6)))
    return img


@functools.lru_cache(None)
def speech(text_):
    size = 40
    while font(BLACK, size).getlength(text_) > SW - 100:
        size -= 2
    return bubble(text_, size)


def phone(t, lang):
    frame, mask, island = phone_parts()
    out = frame.copy()
    content = screen(t, lang)
    content.alpha_composite(island)
    out.paste(content, (6 + BEZEL, BEZEL), mask)
    return out


@functools.lru_cache(None)
def thumb():
    """A cartoon thumb coming in from the bottom right, drawn at 4x and tilted."""
    s, w, h = 4, 230, 600
    img = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin, shade, nail = (238, 186, 152), (212, 154, 122), (252, 222, 208)
    d.rounded_rectangle([0, 0, w * s - 1, h * s + 600], 115 * s, fill=shade)
    d.rounded_rectangle([12 * s, 4 * s, w * s - 28 * s, h * s + 600], 102 * s, fill=skin)
    d.rounded_rectangle([46 * s, 26 * s, 178 * s, 196 * s], 62 * s, fill=nail)
    d.rounded_rectangle([70 * s, 48 * s, 104 * s, 128 * s], 17 * s, fill=(255, 242, 234))
    for y in (318, 346):
        d.arc([56 * s, y * s, 176 * s, (y + 46) * s], 200, 340, fill=shade, width=5 * s)
    img = img.resize((w, h), Image.LANCZOS)
    return img.rotate(26, expand=True, resample=Image.BICUBIC)


def thumb_lift(t):
    """How far up the thumb is: it swipes up, lifts and comes back, then taps once and leaves."""
    if t < SWIPES_END and t >= SWIPE_START:
        u = ((t - SWIPE_START) % SWIPE_EVERY) / SWIPE_EVERY
        if u < 0.35:
            return 240 * ease_out(u / 0.35)
        return 240 * (1 - smooth(seg(u, 0.4, 0.95)))
    if TAP <= t < PAUSED:
        return -30 * math.sin(math.pi * seg(t, TAP, PAUSED))
    return 0.0


# MARK: Overlays

@functools.lru_cache(None)
def counter(label, minutes):
    f_label, f_value = font(SEMI, 32), font(BLACK, 44)
    value = f"{minutes // 60}h {minutes % 60:02d}m"
    width = int(f_label.getlength(label) + f_value.getlength("6h 00m") + 120)
    img = Image.new("RGBA", (width, 84), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, width - 1, 83], 42, fill=(10, 8, 24, 200), outline=(255, 255, 255, 40), width=2)
    hot = clamp((minutes - 291) / 81)
    color = tuple(int(WHITE[i] + ((255, 92, 110)[i] - WHITE[i]) * hot) for i in range(3))
    d.ellipse([30, 32, 50, 52], fill=(255, 92, 110))
    d.text((66, 42), label, font=f_label, fill=GREY, anchor="lm")
    d.text((width - 34, 42), value, font=f_value, fill=color, anchor="rm")
    return img


def minutes_at(t):
    return 291 + round(81 * seg(t, 0, PAUSED) ** 1.5)


# MARK: Part one: the scroll, the pause and the sunset

def world(t, lang):
    copy = VIDEO[lang]
    full, dim, zoomed = scenes()
    if t < REVEAL:
        name = "bed" if t < 4.0 else "dinner" if t < 5.6 else "sunset"
        img = zoomed[name].convert("RGBA")
    else:
        k = smooth(seg(t, REVEAL, REVEAL + 1.4))
        z = ZOOM_BEFORE - (ZOOM_BEFORE - 1) * ease_out(seg(t, REVEAL, PROOF))
        img = Image.blend(zoom(dim["sunset"], z), zoom(full["sunset"], z), k).convert("RGBA")

    # The phone, which slides away into a pocket at the reveal.
    leave = smooth(seg(t, REVEAL, REVEAL + 1.4))
    if leave < 1:
        s = 1 - 0.4 * leave
        cy = PHONE_CY + 1300 * leave
        put_center(img, phone(t, lang), PHONE_CX, cy, s)
        if t < PIP_POPS + 1.2:
            away = smooth(seg(t, PIP_POPS + 0.6, PIP_POPS + 1.2))
            put(img, thumb(), 640 + 500 * away, 1320 - thumb_lift(t) + 700 * away)

    if PAUSED <= t < PAUSED + 0.12:
        put(img, Image.new("RGBA", (W, H), (255, 255, 255, 255)), 0, 0, 0.35 * (1 - seg(t, PAUSED, PAUSED + 0.12)))

    # Screen time ticking up, then frozen.
    k = 1 - seg(t, REVEAL, REVEAL + 0.4)
    if k > 0:
        c = counter(copy["counter"], minutes_at(t))
        put(img, c, (W - c.width) / 2, 480, k)

    # Words.
    hook = title(*copy["hook"], size=78)
    put(img, hook, 0, 210, 1 - seg(t, 2.4, 2.7))
    for i, (line, start) in enumerate(zip(copy["lines"], (2.6, 4.0, 5.6))):
        block = title(line, size=64, gradient=False)
        k = seg(t, start, start + 0.2) * (1 - seg(t, PAUSED - 0.2, PAUSED))
        put(img, block, 0, 190 + i * 74 + 20 * (1 - seg(t, start, start + 0.2)), k)
    if 4.1 <= t < 5.6:
        b = listen_bubble(copy["listen"])
        put_center(img, b, W - b.width / 2 - 20, 1000, back(seg(t, 4.1, 4.35)), 1 - seg(t, 5.4, 5.6))
    if t >= REVEAL + 0.8:
        k = seg(t, REVEAL + 0.8, REVEAL + 1.3)
        put(img, title(*copy["reveal"], size=100), 0, 250 + 30 * (1 - ease_out(k)), k)
    return img


@functools.lru_cache(None)
def listen_bubble(text_):
    return bubble(text_, 36, tail="left")


# MARK: Part two: the proof

def bars_card(label, average, value, hours, colors, p):
    cw, ch = 460, 680
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, cw - 1, ch - 1], 40, fill=(*CARD, 240), outline=(255, 255, 255, 40), width=2)
    d.text((cw / 2, 30), label, font=font(BLACK, 40), fill=WHITE, anchor="ma")
    d.text((32, 100), average, font=font(SEMI, 28), fill=GREY)
    d.text((32, 136), value, font=font(BLACK, 66), fill=WHITE)
    base, top = ch - 40, 250
    scale = (base - top) / 8
    slot = (cw - 64) / len(hours)
    bars = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bars)
    for i, hrs in enumerate(hours):
        bx = 32 + slot * i + slot * 0.18
        height = max(hrs * scale * p, 12)
        bd.rounded_rectangle([bx, base - height, bx + slot * 0.64, base], 10, fill=WHITE)
    gradient_fill(img, bars, colors)
    return img


def duration(minutes):
    return f"{int(minutes) // 60}h {int(minutes) % 60:02d}m"


@functools.lru_cache(None)
def league_card(lang):
    _, _, title_, names, unit = COPY["league"][lang]
    cw, ch = 940, 780
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    translucent(img, lambda d: d.rounded_rectangle([0, 0, cw - 1, ch - 1], 48, fill=(*CARD, 240),
                                                   outline=(255, 255, 255, 40), width=2))
    d = ImageDraw.Draw(img)
    d.text((44, 40), title_, font=font(BLACK, 46), fill=WHITE)
    trophy(img, cw - 90, 70, 110)
    rows = [(names[0], 1240, [VIOLET, PINK]), (names[1], 980, None), (names[2], 870, None)]
    row_h = (ch - 150) / 3
    for i, (name, points, colors) in enumerate(rows):
        ry = 130 + i * row_h
        if colors:
            highlight = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(highlight).rounded_rectangle([24, ry, cw - 24, ry + row_h - 16], 32, fill=WHITE)
            gradient_fill(img, highlight, colors, vertical=False)
        d = ImageDraw.Draw(img)
        mid = ry + (row_h - 16) / 2
        d.text((70, mid), str(i + 1), font=font(BLACK, 54), fill=WHITE, anchor="mm")
        avatar = 110
        if i == 0:
            img.alpha_composite(pip(avatar), (120, int(mid - avatar / 2)))
        else:
            d.ellipse([120, mid - avatar / 2, 120 + avatar, mid + avatar / 2], fill=ORANGE if i == 1 else CYAN)
            d.text((120 + avatar / 2, mid), name[0], font=font(BLACK, 48), fill=WHITE, anchor="mm")
        d = ImageDraw.Draw(img)
        d.text((150 + avatar, mid), name, font=font(BLACK, 52), fill=WHITE, anchor="lm")
        d.text((cw - 60, mid), f"{points:,}".replace(",", " ") + f" {unit}", font=font(BOLD, 42),
               fill=WHITE if colors else GREY, anchor="rm")
    return img


@functools.lru_cache(None)
def notification_card(lang):
    _, _, now, title_, body = COPY["notification"][lang]
    cw, ch = 960, 260
    img = Image.new("RGBA", (cw + 80, ch + 100), (0, 0, 0, 0))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 50, 40 + cw, 50 + ch], 56, fill=(0, 0, 0, 170))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))
    translucent(img, lambda d: d.rounded_rectangle([40, 26, 40 + cw, 26 + ch], 56, fill=(48, 40, 92, 250),
                                                   outline=(255, 255, 255, 50), width=3))
    img.alpha_composite(rounded(app_icon(130).convert("RGB")), (80, 26 + (ch - 130) // 2))
    d = ImageDraw.Draw(img)
    tx = 40 + 200
    d.text((tx, 26 + 56), "Paus", font=font(BOLD, 36), fill=GREY)
    d.text((40 + cw - 44, 26 + 58), now, font=font(SEMI, 32), fill=DIM, anchor="ra")
    tf = font(BLACK, 44)
    while d.textlength(title_, font=tf) > cw - 240:
        tf = font(BLACK, tf.size - 2)
    d.text((tx, 26 + 110), title_, font=tf, fill=WHITE)
    d.text((tx, 26 + 176), body, font=font(SEMI, 34), fill=GREY)
    return img


@functools.lru_cache(None)
def dark():
    return backdrop(W, H)


def headline_for(t, lang):
    beats = [("before-after", PROOF, LEAGUE), ("league", LEAGUE, NOTIFY), ("notification", NOTIFY, 99)]
    layers = []
    for name, a, b in beats:
        k = seg(t, a, a + 0.3) * (1 - seg(t, b - 0.15, b + 0.15))
        if k > 0:
            layers.append((title(*COPY[name][lang][:2], size=84), k))
    return layers


def proof(t, lang):
    img = dark().copy()
    for layer, k in headline_for(t, lang):
        put(img, layer, 0, 230, k)
    before, after = COPY["before-after"][lang][2]
    average = VIDEO[lang]["average"]

    if t < LEAGUE + 0.5:
        enter = ease_out(seg(t, PROOF + 0.1, PROOF + 0.6))
        leave = smooth(seg(t, LEAGUE, LEAGUE + 0.45))
        p = ease_out(seg(t, PROOF + 0.5, PROOF + 1.6))
        y = 600 + 140 * (1 - enter)
        dx = -W * leave
        put(img, bars_card(before, average, "6h 12m", (6.8, 5.6, 7.1, 6.2, 6.5), [ORANGE, PINK], p), 60 + dx, y, enter)
        put(img, bars_card(after, average, duration(372 - 188 * p), (3.4, 2.9, 3.1, 2.6, 3.2), [MINT, CYAN], p),
            560 + dx, y, enter)
        d = ImageDraw.Draw(img)
        d.text((W - 64 + dx, y + 700), COPY["before-after"][lang][3], font=font(SEMI, 24), fill=DIM, anchor="ra")

    if LEAGUE <= t < NOTIFY + 0.5:
        enter = ease_out(seg(t, LEAGUE, LEAGUE + 0.45))
        leave = smooth(seg(t, NOTIFY, NOTIFY + 0.45))
        put(img, league_card(lang), 70 + W * (1 - enter) - W * leave, 620)

    if t >= NOTIFY:
        drop = back(seg(t, NOTIFY + 0.15, NOTIFY + 0.6))
        card = notification_card(lang)
        put(img, card, (W - card.width) / 2, -400 + (640 + 400) * drop)
        pop = back(seg(t, NOTIFY + 0.5, NOTIFY + 0.85))
        if pop > 0:
            halo = Image.new("RGBA", (700, 700), (0, 0, 0, 0))
            ImageDraw.Draw(halo).ellipse([80, 80, 620, 620], fill=(*MINT, 90))
            put_center(img, halo.filter(ImageFilter.GaussianBlur(80)), W / 2, 1260, 1, clamp(pop))
            put_center(img, pip_big(), W / 2, 1260 + math.sin(t * 3) * 10, 0.9 * pop)
    return img


# MARK: Part three: the call to action

@functools.lru_cache(None)
def end_layers(lang):
    tagline = title(TAGLINE[lang], size=96, gradient=False)
    action = Image.new("RGBA", (W, 200), (0, 0, 0, 0))
    cta(action, lang, 150)
    halo = Image.new("RGBA", (900, 900), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([120, 120, 780, 780], fill=(*PINK, 90))
    return tagline, action, halo.filter(ImageFilter.GaussianBlur(100))


def end(t, lang):
    img = dark().copy()
    tagline, action, halo = end_layers(lang)
    pop = back(seg(t, END + 0.1, END + 0.5))
    put_center(img, halo, W / 2, 760, 1, clamp(pop))
    put_center(img, pip_big(), W / 2, 760 + math.sin(t * 3) * 12, 1.1 * pop)
    k = seg(t, END + 0.4, END + 0.7)
    put(img, tagline, 0, 1080 + 30 * (1 - ease_out(k)), k)
    k = back(seg(t, END + 0.8, END + 1.15))
    put_center(img, action, W / 2, 1360, k, clamp(k))
    return img


def frame(t, lang):
    if t < PROOF - CROSSFADE:
        return world(t, lang)
    if t < PROOF:
        return Image.blend(world(t, lang), proof(t, lang), seg(t, PROOF - CROSSFADE, PROOF))
    if t < END - CROSSFADE:
        return proof(t, lang)
    if t < END:
        return Image.blend(proof(t, lang), end(t, lang), seg(t, END - CROSSFADE, END))
    return end(t, lang)


# MARK: Sound

def soundtrack():
    n = int(DURATION * RATE)
    mix = np.zeros(n)
    rng = np.random.default_rng(1)

    def add(start, sig, gain=1.0):
        i = int(start * RATE)
        if i >= n:
            return
        sig = sig[: n - i]
        mix[i:i + len(sig)] += sig * gain

    def env(length, attack, release):
        e = np.ones(length)
        a, r = int(attack * RATE), int(release * RATE)
        if a:
            e[:a] = np.linspace(0, 1, a)
        if r:
            e[-r:] *= np.linspace(1, 0, r)
        return e

    def sine(freq, dur, harmonics=(1.0,)):
        t = np.arange(int(dur * RATE)) / RATE
        return sum(a * np.sin(2 * np.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))

    def lowpass(sig, width):
        return np.convolve(sig, np.ones(width) / width, mode="same")

    # A low, uneasy drone under the scrolling that stops dead at the pause.
    t = np.arange(int(PAUSED * RATE)) / RATE
    drone = (np.sin(2 * np.pi * 55 * t) + 0.5 * np.sin(2 * np.pi * 82.4 * t) + 0.3 * np.sin(2 * np.pi * 110.3 * t))
    drone *= (0.35 + 0.65 * t / PAUSED) * (0.8 + 0.2 * np.sin(2 * np.pi * (2 + 4 * t / PAUSED) * t))
    add(0, drone * env(len(drone), 0.3, 0.02), 0.06)

    # A whoosh for every swipe.
    start = SWIPE_START
    while start < SWIPES_END:
        noise = lowpass(rng.standard_normal(int(0.32 * RATE)), 6)
        e = np.sin(np.linspace(0, np.pi, len(noise))) ** 2
        add(start, noise * e, 0.05)
        start += SWIPE_EVERY

    # A tick for every minute the counter climbs, never closer than a ninth of a second.
    last, previous = -1.0, minutes_at(0)
    for i in range(int(PAUSED * FPS)):
        t = i / FPS
        m = minutes_at(t)
        if m != previous and t - last > 0.11:
            click = rng.standard_normal(int(0.012 * RATE)) * np.exp(-np.linspace(0, 8, int(0.012 * RATE)))
            add(t, click + 0.6 * sine(2200, 0.012) * np.exp(-np.linspace(0, 6, int(0.012 * RATE))), 0.16)
            last = t
        previous = m

    # The pop when Pip appears, and a blip for the speech bubble.
    tt = np.arange(int(0.14 * RATE)) / RATE
    add(PIP_POPS, np.sin(2 * np.pi * (260 * tt + 2200 * tt ** 2)) * np.exp(-tt * 25), 0.45)
    for f, d in [(880, 0), (1320, 0.06)]:
        add(PIP_POPS + 0.35 + d, sine(f, 0.09) * np.exp(-np.linspace(0, 5, int(0.09 * RATE))), 0.18)

    # The sea and warm chords once the world comes back.
    sea_len = int((END + 1.5 - REVEAL) * RATE)
    sea = lowpass(lowpass(rng.standard_normal(sea_len), 60), 60)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(sea_len) / RATE / 4.5)
    add(REVEAL, sea * swell * env(sea_len, 1.2, 1.2), 0.9)

    chords = [(REVEAL, PROOF + 0.4, [130.8, 196.0, 261.6, 329.6, 392.0]),
              (PROOF, END + 0.4, [174.6, 220.0, 261.6, 349.2, 440.0]),
              (END, DURATION, [130.8, 196.0, 261.6, 329.6, 392.0, 523.3])]
    for a, b, notes in chords:
        dur = b - a
        for f in notes:
            tone = sine(f * 1.002, dur, (1, 0.25)) + sine(f * 0.998, dur, (1,))
            add(a, tone * env(len(tone), 0.9, 0.8), 0.022)

    # Bright plucks under the results and the ending.
    scale = [523.3, 587.3, 659.3, 784.0, 880.0, 784.0, 659.3, 587.3]
    step = 0
    t = PROOF + 0.3
    while t < DURATION - 1.2:
        f = scale[step % len(scale)]
        pluck = sine(f, 0.45, (1, 0.3, 0.1)) * np.exp(-np.linspace(0, 7, int(0.45 * RATE)))
        add(t, pluck, 0.06)
        step += 1
        t += 0.3

    # Rising bars, sliding cards, the notification chime and the final pop.
    tt = np.arange(int(1.0 * RATE)) / RATE
    add(PROOF + 0.5, np.sin(2 * np.pi * (300 * tt + 300 * tt ** 2)) * env(len(tt), 0.1, 0.4), 0.05)
    for when in (LEAGUE, NOTIFY):
        noise = lowpass(rng.standard_normal(int(0.4 * RATE)), 4)
        add(when, noise * np.sin(np.linspace(0, np.pi, len(noise))) ** 2, 0.06)
    for f, d in [(1318.5, 0), (1975.5, 0.12)]:
        add(NOTIFY + 0.4 + d, sine(f, 0.9, (1, 0.2)) * np.exp(-np.linspace(0, 5, int(0.9 * RATE))), 0.14)
    tt = np.arange(int(0.14 * RATE)) / RATE
    add(END + 0.1, np.sin(2 * np.pi * (300 * tt + 2000 * tt ** 2)) * np.exp(-tt * 25), 0.35)

    mix *= env(n, 0.0, 1.2)
    mix /= max(1e-9, np.abs(mix).max()) / 0.89
    return mix


def write_wav(path, mono):
    data = (np.clip(mono, -1, 1) * 32767).astype(np.int16)
    stereo = np.repeat(data[:, None], 2, 1)
    with wave.open(path, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(stereo.tobytes())


# MARK: Output

def render(lang, path):
    with tempfile.TemporaryDirectory() as tmp:
        audio = os.path.join(tmp, "sound.wav")
        write_wav(audio, soundtrack())
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
             "-r", str(FPS), "-i", "-", "-i", audio, "-c:v", "libx264", "-preset", "medium", "-crf", "18",
             "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p", "-color_primaries", "bt709",
             "-color_trc", "bt709", "-colorspace", "bt709", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", path],
            stdin=subprocess.PIPE)
        for i in range(int(DURATION * FPS)):
            ffmpeg.stdin.write(frame(i / FPS, lang).convert("RGB").tobytes())
        ffmpeg.stdin.close()
        if ffmpeg.wait() != 0:
            raise SystemExit("ffmpeg failed")


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--stills":
        out = sys.argv[3] if len(sys.argv) > 3 else "."
        for t in sys.argv[2].split(","):
            for lang in ("sv", "en"):
                frame(float(t), lang).convert("RGB").save(os.path.join(out, f"still-{lang}-{t}.png"))
        return
    for lang in ("sv", "en"):
        folder = os.path.join(OUT, "ads", lang)
        os.makedirs(folder, exist_ok=True)
        render(lang, os.path.join(folder, "thumb-video-1080x1920.mp4"))


if __name__ == "__main__":
    main()
