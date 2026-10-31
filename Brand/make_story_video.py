"""A narrated story ad: original illustrated scenes, one big word at a time in step with a voiceover.

The voiceover is made separately (ElevenLabs). Its sentences are found from the pauses between them, and the
words inside a sentence are spread by their length, which is close enough for one word on screen at a time.

Run: python3 Brand/make_story_video.py voice.mp3 out.mp4
Stills: python3 Brand/make_story_video.py voice.mp3 --stills 3,10,15,20,26,33,39,44,48,52,56 out_dir
"""
import functools
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import BLACK, BOLD, SEMI, app_icon, font, pip, rounded
from make_video import RATE, back, clamp, ease_out, seg, smooth, write_wav

W, H, FPS = 1080, 1920, 30
END_LENGTH = 3.4

# The script, one line per spoken phrase, in the order the pauses split them.
PHRASES = [
    "You spent four hours on your phone yesterday.",
    "Can you remember a single thing you watched?",
    "Not one.",
    "Four hours of your life.",
    "Not spent on something you love.",
    "Not spent with someone you love.",
    "Just…",
    "scrolled away.",
    "And tomorrow,",
    "you'll do it again.",
    "Here's what nobody tells you.",
    "These apps aren't free.",
    "You pay with the one thing you can never earn back.",
    "Your time.",
    "At this pace, that's more than a decade of your waking life.",
    "Ten years,",
    "watching other people live theirs.",
    "Now imagine what those years could be.",
    "A body you're proud of.",
    "A skill no one can take from you.",
    "Long nights with the people who matter.",
    "Sunsets you actually watched.",
    "A life you actually remember.",
    "You don't need more discipline.",
    "You need a pause.",
    "Paus blocks the apps that steal your hours, so the next four hours go back to you.",
    "Your life is happening right now.",
    "Don't scroll past it.",
]

# Which scene goes with which phrases (index of the first phrase of each scene).
SCENES = [(0, "bedroom"), (3, "hourglass"), (8, "days"), (10, "vortex"), (14, "lifegrid"), (17, "sunrise"),
          (20, "campfire"), (23, "pip"), (25, "lock"), (26, "dawn")]

GOLD = (255, 214, 90)
PINK = (255, 92, 168)
MINT = (110, 245, 195)
WHITE = (255, 255, 255)
INK = (20, 14, 40)


# MARK: Timing from the voiceover

def speech_segments(path):
    out = subprocess.run(["ffmpeg", "-v", "info", "-i", path, "-af", "silencedetect=noise=-35dB:d=0.18", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([0-9.]+)", out)]
    ends = [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", out)]
    duration = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                                    capture_output=True, text=True).stdout)
    segments, t = [], 0.0
    for s, e in zip(starts, ends):
        if s - t > 0.15:
            segments.append((t, s))
        t = e
    if duration - t > 0.15:
        segments.append((t, duration))
    return segments, duration


def syllables(word):
    return max(1, len(re.findall(r"[aeiouy]+", word.lower())))


def word_timings(segments):
    """(start, end, word) for every word, spread over its phrase by syllables."""
    if len(segments) != len(PHRASES):
        raise SystemExit(f"Found {len(segments)} spoken phrases, expected {len(PHRASES)}. Adjust PHRASES or the silence threshold.")
    words = []
    for (start, end), phrase in zip(segments, PHRASES):
        parts = phrase.split()
        weights = [syllables(p) + 0.6 for p in parts]
        total = sum(weights)
        t = start
        for part, weight in zip(parts, weights):
            d = (end - start) * weight / total
            words.append((t, t + d, part))
            t += d
    return words


# MARK: Drawing helpers

def vgrad(stops, w=W, h=H):
    """A vertical gradient through (position, color) stops."""
    y = np.linspace(0, 1, h, dtype=np.float32)
    img = np.zeros((h, 3), np.float32)
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        m = (y >= p0) & (y <= p1)
        k = ((y[m] - p0) / max(p1 - p0, 1e-6))[:, None]
        img[m] = np.array(c0) + (np.array(c1) - np.array(c0)) * k
    return Image.fromarray(np.repeat(img[:, None, :], w, 1).astype(np.uint8), "RGB").convert("RGBA")


def glow(img, box, color, alpha, blur):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=(*color, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


@functools.lru_cache(None)
def stars(seed, count, top=0, bottom=H):
    rng = np.random.default_rng(seed)
    return [(rng.uniform(0, W), rng.uniform(top, bottom), rng.uniform(1.5, 4.5), rng.uniform(0, 6.28)) for _ in range(count)]


def draw_stars(img, t, seed=1, count=120, top=0, bottom=H, alpha=255):
    d = ImageDraw.Draw(img)
    for x, y, r, phase in stars(seed, count, top, bottom):
        k = 0.55 + 0.45 * math.sin(t * 2 + phase)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 240, int(alpha * k)))


