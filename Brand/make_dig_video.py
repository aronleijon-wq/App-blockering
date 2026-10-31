"""The "keep digging" ad: someone in a mine stops digging to scroll, smirks, and the camera pulls back to show a
wall of diamonds, each one a thing they want from life, right behind the rock they stopped at.

Run from the repository root: python3 Brand/make_dig_video.py
Stills for checking the look: python3 Brand/make_dig_video.py --stills 1,3.5,6,10,13 out_dir
"""
import functools
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import BLACK, OUT, font
from make_video import END, RATE, back, clamp, ease_out, end, put_center, seg, smooth, write_wav

W, H, FPS = 1080, 1920, 30

SCROLL = 0.0          # Medium shot: scrolling in the mine.
FACE = 3.0            # Close-up: the smirk.
REVEAL = 4.4          # Cut to the wide shot, pulling back.
WORDS = 6.0           # The diamonds get their names.
PUNCH = 11.2          # "Lägg ner mobilen. Fortsätt gräva."
END_CARD = 12.8
END_LENGTH = 3.2
DURATION = END_CARD + END_LENGTH

COPY = {
    "sv": {
        "hook": "bara en video till…",
        "missing": "det du missar:",
        "words": ["Drömkroppen", "Bättre betyg", "Egen firma", "Disciplin", "Pengar", "Resor", "Relationer",
                  "Bättre sömn", "Självförtroende", "Familjen"],
        "punch": ("Lägg ner mobilen.", "Fortsätt gräva."),
    },
    "en": {
        "hook": "just one more video…",
        "missing": "what you're missing:",
        "words": ["Dream body", "Better grades", "Own business", "Discipline", "Money", "Travel", "Relationships",
                  "Better sleep", "Confidence", "Family"],
        "punch": ("Put the phone down.", "Keep digging."),
    },
}

SKIN = (246, 214, 186)
HAIR = (58, 44, 38)
HOODIE = (92, 70, 170)
JEANS = (44, 52, 78)
SHOE = (30, 28, 34)
INK = (26, 22, 30)
DIRT = (120, 82, 52)
DIRT_DARK = (86, 58, 38)
TUNNEL = (150, 146, 140)
GLOWS = [(80, 170, 255), (255, 80, 150), (255, 210, 70), (120, 255, 200)]


# MARK: Drawing

def glow_color(t):
    """The phone's light on the face changes with each video, like swiping through a feed."""
    i = int(t / 0.55) % len(GLOWS)
    return GLOWS[i]


