"""Puts Paus graphics on top of a filmed talking-head video: a counter rushing up to 20 years, the Paus logo
with Pip, the before and after bars and the App Store call to action, then the animated end card.

The graphics sit in the lower half of the picture, so they don't cover the face. The times below are for the
first founder video; change them to fit another take.

Run: python3 Brand/make_overlay_video.py input.mp4 output.mp4
"""
import functools
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

from make_ads import COPY, DIM, GREY
from make_brand import BLACK, CARD, CYAN, MINT, ORANGE, PINK, SEMI, WHITE, app_icon, font, gradient_text, rounded
from make_video import (END, RATE, back, bars_card, bubble, clamp, cta, duration, ease_out, end, faded, pip_big, put,
                        put_center, seg, smooth, write_wav)

W, H, FPS = 1080, 1920, 30
LANG = "sv"

# When things happen in the filmed video, in seconds.
YEARS = 6.0           # "…då blir det tjugo år"
YEARS_GONE = 12.3
NAME = 18.5           # "Den heter Paus"
NAME_GONE = 21.7
HALVE = 22.0          # "Halvera din skärmtid"
TEN_YEARS = 24.5      # "…då får du tillbaka tio år"
HALVE_GONE = 27.7
DOWNLOAD = 28.0       # "Ladda ner Paus i App Store. Det är gratis."
END_CARD = 30.4       # Right after the last word.
END_LENGTH = 3.2
CROSSFADE = 0.35

LOWER = 1330          # The middle of the band the graphics use, below the chin.


# MARK: The pieces

@functools.lru_cache(None)
def years_card(years):
    cw, ch = 780, 330
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, cw - 1, ch - 1], 48, fill=(*CARD, 235), outline=(255, 255, 255, 40), width=2)
    d.text((cw / 2, 34), "5 h om dagen × hela livet", font=font(SEMI, 34), fill=GREY, anchor="ma")
    number = gradient_text(f"{years} år", 150)
    put(img, number, (cw - number.width) / 2, 92)
    # How much of a 95 year life that is.
    x0, x1, y = 60, cw - 60, 270
    d.rounded_rectangle([x0, y, x1, y + 22], 11, fill=(255, 255, 255, 40))
    if years:
        d.rounded_rectangle([x0, y, x0 + (x1 - x0) * years / 95, y + 22], 11, fill=PINK)
    return img


def years_at(t):
    return round(20 * ease_out(seg(t, YEARS, YEARS + 0.7)))


@functools.lru_cache(None)
def logo():
    icon = rounded(app_icon(150).convert("RGB"))
    word = gradient_text("Paus", 130)
    cw, ch = icon.width + 40 + word.width + 100, 210
    img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, cw - 1, ch - 1], 60, fill=(*CARD, 235), outline=(255, 255, 255, 40),
                                          width=2)
    put(img, icon, 50, 30)
    put(img, word, 50 + icon.width + 40, (ch - word.height) / 2)
    return img


@functools.lru_cache(None)
def pip_line():
    return bubble(COPY["bodyguard"][LANG][2], 36)


@functools.lru_cache(None)
def ten_years():
    f = font(BLACK, 52)
    label = "+10 år tillbaka"
    cw = int(f.getlength(label) + 80)
    img = Image.new("RGBA", (cw, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, cw - 1, 95], 48, fill=MINT)
    d.text((cw / 2, 48), label, font=f, fill=(20, 16, 40), anchor="mm")
    return img


@functools.lru_cache(None)
def download_bar():
    bar = Image.new("RGBA", (W - 80, 200), (0, 0, 0, 0))
    ImageDraw.Draw(bar).rounded_rectangle([0, 0, bar.width - 1, 199], 60, fill=(*CARD, 235),
                                          outline=(255, 255, 255, 40), width=2)
    row = Image.new("RGBA", (W, 200), (0, 0, 0, 0))
    cta(row, LANG, 148)
    put(bar, row, -40, 0)
    return bar


# MARK: One frame