def zoom(img, s, cx=W / 2, cy=H / 2):
    if abs(s - 1) < 1e-3:
        return img
    big = img.resize((int(W * s), int(H * s)), Image.BICUBIC)
    x, y = int(cx * s - cx), int(cy * s - cy)
    return big.crop((x, y, x + W, y + H))


# MARK: Scenes. Each takes the time since it began and the whole video time.

@functools.lru_cache(None)
def bedroom_base():
    img = vgrad([(0, (22, 16, 58)), (1, (10, 8, 30))])
    d = ImageDraw.Draw(img)
    # Window with the night outside.
    d.rounded_rectangle([600, 480, 960, 940], 30, fill=(40, 34, 96))
    sky = vgrad([(0, (30, 26, 90)), (1, (70, 50, 140))], 320, 420)
    img.alpha_composite(sky, (620, 500))
    d.ellipse([800, 550, 880, 630], fill=(250, 240, 200))
    d.ellipse([780, 538, 862, 620], fill=(58, 46, 120))
    d.line([(780, 500), (780, 920)], fill=(40, 34, 96), width=14)
    d.line([(620, 710), (940, 710)], fill=(40, 34, 96), width=14)
    # Bed, seen from the side: frame, mattress, pillow, a big duvet.
    d.rounded_rectangle([60, 1180, 1020, 1300], 40, fill=(70, 46, 110))
    d.rounded_rectangle([90, 1100, 990, 1200], 50, fill=(120, 110, 190))
    d.rounded_rectangle([110, 1010, 380, 1110], 50, fill=(220, 220, 245))
    d.rounded_rectangle([60, 1300, 110, 1500], 20, fill=(70, 46, 110))
    d.rounded_rectangle([970, 1300, 1020, 1500], 20, fill=(70, 46, 110))
    d.rectangle([0, 1500, W, H], fill=(16, 12, 40))
    return img


def person_in_bed(img, t, glow_on=True):
    d = ImageDraw.Draw(img)
    # Head on the pillow, the duvet up to the chin, hands holding the phone above the face.
    d.ellipse([220, 950, 340, 1070], fill=(240, 196, 160))
    d.chord([212, 930, 348, 1040], 180, 360, fill=(80, 50, 40))
    d.rounded_rectangle([250, 1050, 990, 1170], 60, fill=(92, 80, 200))
    for x in range(330, 980, 90):
        d.arc([x, 1060, x + 120, 1150], 200, 340, fill=(76, 64, 176), width=6)
    phone_x, phone_y = 330 + 4 * math.sin(t * 1.3), 840
    d.rounded_rectangle([phone_x, phone_y, phone_x + 90, phone_y + 160], 16, fill=(24, 20, 34))
    screen = [(80, 170, 255), (255, 90, 160), (255, 200, 80), (120, 255, 200)][int(t / 0.6) % 4]
    d.rounded_rectangle([phone_x + 8, phone_y + 10, phone_x + 82, phone_y + 150], 10, fill=screen)
    d.ellipse([phone_x - 10, phone_y + 120, phone_x + 40, phone_y + 170], fill=(240, 196, 160))
    if glow_on:
        glow(img, [80, 760, 560, 1180], screen, 90, 70)
    d = ImageDraw.Draw(img)
    d.ellipse([262, 1000, 274, 1012], fill=INK)
    d.ellipse([292, 1000, 304, 1012], fill=INK)


