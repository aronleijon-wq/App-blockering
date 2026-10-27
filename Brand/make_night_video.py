"""Draws "Same night", an animated 9:16 video ad: two people in the same room at 23:12. One keeps scrolling
until 02:47 and wakes up drained; the other gets a no from Pip, puts the phone away and wakes up fresh.

Run from the repository root: python3 Brand/make_night_video.py
Stills for checking a few moments: python3 Brand/make_night_video.py --stills 1,5,9 [out_dir]
"""
import functools
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_ads import COPY
from make_brand import BOLD, INK, MINT, OUT, PINK, SEMI, WHITE, font
from make_video import (END, RATE, back, bubble, clamp, ease_out, end, glow, pip_big, put, put_center, seg, smooth,
                        title, vgrad, write_wav)

W, H, FPS = 1080, 1920, 30
LEFT_X, RIGHT_X = 290, 790
BED_TOP = 1300
WINDOW = (330, 640, 750, 1020)

COPY_NIGHT = {
    "sv": {
        "labels": ("SCROLLAREN", "MED PAUS"),
        "hook": ("Samma kväll.", "Två olika morgnar."),
        "screen": "Skärmtid",
        "later": "Tre timmar senare…",
        "morning": ("Vem vill du vara", "i morgon?"),
        "battery": ("12 %", "100 %"),
    },
    "en": {
        "labels": ("THE SCROLLER", "WITH PAUS"),
        "hook": ("Same night.", "Two different mornings."),
        "screen": "Screen time",
        "later": "Three hours later…",
        "morning": ("Who do you want", "to be tomorrow?"),
        "battery": ("12%", "100%"),
    },
}

# When things happen, in seconds.
PIP = 2.6           # Pip says no on the right phone.
PHONE_DOWN = 4.0    # The right one puts the phone away and lies down.
TIMELAPSE = 6.0     # The clock races from 23:12 to 02:47.
NIGHT_END = 9.5
DAWN = 10.5         # 07:00, the alarm.
END_CARD = 15.0
DURATION = END_CARD + 4.0
CROSSFADE = 0.35

START_MINUTE = 23 * 60 + 12
LATE_MINUTE = 26 * 60 + 47
MORNING_MINUTE = 31 * 60


def clock_minute(t):
    if t < TIMELAPSE:
        return START_MINUTE + int(t / 2)
    if t < NIGHT_END:
        return START_MINUTE + 3 + int((LATE_MINUTE - START_MINUTE - 3) * smooth(seg(t, TIMELAPSE, NIGHT_END - 0.5)))
    if t < DAWN:
        return LATE_MINUTE
    return MORNING_MINUTE


def screen_minutes(t):
    """The scroller's screen time tonight."""
    return 72 + int((214 - 72) * smooth(seg(t, 0.5, NIGHT_END)))


def soft_glow(img, cx, cy, r, color, alpha):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*color, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(r * 0.45)))


# MARK: The room