def person(img, cx, feet, h, t, smirk=False):
    """A person in a hoodie scrolling a phone, `h` tall, standing on `feet`, facing the viewer."""
    d = ImageDraw.Draw(img)
    u = h / 100
    head_r = 9.5 * u
    head_cy = feet - 89 * u
    # Legs and shoes
    for sx in (-1, 1):
        d.rounded_rectangle([cx + sx * 1.2 * u - (8.5 * u if sx < 0 else 0), feet - 44 * u,
                             cx + sx * 1.2 * u + (8.5 * u if sx > 0 else 0), feet - 3 * u], 3 * u, fill=JEANS)
        d.rounded_rectangle([cx + sx * 6 * u - 7 * u, feet - 5 * u, cx + sx * 6 * u + 7 * u, feet], 2.5 * u, fill=SHOE)
    # Hoodie body
    d.rounded_rectangle([cx - 15 * u, feet - 78 * u, cx + 15 * u, feet - 40 * u], 7 * u, fill=HOODIE)
    d.polygon([(cx - 6 * u, feet - 78 * u), (cx, feet - 72 * u), (cx + 6 * u, feet - 78 * u)], fill=(70, 52, 140))
    # Hanging left arm, raised right arm holding the phone in front of the chest
    d.rounded_rectangle([cx - 20 * u, feet - 75 * u, cx - 12 * u, feet - 46 * u], 4 * u, fill=HOODIE)
    d.ellipse([cx - 20 * u, feet - 49 * u, cx - 12 * u, feet - 42 * u], fill=SKIN)
    d.line([(cx + 15 * u, feet - 73 * u), (cx + 18 * u, feet - 58 * u), (cx + 6 * u, feet - 62 * u)], fill=HOODIE, width=int(8 * u), joint="curve")
    d.rounded_rectangle([cx - 1 * u, feet - 71 * u, cx + 9 * u, feet - 56 * u], 1.6 * u, fill=INK)
    screen = glow_color(t)
    d.rounded_rectangle([cx + 0.2 * u, feet - 70 * u, cx + 7.8 * u, feet - 57 * u], 1.2 * u, fill=screen)
    d.ellipse([cx + 1 * u, feet - 62 * u, cx + 9 * u, feet - 56 * u], fill=SKIN)
    # Head, hair
    d.ellipse([cx - head_r, head_cy - head_r * 1.05, cx + head_r, head_cy + head_r * 1.05], fill=SKIN)
    d.chord([cx - head_r * 1.05, head_cy - head_r * 1.2, cx + head_r * 1.05, head_cy + head_r * 0.5], 180, 360, fill=HAIR)
    d.ellipse([cx - head_r * 1.05, head_cy - head_r * 0.6, cx - head_r * 0.6, head_cy + head_r * 0.1], fill=HAIR)
    # Face: eyes on the phone, or a sly look and a smirk at the camera
    ey = head_cy + head_r * 0.12
    for sx in (-1, 1):
        ex = cx + sx * head_r * 0.38
        if smirk:
            d.ellipse([ex - 1.6 * u, ey - 1.0 * u, ex + 1.6 * u, ey + 1.4 * u], fill="white")
            d.ellipse([ex + 0.1 * u, ey - 0.6 * u, ex + 1.5 * u, ey + 1.1 * u], fill=INK)
            d.line([(ex - 2 * u, ey - 1.6 * u), (ex + 2 * u, ey - 1.0 * u)], fill=INK, width=max(1, int(0.9 * u)))
        else:
            d.ellipse([ex - 1.1 * u, ey + 0.2 * u, ex + 1.1 * u, ey + 1.6 * u], fill=INK)
    if smirk:
        d.arc([cx - head_r * 0.25, head_cy + head_r * 0.25, cx + head_r * 0.55, head_cy + head_r * 0.7], 10, 120, fill=INK, width=max(1, int(1.0 * u)))
    else:
        d.line([(cx - head_r * 0.15, head_cy + head_r * 0.55), (cx + head_r * 0.15, head_cy + head_r * 0.55)], fill=INK, width=max(1, int(0.8 * u)))
    # The phone's light on the face
    light = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(light).ellipse([cx - head_r * 1.1, head_cy - head_r * 0.6, cx + head_r * 1.1, head_cy + head_r * 1.3], fill=(*screen, 70))
    img.alpha_composite(light.filter(ImageFilter.GaussianBlur(head_r * 0.4)))
    # The pickaxe, leaning against the leg
    d = ImageDraw.Draw(img)
    d.line([(cx + 22 * u, feet), (cx + 11 * u, feet - 34 * u)], fill=(140, 96, 56), width=int(2.4 * u))
    d.arc([cx + 1 * u, feet - 42 * u, cx + 25 * u, feet - 26 * u], 190, 330, fill=(150, 156, 166), width=int(2.6 * u))