def bedroom(t, T):
    img = bedroom_base().copy()
    person_in_bed(img, T)
    # A clock on the wall, its hands racing.
    cx, cy, r = 260, 640, 110
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(240, 236, 255), outline=(60, 50, 120), width=10)
    a = T * 2.5
    d.line([(cx, cy), (cx + 70 * math.sin(a), cy - 70 * math.cos(a))], fill=INK, width=10)
    d.line([(cx, cy), (cx + 45 * math.sin(a / 12), cy - 45 * math.cos(a / 12))], fill=INK, width=14)
    return zoom(img, 1 + 0.04 * t, 300, 1000)


def hourglass(t, T):
    img = vgrad([(0, (70, 30, 120)), (0.6, (150, 50, 130)), (1, (40, 16, 70))])
    draw_stars(img, T, seed=3, count=70, bottom=900, alpha=180)
    d = ImageDraw.Draw(img)
    cx, top, mid, bot = W / 2, 520, 980, 1440
    d.rounded_rectangle([cx - 300, top - 60, cx + 300, top], 20, fill=(150, 96, 60))
    d.rounded_rectangle([cx - 300, bot, cx + 300, bot + 60], 20, fill=(150, 96, 60))
    glass = [(cx - 240, top), (cx + 240, top), (cx + 30, mid), (cx + 240, bot), (cx - 240, bot), (cx - 30, mid)]
    d.polygon(glass, fill=(200, 230, 255, 255))
    # The sand: the top empties, the bottom fills, a stream falls through the middle.
    k = clamp(t / 7.5)
    level = top + 60 + (mid - top - 80) * k
    width = 220 * (mid - level) / (mid - top)
    d.polygon([(cx - width, level), (cx + width, level), (cx + 20, mid - 10), (cx - 20, mid - 10)], fill=GOLD)
    heap = 60 + 300 * k
    d.polygon([(cx - 230, bot), (cx + 230, bot), (cx + 60, bot - heap), (cx - 60, bot - heap)], fill=GOLD)
    d.ellipse([cx - 60, bot - heap - 30, cx + 60, bot - heap + 30], fill=GOLD)
    d.line([(cx, mid - 10), (cx, bot - heap)], fill=GOLD, width=10)
    for i in range(12):
        y = mid + ((T * 600 + i * 47) % (bot - heap - mid))
        d.ellipse([cx - 6, y - 6, cx + 6, y + 6], fill=(255, 236, 150))
    d.polygon(glass, outline=(255, 255, 255), width=8)
    return img


def days(t, T):
    """Sun and moon racing over a city: one day after another, the same lit window each night."""
    phase = (t / 0.8) % 1
    day = math.sin(phase * math.pi)
    top = tuple(int(a + (b - a) * day) for a, b in zip((14, 12, 50), (110, 190, 255)))
    low = tuple(int(a + (b - a) * day) for a, b in zip((50, 30, 110), (255, 200, 150)))
    img = vgrad([(0, top), (1, low)])
    d = ImageDraw.Draw(img)
    a = phase * math.pi
    sx, sy = W / 2 - 520 * math.cos(a), 1100 - 700 * math.sin(a)
    d.ellipse([sx - 80, sy - 80, sx + 80, sy + 80], fill=(255, 220, 120) if day > 0.15 else (240, 240, 220))
    rng = np.random.default_rng(5)
    x = 0
    while x < W:
        w, h = rng.integers(120, 220), rng.integers(300, 800)
        d.rectangle([x, H - h, x + w, H], fill=(28, 22, 60))
        for wy in range(int(H - h + 40), H - 40, 70):
            for wx in range(int(x + 20), int(x + w - 30), 50):
                lit = (wx == int(x + 20) and wy == int(H - h + 40)) or rng.random() < 0.15 * (1 - day)
                d.rectangle([wx, wy, wx + 26, wy + 36], fill=(255, 200, 120) if lit else (44, 36, 86))
        x += w + 10
    return img