def overlays(img, t):
    # The years counter rushes up, lands with a bump and leaves.
    if YEARS <= t < YEARS_GONE + 0.4:
        enter = back(seg(t, YEARS - 0.1, YEARS + 0.25))
        bump = 1 + 0.08 * math.sin(math.pi * seg(t, YEARS + 0.7, YEARS + 0.95))
        leave = 1 - smooth(seg(t, YEARS_GONE, YEARS_GONE + 0.35))
        put_center(img, years_card(years_at(t)), W / 2, LOWER, 0.6 + 0.4 * enter * bump, clamp(enter) * leave)

    # The logo, then Pip with his line.
    if NAME <= t < NAME_GONE + 0.4:
        leave = 1 - smooth(seg(t, NAME_GONE, NAME_GONE + 0.35))
        pop = back(seg(t, NAME, NAME + 0.35))
        put_center(img, logo(), W / 2, LOWER - 120, pop, clamp(pop) * leave)
        pop = back(seg(t, NAME + 0.8, NAME + 1.15))
        bob = math.sin(t * 3) * 8
        put_center(img, pip_big(), W - 200, LOWER + 200 + bob, 0.6 * pop, clamp(pop) * leave)
        pop = back(seg(t, NAME + 1.1, NAME + 1.35))
        line = pip_line()
        put_center(img, line, W - 200 - 170 - line.width / 2 + 130, LOWER + 70, pop, clamp(pop) * leave)

    # Before and after, then the ten years won back.
    if HALVE <= t < HALVE_GONE + 0.4:
        enter = ease_out(seg(t, HALVE, HALVE + 0.45))
        leave = 1 - smooth(seg(t, HALVE_GONE, HALVE_GONE + 0.35))
        p = ease_out(seg(t, HALVE + 0.4, HALVE + 1.4))
        before, after = COPY["before-after"][LANG][2]
        average = "Snitt per dag"
        cards = Image.new("RGBA", (940, 700), (0, 0, 0, 0))
        put(cards, bars_card(before, average, "6h 12m", (6.8, 5.6, 7.1, 6.2, 6.5), [ORANGE, PINK], p), 0, 0)
        put(cards, bars_card(after, average, duration(372 - 188 * p), (3.4, 2.9, 3.1, 2.6, 3.2), [MINT, CYAN], p),
            480, 0)
        ImageDraw.Draw(cards).text((936, 684), COPY["before-after"][LANG][3], font=font(SEMI, 22), fill=DIM,
                                   anchor="rb")
        put_center(img, cards, W / 2, LOWER + 130 + 120 * (1 - enter), 0.72, enter * leave)
        pop = back(seg(t, TEN_YEARS, TEN_YEARS + 0.35))
        put_center(img, ten_years(), W / 2, LOWER - 192, pop, clamp(pop) * leave)

    # The call to action slides up.
    if DOWNLOAD <= t:
        enter = ease_out(seg(t, DOWNLOAD, DOWNLOAD + 0.45))
        bar = download_bar()
        put(img, bar, 40, LOWER - 100 + 200 * (1 - enter), enter)


def frame(source, t):
    img = source.convert("RGBA")
    overlays(img, t)
    if t >= END_CARD:
        k = smooth(seg(t, END_CARD, END_CARD + CROSSFADE))
        card = end(END + (t - END_CARD), LANG)
        img = Image.blend(img, card, k) if k < 1 else card
    return img.convert("RGB")


# MARK: Sound effects

