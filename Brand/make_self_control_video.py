"""A fast-cut "self-control" edit: a stick figure on the floor with the phone and the excuses we tell ourselves,
a dictionary card, quick typographic cuts, then the yearly numbers and Paus.

Run from the repository root: python3 Brand/make_self_control_video.py
Stills: python3 Brand/make_self_control_video.py --stills 1,6,7.3,8,8.7,9.4,10.1,10.8,11.5,12.3,14,16.5,19 out_dir
"""
import functools
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from make_brand import BLACK, OUT, SEMI, app_icon, rounded
from make_video import RATE, back, clamp, ease_out, seg, smooth, write_wav

W, H, FPS = 1080, 1920, 30
FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
SERIF = os.path.join(FONTS, "DMSerifDisplay-Regular.ttf")
SERIF_ITALIC = os.path.join(FONTS, "DMSerifDisplay-Italic.ttf")
CONDENSED = os.path.join(FONTS, "Oswald-Variable.ttf")

YELLOW = (236, 255, 60)
GOLD = (232, 196, 120)
RED = (220, 40, 40)

# The cuts, in order: (start, scene name).
CUTS = [
    (0.0, "floor"), (5.6, "definition"), (7.0, "control"), (7.7, "old"), (8.4, "versus"), (9.1, "again"),
    (9.8, "better"), (10.5, "tired"), (11.2, "born"), (11.9, "focus"), (12.8, "hours"), (15.0, "days"),
    (17.4, "app"), (20.4, "outro"),
]
DURATION = 21.6

COPY = {
    "sv": {
        "quotes": ["”Bara fem minuter till…”", "”Jag börjar imorgon…”", "”Jag kan inte sluta…”"],
        "word": "självkontroll", "kind": "subst.",
        "definition": "Förmågan att styra sina impulser och sitt\nbeteende, även när frestelsen är som störst.",
        "control": ("Själv", "kontroll"),
        "old": ("glöm den", "gamla mig."),
        "versus": "du mot dig ",
        "again": ("Om du", "faller", "Försök igen.", "& igen"),
        "better": ("ÄR DU", "BÄTTRE", "ÄN IGÅR?"),
        "tired": ("Är du", "trött?", "Gör det", "trött."),
        "born": "Född att vinna.",
        "focus": "FOKUS",
        "hours": ("5 timmar om dagen.", "timmar om året."),
        "days": ("76 dygn.", "Varje år."),
        "app": ("SÖK · APP STORE", "PAUS:", "Halvera din skärmtid", "Ta tillbaka dem."),
    },
    "en": {
        "quotes": ["“Just five more minutes…”", "“I'll start tomorrow…”", "“I can't stop…”"],
        "word": "self-control", "kind": "noun",
        "definition": "The ability to control your impulses and\nbehaviour, even when temptation is strongest.",
        "control": ("Self ", "Control"),
        "old": ("forget the", "old me."),
        "versus": "you vs you ",
        "again": ("If you", "fall", "Try again.", "& again"),
        "better": ("ARE YOU", "BETTER", "THAN YESTERDAY?"),
        "tired": ("If you are", "tired,", "do it", "tired."),
        "born": "Born to win.",
        "focus": "FOCUS",
        "hours": ("5 hours a day.", "hours a year."),
        "days": ("76 days.", "Every year."),
        "app": ("SEARCH · APP STORE", "PAUS:", "Halve your screen time", "Take them back."),
    },
}


@functools.lru_cache(None)
def font(path, size, variation=None):
    f = ImageFont.truetype(path, size)
    if variation:
        f.set_variation_by_name(variation)
    return f


def text_size(d, s, f):
    l, t, r, b = d.textbbox((0, 0), s, font=f)
    return r - l, b - t