def vortex(t, T):
    img = vgrad([(0, (16, 10, 40)), (1, (50, 14, 70))])
    cx, cy = W / 2, 980
    d = ImageDraw.Draw(img)
    # A phone whose screen is a swirl that swallows clocks.
    d.rounded_rectangle([cx - 260, cy - 480, cx + 260, cy + 480], 70, fill=(30, 26, 44), outline=(90, 80, 130), width=8)
    spiral = Image.new("RGBA", (480, 900), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spiral)
    for i in range(40):
        r = 30 + i * 13
        hue = i / 40
        color = (int(255 * (0.6 + 0.4 * hue)), int(60 + 120 * (1 - hue)), int(200 - 80 * hue), 255)
        start = (T * 120 + i * 18) % 360
        sd.arc([240 - r, 450 - r, 240 + r, 450 + r], start, start + 200, fill=color, width=10)
    mask = Image.new("L", (480, 900), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 479, 899], 50, fill=255)
    img.paste(spiral, (int(cx - 240), int(cy - 450)), Image.composite(spiral.getchannel("A"), Image.new("L", (480, 900), 0), mask))
    d = ImageDraw.Draw(img)
    for i in range(7):
        k = ((T * 0.35 + i / 7) % 1)
        ang = i * 0.9 + k * 6
        dist = 520 * (1 - k)
        x, y = cx + dist * math.cos(ang), cy + dist * math.sin(ang) * 1.2
        r = 70 * (1 - k) + 6
        d.ellipse([x - r, y - r, x + r, y + r], fill=(245, 240, 255), outline=(60, 50, 110), width=max(2, int(r / 9)))
        d.line([(x, y), (x, y - r * 0.6)], fill=INK, width=max(2, int(r / 10)))
        d.line([(x, y), (x + r * 0.45, y)], fill=INK, width=max(2, int(r / 10)))
    return img


def lifegrid(t, T):
    """A life as 80 dots, one per year. The years lost to the phone light up one after another."""
    img = vgrad([(0, (12, 10, 34)), (1, (30, 16, 60))])
    d = ImageDraw.Draw(img)
    cols, rows, r, gap = 8, 10, 42, 108
    x0, y0 = (W - (cols - 1) * gap) / 2, 470
    lit = int(clamp(t / 3.0) * 14)
    for i in range(cols * rows):
        x, y = x0 + (i % cols) * gap, y0 + (i // cols) * gap
        if 20 <= i < 20 + lit:
            glow(img, [x - r - 14, y - r - 14, x + r + 14, y + r + 14], PINK, 140, 14)
            d = ImageDraw.Draw(img)
            d.ellipse([x - r, y - r, x + r, y + r], fill=PINK)
        else:
            d.ellipse([x - r, y - r, x + r, y + r], fill=(60, 52, 110) if i < 20 else (90, 80, 150))
    return img


@functools.lru_cache(None)
def landscape_base(warm):
    sky = [(0, (255, 140, 120)), (0.45, (255, 200, 140)), (0.7, (255, 230, 180)), (1, (255, 230, 180))] if warm else \
          [(0, (120, 70, 180)), (0.5, (255, 120, 150)), (0.75, (255, 190, 130)), (1, (255, 190, 130))]
    img = vgrad(sky)
    return img


def mountains(img, layers, t):
    d = ImageDraw.Draw(img)
    for i, (color, base, amp, freq, seed) in enumerate(layers):
        pts = [(0, H)]
        for x in range(0, W + 41, 40):
            y = base - amp * (0.5 + 0.5 * math.sin(x * freq + seed)) - amp * 0.35 * math.sin(x * freq * 2.7 + seed * 2)
            pts.append((x, y))
        pts.append((W, H))
        d.polygon(pts, fill=color)


def sunrise(t, T):
    img = landscape_base(True).copy()
    sy = 1180 - 260 * ease_out(clamp(t / 6))
    glow(img, [W / 2 - 360, sy - 360, W / 2 + 360, sy + 360], (255, 240, 180), 160, 90)
    d = ImageDraw.Draw(img)
    d.ellipse([W / 2 - 150, sy - 150, W / 2 + 150, sy + 150], fill=(255, 245, 210))
    mountains(img, [((200, 110, 140), 1260, 260, 0.004, 1), ((140, 70, 120), 1420, 220, 0.006, 3),
                    ((80, 40, 90), 1600, 180, 0.009, 5)], t)
    d = ImageDraw.Draw(img)
    for i in range(5):
        bx = (T * 60 + i * 190) % (W + 200) - 100
        by = 520 + 60 * math.sin(i * 2.1) + 10 * math.sin(T * 3 + i)
        d.arc([bx - 22, by - 10, bx, by + 10], 200, 340, fill=(60, 30, 70), width=5)
        d.arc([bx, by - 10, bx + 22, by + 10], 200, 340, fill=(60, 30, 70), width=5)
    return zoom(img, 1.05 - 0.05 * clamp(t / 6))


def campfire(t, T):
    img = vgrad([(0, (16, 14, 52)), (0.6, (60, 40, 110)), (1, (30, 20, 50))])
    draw_stars(img, T, seed=8, count=160, bottom=1100)
    mountains(img, [((36, 28, 70), 1350, 200, 0.005, 2)], t)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 1500, W, H], fill=(24, 18, 40))
    fx, fy = W / 2, 1540
    flicker = 1 + 0.08 * math.sin(T * 14) + 0.05 * math.sin(T * 23)
    glow(img, [fx - 420, fy - 360, fx + 420, fy + 300], (255, 150, 60), 120, 80)
    d = ImageDraw.Draw(img)
    for dx, h, c in ((-50, 170, (255, 120, 40)), (40, 150, (255, 150, 50)), (0, 220 * flicker, (255, 200, 80))):
        d.polygon([(fx + dx - 55, fy), (fx + dx + 55, fy), (fx + dx, fy - h)], fill=c)
    d.line([(fx - 90, fy + 10), (fx + 90, fy - 10)], fill=(110, 70, 40), width=22)
    d.line([(fx - 90, fy - 10), (fx + 90, fy + 10)], fill=(90, 56, 34), width=22)
    # Friends around the fire, warm on the side facing it.
    for x, s in ((230, 1.0), (360, 0.85), (720, 0.9), (860, 1.05)):
        hx, hy = x, 1380 - 40 * s
        d.ellipse([hx - 40 * s, hy - 40 * s, hx + 40 * s, hy + 40 * s], fill=(50, 30, 50))
        d.rounded_rectangle([hx - 60 * s, hy + 30 * s, hx + 60 * s, hy + 190 * s], 40, fill=(50, 30, 50))
        side = 1 if x < fx else -1
        d.chord([hx - 40 * s, hy - 40 * s, hx + 40 * s, hy + 40 * s], 270 if side > 0 else 90, 90 if side > 0 else 270, fill=(255, 150, 90))
    for i in range(14):
        k = (T * 0.6 + i / 14) % 1
        x = fx + 60 * math.sin(i * 1.7 + T) * k
        y = fy - 200 - 600 * k
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 210, 120, int(255 * (1 - k))))
    return img