def earth(w, h, seed=1):
    rng = np.random.default_rng(seed)
    base = np.zeros((h, w, 3), np.float32) + DIRT
    noise = rng.normal(0, 1, (h // 8 + 1, w // 8 + 1)).repeat(8, 0).repeat(8, 1)[:h, :w]
    base += noise[..., None] * 9
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(w * h // 9000):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(4, 14) * w / 1080
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=DIRT_DARK)
    return img


def tunnel_shot(t, s):
    """Inside the mine: a grey rock face behind, dirt framing the tunnel, the person in the middle."""
    img = earth(W, H, seed=3)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([60, 420, W - 60, H - 380], 120, fill=TUNNEL)
    d.rectangle([60, H - 520, W - 60, H - 380], fill=(124, 116, 106))
    big = img.resize((int(W * s), int(H * s)), Image.LANCZOS)
    img = big.crop(((big.width - W) // 2, (big.height - H) // 2, (big.width - W) // 2 + W, (big.height - H) // 2 + H))
    person(img, W / 2, H - 470 * s + (s - 1) * 300, 1000 * s, t)
    return img


def face_shot(t, s):
    img = Image.new("RGBA", (W, H), TUNNEL + (255,))
    person(img, W / 2 - 40, H / 2 + 89 * 46 * s + 60, 4600 * s, t, smirk=True)
    return img


@functools.lru_cache(None)
def world():
    """The wide picture, twice the frame size: a thin tunnel at the bottom left, and diamonds everywhere
    past the last few centimetres of rock."""
    w, h = W * 2, H * 2
    img = Image.new("RGBA", (w, h), (205, 240, 250, 255))
    rng = np.random.default_rng(7)
    d = ImageDraw.Draw(img)
    for _ in range(1500):
        x, y = rng.uniform(-60, w + 60), rng.uniform(-60, h + 60)
        r = rng.uniform(34, 62)
        a = rng.uniform(0, math.pi)
        pts = [(x + r * math.cos(a + k * math.pi / 3) * (1 if k % 2 else 0.75), y + r * math.sin(a + k * math.pi / 3) * (1 if k % 2 else 0.75)) for k in range(6)]
        shade = rng.choice([0, 1, 2])
        fill = [(160, 220, 245), (120, 195, 235), (225, 248, 255)][shade]
        d.polygon(pts, fill=fill, outline=(70, 140, 190))
        d.line([pts[0], pts[3]], fill=(90, 160, 205), width=3)
        d.line([pts[1], pts[4]], fill=(255, 255, 255), width=2)
    # Rock around the tunnel, a thin wall at its end, and the tunnel itself.
    rock = earth(w, h, seed=5)
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([-200, 2960, 1120, 3840 + 200], 140, fill=255)
    img.paste(rock, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([-100, 3120, 1000, 3560], 90, fill=TUNNEL)
    return img


def wide_shot(t):
    p = ease_out(seg(t, REVEAL, REVEAL + 1.4))
    # From the tunnel's end to the whole picture.
    cw = 700 + (W * 2 - 700) * p
    ch = cw * H / W
    cx = 760 + (W - 760) * p
    cy = 3320 + (H - 3320) * p
    cx = min(max(cx, cw / 2), W * 2 - cw / 2)
    cy = min(max(cy, ch / 2), H * 2 - ch / 2)
    base = world().copy()
    person(base, 820, 3540, 380, t)
    return base.crop((int(cx - cw / 2), int(cy - ch / 2), int(cx + cw / 2), int(cy + ch / 2))).resize((W, H), Image.BILINEAR)


@functools.lru_cache(None)
def word_layer(text, size=84):
    f = font(BLACK, size)
    l, t, r, b = f.getbbox(text, stroke_width=8)
    layer = Image.new("RGBA", (r - l + 10, b - t + 10), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((5 - l, 5 - t), text, font=f, fill=(255, 214, 60), stroke_width=8, stroke_fill=INK)
    return layer


@functools.lru_cache(None)
def caption_layer(text, size=70):
    f = font(BLACK, size)
    l, t, r, b = f.getbbox(text, stroke_width=7)
    layer = Image.new("RGBA", (r - l + 10, b - t + 10), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((5 - l, 5 - t), text, font=f, fill="white", stroke_width=7, stroke_fill=INK)
    return layer


# Where each word sits in the wide shot, inside the area stories and reels leave free.
SPOTS = [(540, 440), (290, 590), (780, 700), (380, 830), (800, 960), (280, 1080), (700, 1200),
         (330, 1320), (560, 1430), (790, 1555)]


def frame(t, lang):
    c = COPY[lang]
    if t < FACE:
        img = tunnel_shot(t, 1 + 0.06 * t / FACE)
        k = ease_out(seg(t, 0.2, 0.5))
        put_center(img, caption_layer(c["hook"]), W / 2, 330, 0.9 + 0.1 * k, k)
    elif t < REVEAL:
        img = face_shot(t, 1 + 0.05 * seg(t, FACE, REVEAL))
    else:
        img = wide_shot(t).convert("RGBA")
        k = ease_out(seg(t, REVEAL + 1.0, REVEAL + 1.4)) * (1 - seg(t, PUNCH - 0.3, PUNCH))
        put_center(img, caption_layer(c["missing"]), W / 2, 300, 1, k)
        out = 1 - seg(t, PUNCH - 0.3, PUNCH)
        for i, word in enumerate(c["words"]):
            start = WORDS + i * 0.45
            pop = back(seg(t, start, start + 0.3))
            if pop > 0:
                put_center(img, word_layer(word), *SPOTS[i], pop, clamp(pop) * out)
        if t >= PUNCH:
            dim = Image.new("RGBA", (W, H), (10, 8, 20, int(170 * smooth(seg(t, PUNCH - 0.2, PUNCH + 0.3)))))
            img.alpha_composite(dim)
            for j, line in enumerate(c["punch"]):
                k = back(seg(t, PUNCH + j * 0.45, PUNCH + j * 0.45 + 0.35))
                put_center(img, caption_layer(line, 92), W / 2, 860 + j * 130, k, clamp(k))
    if t >= END_CARD:
        k = smooth(seg(t, END_CARD, END_CARD + 0.35))
        card = end(END + (t - END_CARD), lang).convert("RGBA")
        img = Image.blend(img.convert("RGBA"), card, k) if k < 1 else card
    return img.convert("RGB")


# MARK: Sound

def soundtrack():
    n = int(DURATION * RATE)
    mix = np.zeros(n)
    rng = np.random.default_rng(4)

    def add(start, sig, gain):
        i = int(start * RATE)
        sig = sig[: max(0, n - i)]
        mix[i:i + len(sig)] += sig * gain

    def tone(f, dur, decay=4.0):
        tt = np.arange(int(dur * RATE)) / RATE
        return (np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(4 * np.pi * f * tt)) * np.exp(-tt * decay)

    # Scrolling: a soft swipe each time the screen changes, over a low hum.
    tt = np.arange(int(REVEAL * RATE)) / RATE
    add(0, np.sin(2 * np.pi * 55 * tt) * np.minimum(1, tt / 0.5), 0.05)
    for i in range(int(REVEAL / 0.55)):
        noise = np.convolve(rng.standard_normal(int(0.12 * RATE)), np.ones(9) / 9, mode="same")
        add(i * 0.55, noise * np.sin(np.linspace(0, np.pi, len(noise))) ** 2, 0.06)
    # The smirk: a little "hm".
    add(FACE + 0.2, tone(196, 0.5, 6), 0.08)
    # The reveal: a big whoosh and a shimmer.
    noise = np.convolve(rng.standard_normal(int(0.9 * RATE)), np.ones(5) / 5, mode="same")
    add(REVEAL, noise * np.sin(np.linspace(0, np.pi, len(noise))) ** 2, 0.12)
    for k, f in enumerate([1318.5, 1568, 1975.5, 2637]):
        add(REVEAL + 0.6 + k * 0.08, tone(f, 1.2, 3), 0.05)
    # Each word: a pop, rising.
    for i in range(10):
        ft = np.arange(int(0.14 * RATE)) / RATE
        pitch = 240 + i * 25
        add(WORDS + i * 0.45, np.sin(2 * np.pi * (pitch * ft + 2200 * ft ** 2)) * np.exp(-ft * 25), 0.3)
    # The punchline: two low hits.
    for j in range(2):
        ft = np.arange(int(0.4 * RATE)) / RATE
        add(PUNCH + j * 0.45, np.sin(2 * np.pi * (90 * ft - 40 * ft ** 2)) * np.exp(-ft * 9), 0.5)
    # The end card: a warm chord.
    dur = DURATION - END_CARD
    for f in (130.8, 196.0, 261.6, 329.6, 392.0, 523.3):
        ft = np.arange(int(dur * RATE)) / RATE
        add(END_CARD, np.sin(2 * np.pi * f * ft) * np.minimum(1, ft / 0.6) * np.linspace(1, 0, len(ft)) ** 0.7, 0.02)
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
            frame(float(t), "sv").save(os.path.join(out, f"dig-{t}.png"))
        return
    for lang in ("sv", "en"):
        render(lang, os.path.join(OUT, "ads", lang, "real-life", "keep-digging-1080x1920.mp4"))


if __name__ == "__main__":
    main()