@functools.lru_cache(None)
def grain(w, h, base, amount, seed):
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w, 3), np.float32) + base
    img += rng.normal(0, amount, (h, w, 1))
    coarse = rng.normal(0, amount * 0.8, (h // 6 + 1, w // 6 + 1, 1)).repeat(6, 0).repeat(6, 1)[:h, :w]
    img += coarse
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def vignette(img, strength=0.75, color=(0, 0, 0)):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((x - W / 2) / (W * 0.62)) ** 2 + ((y - H / 2) / (H * 0.62)) ** 2)
    a = (np.clip(r - 0.45, 0, 1) / 0.55) ** 1.6 * strength
    layer = np.zeros((H, W, 4), np.uint8)
    layer[..., :3] = color
    layer[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    img.alpha_composite(Image.fromarray(layer, "RGBA"))


@functools.lru_cache(None)
def vignette_layer(strength, color):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vignette(img, strength, color)
    return img


def black():
    return Image.new("RGBA", (W, H), (0, 0, 0, 255))


def fade(t, start, end, fade_in=0.25, fade_out=0.3):
    return smooth(seg(t, start, start + fade_in)) * (1 - smooth(seg(t, end - fade_out, end)))


def centered(d, y, s, f, fill):
    w, _ = text_size(d, s, f)
    d.text(((W - w) / 2, y), s, font=f, fill=fill)


# MARK: Scenes

def stick_figure(img, t):
    """Lying on the floor, head by the phone, its light flickering with each video."""
    d = ImageDraw.Draw(img)
    white, width = (235, 235, 235), 6
    hx, hy, hr = 470, 900, 62
    flicker = [(255, 120, 60), (80, 160, 255), (255, 90, 160), (255, 200, 80)][int(t / 0.45) % 4]
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([200, 760, 560, 1060], fill=(*flicker, 70))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
    d = ImageDraw.Draw(img)
    # The phone, on its side by the face.
    phone = Image.new("RGBA", (120, 210), (0, 0, 0, 0))
    pd = ImageDraw.Draw(phone)
    pd.rounded_rectangle([4, 4, 116, 206], 18, outline=white, width=width)
    pd.rounded_rectangle([16, 18, 104, 192], 8, fill=flicker)
    phone = phone.rotate(18, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(phone, (250, 800))
    d = ImageDraw.Draw(img)
    # Head, an eye on the screen, a flat mouth.
    d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], outline=white, width=width)
    d.ellipse([hx - 30, hy - 10, hx - 18, hy + 2], fill=white)
    d.line([(hx - 28, hy + 26), (hx - 6, hy + 30)], fill=white, width=4)
    # Body, arms and legs, lying back.
    neck, hip = (hx + 55, hy + 30), (hx + 250, hy + 120)
    d.line([neck, hip], fill=white, width=width)
    d.line([(hx + 95, hy + 50), (hx + 10, hy + 95), (hx - 70, hy + 40)], fill=white, width=width, joint="curve")
    d.line([(hx + 110, hy + 58), (hx + 210, hy + 10), (hx + 290, hy + 30)], fill=white, width=width, joint="curve")
    d.line([hip, (hx + 360, hy + 40), (hx + 450, hy + 170)], fill=white, width=width, joint="curve")
    d.line([hip, (hx + 330, hy + 200), (hx + 470, hy + 230)], fill=white, width=width, joint="curve")


def floor(t, c):
    img = black()
    stick_figure(img, t)
    d = ImageDraw.Draw(img)
    f = font(SEMI, 48)
    for i, quote in enumerate(c["quotes"]):
        start = 0.3 + i * 1.65
        k = fade(t, start, start + 1.6)
        if k > 0:
            w, _ = text_size(d, quote, f)
            layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(layer).text(((W - w) / 2, 560), quote, font=f, fill=(240, 240, 240, int(255 * k)))
            img.alpha_composite(layer)
    return img


def definition(t, c):
    img = floor(t, c)
    k = back(seg(t, 5.6, 5.9))
    card = Image.new("RGBA", (820, 380), (250, 250, 248, 255))
    d = ImageDraw.Draw(card)
    d.rectangle([0, 0, 819, 379], outline=(30, 30, 30), width=3)
    d.text((48, 40), c["word"], font=font(BLACK, 58), fill=(15, 15, 15))
    d.text((48, 118), c["kind"], font=font(SERIF_ITALIC, 34), fill=(110, 110, 110))
    d.multiline_text((48, 190), c["definition"], font=font(SEMI, 32), fill=(40, 40, 40), spacing=14)
    s = 0.85 + 0.15 * k
    card = card.resize((int(card.width * s), int(card.height * s)), Image.LANCZOS)
    img.alpha_composite(card, ((W - card.width) // 2, 560 - card.height // 2 + 40))
    return img


def control(t, c):
    img = black()
    d = ImageDraw.Draw(img)
    a, b = c["control"]
    f = font(BLACK, 120)
    wa, _ = text_size(d, a, f)
    wb, h = text_size(d, b, f)
    x = (W - wa - wb) / 2
    s = 1 + 0.04 * seg(t, 7.0, 7.7)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.text((x, H / 2 - h), a, font=f, fill="white")
    ld.text((x + wa, H / 2 - h), b, font=f, fill=YELLOW)
    big = layer.resize((int(W * s), int(H * s)), Image.LANCZOS)
    img.alpha_composite(big.crop(((big.width - W) // 2, (big.height - H) // 2, (big.width - W) // 2 + W, (big.height - H) // 2 + H)))
    return img


def old(t, c):
    img = grain(W, H, 22, 10, 1).convert("RGBA")
    img.alpha_composite(vignette_layer(0.9, (0, 0, 0)))
    d = ImageDraw.Draw(img)
    a, b = c["old"]
    f = font(SERIF, 130)
    drift = 30 * seg(t, 7.7, 8.4)
    wa, _ = text_size(d, a, f)
    wb, _ = text_size(d, b, f)
    d.text((W - 90 - wa - drift, 700), a, font=f, fill=(225, 225, 220))
    d.text((W - 70 - wb - drift, 850), b, font=f, fill=(225, 225, 220))
    return img


def versus(t, c):
    img = grain(W, H, 205, 12, 2).convert("RGBA")
    d = ImageDraw.Draw(img)
    f = font(SERIF, 330)
    text = c["versus"] * 3
    w, h = text_size(d, text, f)
    x = 200 - (w / 3) * seg(t, 8.4, 9.1) * 0.9
    d.rectangle([0, H / 2 - 110, W, H / 2 + 150], fill=(*YELLOW, 255))
    d.text((x, H / 2 - 230), text, font=f, fill=(25, 25, 22))
    img.alpha_composite(vignette_layer(0.7, (0, 0, 0)))
    return img


def again(t, c):
    img = black()
    d = ImageDraw.Draw(img)
    lead, fall, first, more = c["again"]
    d.text((60, 860), lead, font=font(BLACK, 72), fill="white")
    d.text((60, 945), fall, font=font(BLACK, 72), fill="white")
    d.line([(330, 960), (430, 960)], fill="white", width=5)
    d.line([(430, 760), (430, 1160), (480, 1160)], fill="white", width=5)
    d.line([(430, 760), (480, 760)], fill="white", width=5)
    paper = grain(520, 760, 225, 10, 3).convert("RGBA")
    pd = ImageDraw.Draw(paper)
    f = font(SERIF, 64)
    w, h = text_size(pd, first, f)
    pd.rectangle([40, 60, 60 + w, 60 + h + 26], fill=YELLOW)
    pd.text((50, 50), first, font=f, fill=(20, 20, 20))
    shown = int(seg(t, 9.1, 9.7) * 7)
    for i in range(shown):
        tone = int(30 + i * 30)
        pd.text((50, 150 + i * 82), more, font=f, fill=(tone, tone, tone))
    img.alpha_composite(paper, (500, 580))
    return img


def better(t, c):
    img = black()
    d = ImageDraw.Draw(img)
    s = 1 + 0.06 * seg(t, 9.8, 10.5)
    y = 640
    for i, line in enumerate(c["better"]):
        size = int((170 if i < 2 else 92) * s)
        f = font(CONDENSED, size, "Bold")
        centered(d, y, line, f, "white" if i < 2 else (200, 200, 200))
        y += size * 1.3
    return img


def tired(t, c):
    img = grain(W, H, 238, 8, 4).convert("RGBA")
    img.alpha_composite(vignette_layer(0.85, (40, 40, 40)))
    d = ImageDraw.Draw(img)
    f = font(SERIF, 112)
    lines = c["tired"]
    for i, line in enumerate(lines):
        w, _ = text_size(d, line, f)
        x = 120 if i < 2 else W - 120 - w
        d.text((x, 600 + i * 130 + (60 if i >= 2 else 0)), line, font=f, fill=(15, 15, 15))
    return img


def born(t, c):
    img = black()
    d = ImageDraw.Draw(img)
    k = smooth(seg(t, 11.2, 11.5))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    centered(ImageDraw.Draw(layer), H / 2 - 70, c["born"], font(SERIF, 120), (240, 240, 240, int(255 * k)))
    img.alpha_composite(layer)
    return img


def focus(t, c):
    img = black()
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(CONDENSED, 250, "Bold")
    word = c["focus"]
    step = 300
    top = H / 2 - step * len(word) / 2
    for i, ch in enumerate(word):
        w, _ = text_size(d, ch, f)
        d.text(((W - w) / 2, top + i * step), ch, font=f, fill="white")
    blur = 26 * (1 - ease_out(seg(t, 11.9, 12.6)))
    if blur > 0.5:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer)
    return img


def hours(t, c):
    img = black()
    d = ImageDraw.Draw(img)
    small, under = c["hours"]
    d.text((110, 690), small, font=font(SERIF, 46), fill=(220, 220, 220))
    n = int(round(1825 * ease_out(seg(t, 12.9, 14.0))))
    number = f"{n:,}".replace(",", " ")
    d.text((100, 760), number, font=font(SERIF, 300), fill="white")
    d.text((110, 1110), under, font=font(SERIF, 54), fill=(220, 220, 220))
    return img


def days(t, c):
    img = black()
    d = ImageDraw.Draw(img)
    cols, rows, cell, gap = 19, 20, 34, 6
    x0 = (W - cols * (cell + gap)) / 2
    y0 = 380
    rng = np.random.default_rng(9)
    red = set(rng.choice(365, 76, replace=False).tolist())
    order = sorted(red)
    rng.shuffle(order)
    shown = set(order[: int(len(order) * ease_out(seg(t, 15.2, 16.6)))])
    for i in range(365):
        x, y = x0 + (i % cols) * (cell + gap), y0 + (i // cols) * (cell + gap)
        fill = RED if i in shown else (28, 28, 28)
        d.rectangle([x, y, x + cell, y + cell], fill=fill, outline=(55, 55, 55))
    a, b = c["days"]
    d.text((x0, 1220), a, font=font(SERIF, 64), fill="white")
    d.text((x0, 1300), b, font=font(SERIF, 64), fill="white")
    return img


@functools.lru_cache(None)
def app_background():
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, bottom = np.array([14, 14, 34], np.float32), np.array([2, 2, 8], np.float32)
    img = top + (bottom - top) * y
    return Image.fromarray(np.broadcast_to(img, (H, W, 3)).astype(np.uint8), "RGB").convert("RGBA")


def app(t, c):
    img = app_background().copy()
    search, name, line, back_line = c["app"]
    d = ImageDraw.Draw(img)
    k = [ease_out(seg(t, 17.4 + i * 0.25, 17.8 + i * 0.25)) for i in range(5)]
    icon = rounded(app_icon(130))
    icon.putalpha(icon.getchannel("A").point(lambda v: int(v * k[0])))
    img.alpha_composite(icon, (110, 640 - int(20 * (1 - k[0]))))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.text((112, 820), search, font=font(SEMI, 26), fill=(160, 160, 190, int(255 * k[1])))
    ld.text((105, 870), name, font=font(SERIF, 130), fill=(240, 240, 245, int(255 * k[2])))
    ld.text((105, 1010), line, font=font(SERIF_ITALIC, 92), fill=(*GOLD, int(255 * k[3])))
    ld.line([(110, 1150), (190, 1150)], fill=(120, 120, 150, int(255 * k[4])), width=2)
    ld.text((110, 1180), back_line, font=font(SERIF, 46), fill=(200, 200, 215, int(255 * k[4])))
    img.alpha_composite(layer)
    return img


def outro(t, c):
    img = black()
    k = fade(t, 20.4, DURATION, 0.3, 0.6)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    centered(ImageDraw.Draw(layer), H / 2 - 50, "PAUS", font(SERIF, 90), (90, 90, 95, int(255 * k)))
    img.alpha_composite(layer)
    return img


SCENES = {f.__name__: f for f in (floor, definition, control, old, versus, again, better, tired, born, focus, hours, days, app, outro)}


def frame(t, lang):
    name = [n for start, n in CUTS if t >= start][-1]
    img = SCENES[name](t, COPY[lang])
    # A white flash on each hard cut in the fast section.
    for start, n in CUTS:
        if 7.0 <= start <= 12.8 and 0 <= t - start < 0.06:
            img.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, 60)))
    return img.convert("RGB")


# MARK: Sound

def soundtrack():
    n = int(DURATION * RATE)
    mix = np.zeros(n)
    rng = np.random.default_rng(5)

    def add(start, sig, gain):
        i = int(start * RATE)
        sig = sig[: max(0, n - i)]
        mix[i:i + len(sig)] += sig * gain

    def hit(start, gain=0.55):
        tt = np.arange(int(0.5 * RATE)) / RATE
        add(start, np.sin(2 * np.pi * (70 * tt - 30 * tt ** 2)) * np.exp(-tt * 7), gain)
        noise = rng.standard_normal(int(0.05 * RATE)) * np.exp(-np.linspace(0, 6, int(0.05 * RATE)))
        add(start, noise, 0.08)

    # A dark drone under the floor scene, swelling into the cuts.
    tt = np.arange(int(7.0 * RATE)) / RATE
    drone = sum(np.sin(2 * np.pi * f * tt) for f in (55, 55.4, 82.5)) / 3
    add(0, drone * np.minimum(1, tt / 1.5) * (0.6 + 0.4 * tt / 7), 0.12)
    for i in range(3):
        noise = np.convolve(rng.standard_normal(int(0.3 * RATE)), np.ones(30) / 30, mode="same")
        add(0.3 + i * 1.65, noise * np.sin(np.linspace(0, np.pi, len(noise))), 0.15)
    add(5.6, np.convolve(rng.standard_normal(int(0.25 * RATE)), np.ones(4) / 4, mode="same") * np.exp(-np.linspace(0, 5, int(0.25 * RATE))), 0.12)
    # The fast cuts: a hit on each, over a pulse.
    for start, name in CUTS:
        if 7.0 <= start <= 12.8:
            hit(start)
    tt = np.arange(int(5.8 * RATE)) / RATE
    add(7.0, np.sin(2 * np.pi * 41 * tt) * (np.sin(2 * np.pi * 2.85 * tt) > 0.6), 0.1)
    # The numbers: ticks while counting, a click per red day.
    for i in range(30):
        tick = rng.standard_normal(int(0.01 * RATE)) * np.exp(-np.linspace(0, 8, int(0.01 * RATE)))
        add(12.9 + 1.1 * (1 - (1 - i / 30) ** (1 / 3)), tick, 0.12)
    for i in range(25):
        tick = np.sin(2 * np.pi * 1800 * np.arange(int(0.02 * RATE)) / RATE) * np.exp(-np.linspace(0, 8, int(0.02 * RATE)))
        add(15.2 + 1.4 * (1 - (1 - i / 25) ** (1 / 3)), tick, 0.05)
    # The app: a slow, hopeful chord.
    dur = DURATION - 17.4
    tt = np.arange(int(dur * RATE)) / RATE
    for f in (196.0, 246.9, 293.7, 392.0, 493.9):
        add(17.4, np.sin(2 * np.pi * f * tt) * np.minimum(1, tt / 0.8) * np.linspace(1, 0, len(tt)) ** 0.8, 0.035)
    return mix


def render(lang, path):
    with tempfile.TemporaryDirectory() as tmp:
        audio = os.path.join(tmp, "sound.wav")
        write_wav(audio, soundtrack())
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
             "-r", str(FPS), "-i", "-", "-i", audio, "-c:v", "libx264", "-preset", "medium", "-crf", "18",
             "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p", "-color_primaries", "bt709",
             "-color_trc", "bt709", "-colorspace", "bt709", "-c:a", "aac", "-b:a", "192k", "-shortest",
             "-movflags", "+faststart", path],
            stdin=subprocess.PIPE)
        for i in range(int(DURATION * FPS)):
            ffmpeg.stdin.write(frame(i / FPS, lang).tobytes())
        ffmpeg.stdin.close()
        if ffmpeg.wait() != 0:
            raise SystemExit("ffmpeg failed")
    print(path)


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--stills":
        out = sys.argv[3] if len(sys.argv) > 3 else "."
        for t in sys.argv[2].split(","):
            frame(float(t), "sv").save(os.path.join(out, f"sc-{t}.png"))
        return
    for lang in ("sv", "en"):
        render(lang, os.path.join(OUT, "ads", lang, "real-life", "self-control-1080x1920.mp4"))


if __name__ == "__main__":
    main()