def pip_scene(t, T):
    img = vgrad([(0, (14, 11, 31)), (1, (36, 20, 70))])
    glow(img, [W / 2 - 420, 560, W / 2 + 420, 1400], (139, 92, 255), 120, 120)
    k = back(seg(t, 0.1, 0.6))
    p = pip(int(520 * max(0.01, k)))
    img.alpha_composite(p, (int(W / 2 - p.width / 2), int(980 - p.height / 2 + 14 * math.sin(T * 2.4))))
    return img


def lock_scene(t, T):
    img = vgrad([(0, (20, 14, 50)), (1, (60, 20, 80))])
    d = ImageDraw.Draw(img)
    cx, cy = W / 2, 980
    d.rounded_rectangle([cx - 300, cy - 560, cx + 300, cy + 560], 80, fill=(26, 22, 40), outline=(100, 90, 150), width=8)
    d.rounded_rectangle([cx - 270, cy - 530, cx + 270, cy + 530], 60, fill=(50, 40, 110))
    colors = [(255, 90, 140), (255, 170, 60), (90, 170, 255), (130, 230, 170), (200, 120, 255), (255, 110, 90),
              (80, 210, 230), (255, 220, 90), (170, 140, 255), (120, 200, 120), (255, 130, 200), (90, 120, 255)]
    for i, c in enumerate(colors):
        x = cx - 210 + (i % 3) * 210
        y = cy - 400 + (i // 3) * 230
        d.rounded_rectangle([x - 75, y - 75, x + 75, y + 75], 34, fill=c)
        k = back(seg(t, 0.3 + i * 0.12, 0.6 + i * 0.12))
        if k > 0:
            lock = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
            l = ImageDraw.Draw(lock)
            l.rounded_rectangle([0, 0, 149, 149], 34, fill=(10, 8, 24, 190))
            l.arc([45, 22, 105, 82], 180, 360, fill=WHITE, width=10)
            l.rounded_rectangle([35, 60, 115, 120], 12, fill=WHITE)
            s = max(0.01, k)
            lock = lock.resize((max(1, int(150 * s)), max(1, int(150 * s))))
            img.alpha_composite(lock, (int(x - lock.width / 2), int(y - lock.height / 2)))
    return img


def dawn(t, T):
    img = landscape_base(False).copy()
    glow(img, [W / 2 - 400, 700, W / 2 + 400, 1500], (255, 230, 170), 150, 100)
    d = ImageDraw.Draw(img)
    d.ellipse([W / 2 - 170, 930, W / 2 + 170, 1270], fill=(255, 238, 200))
    mountains(img, [((210, 120, 150), 1300, 200, 0.005, 4), ((120, 60, 120), 1480, 200, 0.007, 6),
                    ((60, 30, 80), 1660, 160, 0.01, 8)], t)
    # Someone standing on the hill, phone in pocket, looking at it.
    d = ImageDraw.Draw(img)
    x, y = 640, 1500
    d.ellipse([x - 26, y - 190, x + 26, y - 138], fill=(40, 20, 50))
    d.rounded_rectangle([x - 36, y - 140, x + 36, y - 30], 20, fill=(40, 20, 50))
    d.rectangle([x - 30, y - 40, x - 8, y + 30], fill=(40, 20, 50))
    d.rectangle([x + 8, y - 40, x + 30, y + 30], fill=(40, 20, 50))
    return zoom(img, 1 + 0.03 * t)


SCENE_DRAW = {"bedroom": bedroom, "hourglass": hourglass, "days": days, "vortex": vortex, "lifegrid": lifegrid,
              "sunrise": sunrise, "campfire": campfire, "pip": pip_scene, "lock": lock_scene, "dawn": dawn}


# MARK: Words

@functools.lru_cache(None)
def word_layer(text, color):
    f = font(BLACK, 150)
    l, t, r, b = f.getbbox(text, stroke_width=12)
    while r - l > W - 80:
        size = int(150 * (W - 80) / (r - l))
        f = font(BLACK, size)
        l, t, r, b = f.getbbox(text, stroke_width=12)
    layer = Image.new("RGBA", (r - l + 20, b - t + 20), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((10 - l, 10 - t), text, font=f, fill=color, stroke_width=12, stroke_fill=INK)
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel("A").point(lambda v: int(v * 0.5)))
    out = Image.new("RGBA", (layer.width + 16, layer.height + 16), (0, 0, 0, 0))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)), (8, 14))
    out.alpha_composite(layer, (0, 0))
    return out