@functools.lru_cache(None)
def room(dawn):
    """The bedroom at night, or at dawn when `dawn` is 1."""
    night = vgrad(W, H, [(0, (10, 9, 22)), (1, (24, 22, 40))])
    day = vgrad(W, H, [(0, (40, 36, 70)), (1, (70, 58, 90))])
    img = Image.blend(night, day, dawn)
    d = ImageDraw.Draw(img)
    # Window with the city outside.
    wx0, wy0, wx1, wy1 = WINDOW
    sky = vgrad(wx1 - wx0, wy1 - wy0, [(0, (16, 22, 58)), (1, (34, 40, 96))])
    morning = vgrad(wx1 - wx0, wy1 - wy0, [(0, (120, 110, 200)), (0.7, (255, 170, 140)), (1, (255, 210, 150))])
    img.paste(Image.blend(sky, morning, dawn), (wx0, wy0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(5)
    if dawn < 0.5:
        for _ in range(30):
            x, y = rng.uniform(wx0, wx1), rng.uniform(wy0, wy0 + 200)
            d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(200, 205, 235))
        d.ellipse([600, wy0 + 50, 680, wy0 + 130], fill=(240, 236, 214))
        d.ellipse([622, wy0 + 38, 702, wy0 + 118], fill=(20, 26, 66))
    else:
        d.ellipse([480, wy1 - 100, 600, wy1 + 20], fill=(255, 226, 160))
    for i, (x, h) in enumerate([(340, 120), (390, 80), (440, 150), (520, 100), (580, 170), (650, 110), (700, 140)]):
        d.rectangle([x, wy1 - h, x + 46, wy1], fill=(18, 18, 36) if dawn < 0.5 else (70, 60, 100))
        for k in range(4):
            if rng.random() > 0.4:
                d.rectangle([x + 8 + (k % 2) * 18, wy1 - h + 14 + (k // 2) * 26, x + 16 + (k % 2) * 18, wy1 - h + 24 + (k // 2) * 26],
                            fill=(255, 220, 140))
    d.rectangle([wx0 + (wx1 - wx0) // 2 - 4, wy0, wx0 + (wx1 - wx0) // 2 + 4, wy1], fill=(60, 56, 84))
    d.rectangle([wx0, wy0 + (wy1 - wy0) // 2 - 4, wx1, wy0 + (wy1 - wy0) // 2 + 4], fill=(60, 56, 84))
    d.rectangle([wx0 - 10, wy0 - 10, wx1 + 10, wy1 + 10], outline=(60, 56, 84), width=10)
    # Curtains.
    for x0 in (wx0 - 90, wx1 + 10):
        d.rectangle([x0, wy0 - 30, x0 + 80, wy1 + 60], fill=(44, 40, 72))
        for k in range(1, 4):
            d.line([(x0 + k * 20, wy0 - 30), (x0 + k * 20, wy1 + 60)], fill=(36, 32, 60), width=3)
    d.rectangle([wx0 - 110, wy0 - 44, wx1 + 110, wy0 - 34], fill=(70, 66, 96))
    # Two beds and the nightstand between them.
    for cx in (LEFT_X, RIGHT_X):
        d.rounded_rectangle([cx - 230, BED_TOP - 140, cx + 230, BED_TOP + 40], 24, fill=(48, 44, 74))
        d.rectangle([cx - 230, BED_TOP + 20, cx + 230, BED_TOP + 420], fill=(58, 54, 86))
    d.rectangle([470, BED_TOP + 40, 610, BED_TOP + 300], fill=(40, 36, 62))
    d.rectangle([470, BED_TOP + 40, 610, BED_TOP + 60], fill=(52, 48, 78))
    d.ellipse([532, BED_TOP + 150, 548, BED_TOP + 166], fill=(70, 66, 96))
    return img.convert("RGBA")


def clock(img, minute, alarm):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([440, BED_TOP - 60, 640, BED_TOP + 40], 12, fill=(16, 14, 28))
    h, m = (minute // 60) % 24, minute % 60
    color = (255, 80, 80) if not alarm or int(alarm * 6) % 2 == 0 else (255, 200, 200)
    soft_glow(img, 540, BED_TOP - 10, 90, (255, 60, 60), 50)
    ImageDraw.Draw(img).text((540, BED_TOP - 10), f"{h:02d}:{m:02d}", font=font(BOLD, 58), fill=color, anchor="mm")


# MARK: The two people

def person_sitting(img, cx, screen_on, tired=0.0, phone=True):
    """Sitting up against the headboard, with the phone in both hands or arms up in a morning stretch."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    base = BED_TOP + 120
    white = (240, 240, 248)
    d.ellipse([cx - 62, base - 400, cx + 62, base - 276], fill=white, outline=(30, 28, 44), width=6)
    d.rounded_rectangle([cx - 95, base - 270, cx + 95, base + 40], 70, fill=white, outline=(30, 28, 44), width=6)
    if not phone:
        for sx in (-1, 1):
            arm = [(cx + sx * 80, base - 230), (cx + sx * 150, base - 330), (cx + sx * 170, base - 430)]
            d.line(arm, fill=(30, 28, 44), width=30, joint="curve")
            d.line(arm, fill=white, width=20, joint="curve")
        # A smile.
        d.arc([cx - 26, base - 352, cx + 26, base - 316], 20, 160, fill=(30, 28, 44), width=5)
    for sx in (-1, 1) if phone else ():
        d.line([(cx + sx * 80, base - 230), (cx + sx * 110, base - 130), (cx + sx * 22, base - 120)], fill=(30, 28, 44), width=30, joint="curve")
        d.line([(cx + sx * 80, base - 230), (cx + sx * 110, base - 130), (cx + sx * 22, base - 120)], fill=white, width=20, joint="curve")
    if phone:
        d.rounded_rectangle([cx - 24, base - 190, cx + 24, base - 110], 8, fill=(30, 30, 46))
    if tired:
        # Heavy eyelids and dark circles.
        for sx in (-1, 1):
            ex = cx + sx * 24
            d.arc([ex - 14, base - 345, ex + 14, base - 325], 0, 180, fill=(120, 100, 150, int(255 * tired)), width=5)
    img.alpha_composite(layer)
    if screen_on:
        soft_glow(img, cx, base - 220, 170, (150, 190, 255), int(90 * screen_on))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([cx - 20, base - 186, cx + 20, base - 114], 6, fill=(200, 220, 255))
    # The duvet over the legs.
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([cx - 220, base - 20, cx + 220, BED_TOP + 380], 40, fill=(80, 90, 150))
    d.arc([cx - 220, base + 40, cx + 220, base + 200], 200, 340, fill=(66, 74, 130), width=8)


def person_lying(img, cx):
    """Asleep, phone on the nightstand."""
    d = ImageDraw.Draw(img)
    base = BED_TOP + 120
    d.rounded_rectangle([cx - 160, base - 150, cx + 40, base - 60], 40, fill=(200, 200, 225))
    d.ellipse([cx - 120, base - 210, cx + 4, base - 86], fill=(240, 240, 248), outline=(30, 28, 44), width=6)
    for sx in (-1, 1):
        ex = cx - 58 + sx * 24
        d.arc([ex - 14, base - 160, ex + 14, base - 140], 0, 180, fill=(30, 28, 44), width=5)
    d.rounded_rectangle([cx - 220, base - 80, cx + 220, BED_TOP + 380], 40, fill=(80, 90, 150))
    d.arc([cx - 220, base - 20, cx + 220, base + 140], 200, 340, fill=(66, 74, 130), width=8)


def phone_on_stand(img):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([560, BED_TOP + 16, 600, BED_TOP + 40], 6, fill=(30, 30, 46))


def zzz(img, cx, t):
    for k in range(3):
        phase = (t * 0.6 + k / 3) % 1
        x = cx + 40 + phase * 80 + k * 10
        y = BED_TOP - 40 - phase * 220
        size = 36 + k * 10
        layer = Image.new("RGBA", (120, 120), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((60, 60), "Z", font=font(BOLD, size), fill=(200, 210, 255), anchor="mm")
        put_center(img, layer, x, y, 1, math.sin(math.pi * phase))


@functools.lru_cache(None)
def label(text_):
    f = font(BOLD, 44)
    w = int(f.getlength(text_) + 20)
    img = Image.new("RGBA", (w, 70), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((w / 2, 35), text_, font=f, fill=WHITE, anchor="mm")
    return img


@functools.lru_cache(None)
def badge(text_, color):
    f = font(BOLD, 40)
    w = int(f.getlength(text_) + 120)
    img = Image.new("RGBA", (w, 84), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, 83], 42, fill=(14, 12, 30, 220), outline=(*color, 255), width=3)
    # A battery.
    d.rounded_rectangle([24, 26, 74, 58], 6, outline=color, width=4)
    d.rectangle([76, 36, 82, 48], fill=color)
    fill = 0.12 if color != MINT else 1.0
    d.rectangle([30, 32, 30 + 38 * fill, 52], fill=color)
    d.text((w - 24, 42), text_, font=f, fill=WHITE, anchor="rm")
    return img


@functools.lru_cache(None)
def screen_badge(text_, minutes):
    f_label, f_value = font(SEMI, 30), font(BOLD, 40)
    value = f"{minutes // 60}h {minutes % 60:02d}m"
    w = int(f_label.getlength(text_) + f_value.getlength("3h 00m") + 90)
    img = Image.new("RGBA", (w, 76), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, 75], 38, fill=(14, 12, 30, 220), outline=(255, 255, 255, 50), width=2)
    d.ellipse([24, 30, 40, 46], fill=(255, 92, 110))
    d.text((54, 38), text_, font=f_label, fill=(200, 195, 230), anchor="lm")
    d.text((w - 26, 38), value, font=f_value, fill=(255, 120, 130), anchor="rm")
    return img


# MARK: Frames

def scene(t, lang):
    copy = COPY_NIGHT[lang]
    dawn = smooth(seg(t, DAWN - 0.6, DAWN + 0.4))
    img = room(round(dawn, 2)).copy()
    alarm = seg(t, DAWN, DAWN + 1.5) if DAWN <= t < DAWN + 1.5 else 0
    clock(img, clock_minute(t), alarm)

    # Left: scrolls all night, then wakes up drained.
    flicker = 0.75 + 0.25 * math.sin(t * 9) * math.sin(t * 3.7)
    person_sitting(img, LEFT_X, flicker if t < DAWN else 0.6, tired=seg(t, DAWN, DAWN + 0.6))

    # Right: Pip says no, the phone goes down, sleep, then a fresh morning.
    lie = smooth(seg(t, PHONE_DOWN, PHONE_DOWN + 0.7)) * (1 - smooth(seg(t, DAWN + 0.4, DAWN + 1.0)))
    sitting = Image.new("RGBA", img.size, (0, 0, 0, 0))
    person_sitting(sitting, RIGHT_X, 1.0 if t < PHONE_DOWN else 0, phone=t < PHONE_DOWN)
    lying = Image.new("RGBA", img.size, (0, 0, 0, 0))
    person_lying(lying, RIGHT_X)
    if lie < 1:
        put(img, sitting, 0, 0, 1 - lie)
    if lie > 0:
        put(img, lying, 0, 0, lie)
    if t >= PHONE_DOWN:
        phone_on_stand(img)
    if PHONE_DOWN + 0.8 <= t < DAWN:
        zzz(img, RIGHT_X, t)

    # Pip's no on the right phone.
    if PIP <= t < PHONE_DOWN + 0.2:
        pop = back(seg(t, PIP, PIP + 0.35)) * (1 - seg(t, PHONE_DOWN - 0.1, PHONE_DOWN + 0.2))
        put_center(img, pip_big(), RIGHT_X, BED_TOP - 360, 0.42 * pop, clamp(pop))
        line = speech(COPY["bodyguard"][lang][2])
        put_center(img, line, RIGHT_X - 20, BED_TOP - 520, back(seg(t, PIP + 0.3, PIP + 0.55)), clamp(pop))

    # Labels above the beds.
    for text_, cx in zip(copy["labels"], (LEFT_X, RIGHT_X)):
        put_center(img, label(text_), cx, 560)

    # The scroller's screen time climbing.
    if t < DAWN + 0.8:
        put_center(img, screen_badge(copy["screen"], screen_minutes(t)), LEFT_X, BED_TOP - 520, 1, 1 - seg(t, DAWN + 0.5, DAWN + 0.8))

    # Morning batteries.
    if t >= DAWN + 0.8:
        k = back(seg(t, DAWN + 0.8, DAWN + 1.1))
        put_center(img, badge(copy["battery"][0], (255, 92, 110)), LEFT_X, BED_TOP - 470, k, clamp(k))
        k = back(seg(t, DAWN + 1.0, DAWN + 1.3))
        put_center(img, badge(copy["battery"][1], MINT), RIGHT_X, BED_TOP - 470, k, clamp(k))

    # Words.
    put(img, title(*copy["hook"], size=84), 0, 250, 1 - seg(t, TIMELAPSE - 0.3, TIMELAPSE))
    if TIMELAPSE <= t < DAWN:
        k = seg(t, TIMELAPSE, TIMELAPSE + 0.3) * (1 - seg(t, DAWN - 0.3, DAWN))
        put(img, title(copy["later"], size=76, gradient=False), 0, 290, k)
    if t >= DAWN + 1.6:
        k = seg(t, DAWN + 1.6, DAWN + 2.0)
        put(img, title(*copy["morning"], size=88), 0, 250 + 20 * (1 - ease_out(k)), k)
    return img


@functools.lru_cache(None)
def speech(text_):
    return bubble(text_, 34)


def frame(t, lang):
    if t < END_CARD - CROSSFADE:
        return scene(t, lang)
    card = end(END + (t - END_CARD + CROSSFADE), lang)
    if t < END_CARD:
        return Image.blend(scene(t, lang), card, seg(t, END_CARD - CROSSFADE, END_CARD))
    return card


# MARK: Sound

def soundtrack():
    n = int(DURATION * RATE)
    mix = np.zeros(n)
    rng = np.random.default_rng(3)

    def add(start, sig, gain):
        i = int(start * RATE)
        sig = sig[: max(0, n - i)]
        mix[i:i + len(sig)] += sig * gain

    def tone(freq, dur, harmonics=(1.0,)):
        t = np.arange(int(dur * RATE)) / RATE
        return sum(a * np.sin(2 * np.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))

    def decay(dur, rate=6):
        return np.exp(-np.linspace(0, rate, int(dur * RATE)))

    # A slow, dreamy night pad.
    for f in (110.0, 164.8, 220.0, 277.2):
        dur = DAWN
        sig = tone(f, dur, (1, 0.2)) * np.minimum(1, np.linspace(0, dur / 1.5, int(dur * RATE)))
        sig *= np.linspace(1, 0.4, len(sig))
        add(0, sig, 0.02)
    # A notification at the start, Pip's pop and blip.
    for f, d in [(1318.5, 0.3), (1975.5, 0.42)]:
        add(d, tone(f, 0.7, (1, 0.2)) * decay(0.7, 5), 0.1)
    tt = np.arange(int(0.14 * RATE)) / RATE
    add(PIP, np.sin(2 * np.pi * (260 * tt + 2200 * tt ** 2)) * np.exp(-tt * 25), 0.35)
    for f, d in [(880, 0), (1320, 0.06)]:
        add(PIP + 0.3 + d, tone(f, 0.09) * decay(0.09, 5), 0.12)
    # A soft thud as the phone goes down.
    tt = np.arange(int(0.25 * RATE)) / RATE
    add(PHONE_DOWN + 0.2, np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 18), 0.4)
    # Clock ticks racing through the night.
    for i in range(40):
        when = TIMELAPSE + (NIGHT_END - 0.5 - TIMELAPSE) * (i / 40) ** 0.8
        click = rng.standard_normal(int(0.01 * RATE)) * decay(0.01, 8)
        add(when, click, 0.1)
    # The alarm, then a bright morning chord.
    for k in range(6):
        add(DAWN + k * 0.25, tone(1760, 0.12) * decay(0.12, 3), 0.08)
    dur = END_CARD + 0.5 - (DAWN + 1.0)
    for f in (261.6, 329.6, 392.0, 523.3):
        sig = tone(f, dur, (1, 0.25)) * np.minimum(1, np.linspace(0, dur / 0.8, int(dur * RATE)))
        add(DAWN + 1.0, sig * np.linspace(1, 0.6, len(sig)), 0.022)
    # The end card.
    tt = np.arange(int(0.14 * RATE)) / RATE
    add(END_CARD + 0.1, np.sin(2 * np.pi * (300 * tt + 2000 * tt ** 2)) * np.exp(-tt * 25), 0.3)
    dur = DURATION - END_CARD
    for f in (130.8, 196.0, 261.6, 329.6, 392.0):
        sig = tone(f, dur, (1, 0.25)) * np.minimum(1, np.linspace(0, dur / 0.5, int(dur * RATE)))
        add(END_CARD, sig * np.linspace(1, 0, len(sig)) ** 0.6, 0.02)
    mix /= max(1e-9, np.abs(mix).max()) / 0.89
    return mix


def render(lang, path):
    with tempfile.TemporaryDirectory() as tmp:
        audio = os.path.join(tmp, "sound.wav")
        write_wav(audio, soundtrack())
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
             "-r", str(FPS), "-i", "-", "-i", audio, "-c:v", "libx264", "-preset", "medium", "-crf", "18",
             "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p", "-color_primaries", "bt709",
             "-color_trc", "bt709", "-colorspace", "bt709",
             "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", path],
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
            frame(float(t), "sv").convert("RGB").save(os.path.join(out, f"night-{t}.png"))
        return
    for lang in ("sv", "en"):
        folder = os.path.join(OUT, "ads", lang)
        os.makedirs(folder, exist_ok=True)
        render(lang, os.path.join(folder, "same-night-video-1080x1920.mp4"))


if __name__ == "__main__":
    main()