def effects(length):
    n = int(length * RATE)
    mix = np.zeros(n)
    rng = np.random.default_rng(2)

    def add(start, sig, gain):
        i = int(start * RATE)
        sig = sig[: max(0, n - i)]
        mix[i:i + len(sig)] += sig * gain

    def sine(freq, dur, harmonics=(1.0,)):
        t = np.arange(int(dur * RATE)) / RATE
        return sum(a * np.sin(2 * np.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))

    def decay(dur, rate=6):
        return np.exp(-np.linspace(0, rate, int(dur * RATE)))

    def pop(start, gain=0.4):
        tt = np.arange(int(0.14 * RATE)) / RATE
        add(start, np.sin(2 * np.pi * (260 * tt + 2200 * tt ** 2)) * np.exp(-tt * 25), gain)

    def whoosh(start, gain=0.05):
        noise = np.convolve(rng.standard_normal(int(0.35 * RATE)), np.ones(5) / 5, mode="same")
        add(start, noise * np.sin(np.linspace(0, np.pi, len(noise))) ** 2, gain)

    # A tick per year on the way up, and a thump on twenty.
    previous = 0
    for i in range(int(1.0 * FPS)):
        t = YEARS + i / FPS
        if years_at(t) != previous:
            click = rng.standard_normal(int(0.012 * RATE)) * decay(0.012, 8)
            add(t, click + 0.6 * sine(2200, 0.012) * decay(0.012), 0.12)
            previous = years_at(t)
    tt = np.arange(int(0.4 * RATE)) / RATE
    add(YEARS + 0.7, np.sin(2 * np.pi * (90 * tt - 40 * tt ** 2)) * np.exp(-tt * 9), 0.5)

    pop(NAME)
    pop(NAME + 0.8, 0.3)
    for f, d in [(880, 0), (1320, 0.06)]:
        add(NAME + 1.1 + d, sine(f, 0.09) * decay(0.09, 5), 0.12)
    whoosh(HALVE)
    tt = np.arange(int(1.0 * RATE)) / RATE
    add(HALVE + 0.4, np.sin(2 * np.pi * (300 * tt + 300 * tt ** 2)) * np.sin(np.linspace(0, np.pi, len(tt))), 0.04)
    for f, d in [(1318.5, 0), (1975.5, 0.12)]:
        add(TEN_YEARS + d, sine(f, 0.9, (1, 0.2)) * decay(0.9, 5), 0.1)
    whoosh(DOWNLOAD)

    # The end card: a pop and a warm chord.
    pop(END_CARD + 0.1, 0.3)
    dur = n / RATE - END_CARD
    for f in (130.8, 196.0, 261.6, 329.6, 392.0, 523.3):
        tone = sine(f, dur, (1, 0.25))
        envelope = np.minimum(1, np.linspace(0, dur / 0.6, len(tone))) * np.linspace(1, 0, len(tone)) ** 0.7
        add(END_CARD, tone * envelope, 0.02)
    return mix


# MARK: Output

# Plain HD video, converted from RGB with the matching matrix and labelled as such, so players don't guess.
SDR_OUTPUT = ["-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p", "-color_primaries", "bt709",
              "-color_trc", "bt709", "-colorspace", "bt709"]


def to_sdr(source):
    """iPhones film in HDR. Read as ordinary video it looks grey and flat, so tone map it to standard colours first."""
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=color_transfer",
                            "-of", "csv=p=0", source], capture_output=True, text=True, check=True)
    transfer = probe.stdout.strip()
    if transfer not in ("arib-std-b67", "smpte2084"):
        return ""
    return (f"zscale=tin={transfer}:min=bt2020nc:pin=bt2020:rin=tv:t=linear:npl=203,format=gbrpf32le,"
            "zscale=p=bt709,tonemap=tonemap=mobius:desat=0,zscale=t=bt709:m=bt709:r=tv,")


def main():
    source, out = sys.argv[1], sys.argv[2]
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", source],
                           capture_output=True, text=True, check=True)
    length = END_CARD + END_LENGTH
    with tempfile.TemporaryDirectory() as tmp:
        sfx = os.path.join(tmp, "effects.wav")
        write_wav(sfx, effects(length))
        decoder = subprocess.Popen(["ffmpeg", "-v", "error", "-i", source, "-vf", f"{to_sdr(source)}scale={W}:{H},fps={FPS}",
                                    "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        encoder = subprocess.Popen(
            ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
             "-i", "-", "-i", source, "-i", sfx, "-filter_complex",
             f"[1:a]aresample={RATE},acompressor=threshold=0.1:ratio=3:attack=10:release=200,"
             f"loudnorm=I=-14:TP=-1.5:LRA=9,aresample={RATE},apad,afade=t=out:st={END_CARD:.2f}:d=0.4[voice];"
             f"[voice][2:a]amix=inputs=2:duration=shortest:normalize=0[a]",
             "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "medium", "-crf", "18", *SDR_OUTPUT,
             "-c:a", "aac", "-b:a", "192k", "-t", f"{length:.2f}", "-movflags", "+faststart", out],
            stdin=subprocess.PIPE)
        size = W * H * 3
        last = None
        for i in range(int(length * FPS)):
            raw = decoder.stdout.read(size)
            if len(raw) == size:
                last = Image.frombytes("RGB", (W, H), raw)
            encoder.stdin.write(frame(last, i / FPS).tobytes())
        decoder.stdout.close()
        decoder.wait()
        encoder.stdin.close()
        if encoder.wait() != 0:
            raise SystemExit("ffmpeg failed")
    print(f"{out}: {length:.1f} s (source {float(probe.stdout):.1f} s)")


if __name__ == "__main__":
    main()