ACCENTS = {"bedroom": WHITE, "hourglass": GOLD, "days": WHITE, "vortex": PINK, "lifegrid": PINK, "sunrise": WHITE,
           "campfire": GOLD, "pip": MINT, "lock": WHITE, "dawn": WHITE}
KEYWORDS = {"time.", "life.", "free.", "decade", "pause.", "paus", "remember.", "now.", "years,", "away."}


def frame(t, words, scene_starts, end_card):
    if t >= end_card:
        img = end_frame(t - end_card)
        return img.convert("RGB")
    name = [n for start, n in scene_starts if t >= start][-1]
    start = [s for s, n in scene_starts if n == name][0]
    img = SCENE_DRAW[name](t - start, t)
    # Crossfade the first moments of a scene over the last frame of the one before.
    for s, n in scene_starts:
        if 0 < t - s < 0.25 and s > 0:
            prev = [m for p, m in scene_starts if p < s][-1]
            pstart = [p for p, m in scene_starts if m == prev][0]
            img = Image.blend(SCENE_DRAW[prev](s - pstart, s), img, smooth((t - s) / 0.25))
    current = [w for w in words if w[0] <= t < w[1] + 0.12]
    if current:
        ws, we, text = current[-1]
        clean = text.strip("…").upper().replace("’", "'")
        color = GOLD if text.lower() in KEYWORDS else ACCENTS[name]
        layer = word_layer(clean.strip(".,?"), color)
        pop = back(seg(t, ws, ws + 0.12))
        s = 0.86 + 0.14 * pop
        sized = layer.resize((max(1, int(layer.width * s)), max(1, int(layer.height * s))), Image.BICUBIC)
        img.alpha_composite(sized, (int(W / 2 - sized.width / 2), int(330 - sized.height / 2)))
    return img.convert("RGB")


def end_frame(t):
    img = vgrad([(0, (14, 11, 31)), (1, (40, 20, 70))])
    glow(img, [W / 2 - 380, 480, W / 2 + 380, 1240], (255, 79, 163), 90, 110)
    k = [ease_out(seg(t, 0.1 + i * 0.25, 0.5 + i * 0.25)) for i in range(3)]
    icon = rounded(app_icon(260))
    icon.putalpha(icon.getchannel("A").point(lambda v: int(v * k[0])))
    img.alpha_composite(icon, ((W - 260) // 2, 640))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((W / 2, 980), "Paus", font=font(BLACK, 110), fill=(255, 255, 255, int(255 * k[1])), anchor="ma")
    d.text((W / 2, 1120), "Take back your time.", font=font(BOLD, 54), fill=(230, 225, 250, int(255 * k[2])), anchor="ma")
    d.text((W / 2, 1210), "Free on the App Store", font=font(SEMI, 42), fill=(180, 170, 210, int(255 * k[2])), anchor="ma")
    img.alpha_composite(layer)
    return img


# MARK: Sound

def music(length):
    """A soft pad under the voice: slow minor chords, then a major lift for the second half."""
    n = int(length * RATE)
    tt = np.arange(n) / RATE
    mix = np.zeros(n)
    chords = [(0, (110.0, 130.8, 164.8)), (16, (98.0, 123.5, 146.8)), (30.5, (130.8, 164.8, 196.0)),
              (42.9, (146.8, 185.0, 220.0)), (50.7, (130.8, 164.8, 196.0, 261.6))]
    for i, (start, notes) in enumerate(chords):
        end = chords[i + 1][0] if i + 1 < len(chords) else length
        m = (tt >= start) & (tt < end + 1.0)
        local = tt[m] - start
        env = np.minimum(1, local / 1.5) * np.clip((end + 1.0 - tt[m]) / 1.0, 0, 1)
        for f in notes:
            mix[m] += (np.sin(2 * np.pi * f * tt[m]) + 0.3 * np.sin(2 * np.pi * f * 2.003 * tt[m])) * env * 0.035
    return mix


def render(voice, out):
    segments, duration = speech_segments(voice)
    words = word_timings(segments)
    scene_starts = [(0.0 if i == 0 else segments[i][0] - 0.15, name) for i, name in SCENES]
    end_card = duration + 0.2
    length = end_card + END_LENGTH
    with tempfile.TemporaryDirectory() as tmp:
        pad = os.path.join(tmp, "pad.wav")
        write_wav(pad, music(length))
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
             "-i", "-", "-i", voice, "-i", pad, "-filter_complex",
             f"[1:a]aresample={RATE},loudnorm=I=-14:TP=-1.5:LRA=9,aresample={RATE},apad[v];[v][2:a]amix=inputs=2:duration=shortest:normalize=0[a]",
             "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
             "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p", "-color_primaries", "bt709",
             "-color_trc", "bt709", "-colorspace", "bt709", "-c:a", "aac", "-b:a", "192k", "-t", f"{length:.2f}",
             "-movflags", "+faststart", out],
            stdin=subprocess.PIPE)
        for i in range(int(length * FPS)):
            ffmpeg.stdin.write(frame(i / FPS, words, scene_starts, end_card).tobytes())
        ffmpeg.stdin.close()
        if ffmpeg.wait() != 0:
            raise SystemExit("ffmpeg failed")
    print(f"{out}: {length:.1f} s")


def main():
    voice = sys.argv[1]
    if len(sys.argv) > 3 and sys.argv[2] == "--stills":
        out = sys.argv[4] if len(sys.argv) > 4 else "."
        segments, duration = speech_segments(voice)
        words = word_timings(segments)
        scene_starts = [(0.0 if i == 0 else segments[i][0] - 0.15, name) for i, name in SCENES]
        for t in sys.argv[3].split(","):
            frame(float(t), words, scene_starts, duration + 0.2).save(os.path.join(out, f"s-{t}.png"))
        return
    render(voice, sys.argv[2])


if __name__ == "__main__":
    main()
