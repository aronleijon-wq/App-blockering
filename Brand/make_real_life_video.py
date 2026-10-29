"""Puts the "real life" overlays on a clip filmed outdoors: the time won back counting up while you are out,
then the streak widget on frosted glass, then the animated end card.

The times below are for the first clip (fishing from a boat, the camera pans to the lake at about 6 s); change
them to fit another take.

Run: python3 Brand/make_real_life_video.py input.mov output.mp4 [sv|en]
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_brand import BLACK, BOLD, SEMI, WHITE, font, pip
from make_overlay_video import SDR_OUTPUT, to_sdr
from make_real_life_ads import COPY
from make_video import END, RATE, back, clamp, ease_out, end, put, seg, smooth, write_wav

W, H, FPS = 1080, 1920, 30

WON = 0.4             # The time won back starts counting.
WON_GONE = 5.9
STREAK = 6.3          # The camera has turned to the lake.
END_CARD = 10.6
END_LENGTH = 3.2
CROSSFADE = 0.35

WON_MINUTES = 2 * 60 + 41
STREAK_DAYS = 20
GOLD = (255, 214, 110)
MINT_TEXT = (150, 255, 215)


def shadowed(draw, xy, text, f, fill, anchor="ma"):
    draw.text((xy[0] + 2, xy[1] + 3), text, font=f, fill=(0, 0, 0, 140), anchor=anchor)
    draw.text(xy, text, font=f, fill=fill, anchor=anchor)


def text_layer(text, f, fill):
    l, t, r, b = f.getbbox(text)
    layer = Image.new("RGBA", (r - l + 20, b - t + 24), (0, 0, 0, 0))
    shadowed(ImageDraw.Draw(layer), (layer.width / 2, 8 - t), text, f, fill)
    return layer


def won_text(minutes, lang):
    h, m = divmod(minutes, 60)
    return f"{h} h {m:02d} min" if h else f"{m} min"


def won_back(img, t, lang):
    label, _, under, proud = COPY[lang]["won"]
    out = 1 - seg(t, WON_GONE - 0.3, WON_GONE)
    if out <= 0 or t < WON:
        return
    k = ease_out(seg(t, WON, WON + 0.35))
    layer = text_layer(label, font(BOLD, 46), WHITE)
    put(img, layer, (W - layer.width) / 2, 250 + 20 * (1 - k), k * out)

    count = ease_out(seg(t, WON + 0.2, WON + 1.6))
    layer = text_layer(won_text(round(WON_MINUTES * count), lang), font(BLACK, 128), MINT_TEXT)
    pop = back(seg(t, WON + 0.2, WON + 0.5))
    if pop < 1:
        layer = layer.resize((max(1, int(layer.width * (0.8 + 0.2 * pop))), max(1, int(layer.height * (0.8 + 0.2 * pop)))))
    put(img, layer, (W - layer.width) / 2, 300 + (150 - layer.height) / 2, clamp(pop) * out)

    for text_, size, path, start, y in ((under, 46, BOLD, WON + 1.7, 455), (proud, 36, SEMI, WON + 2.2, 525)):
        k = ease_out(seg(t, start, start + 0.35))
        layer = text_layer(text_, font(path, size), WHITE)
        put(img, layer, (W - layer.width) / 2, y + 20 * (1 - k), k * out)


def streak(img, t, lang):
    caption, unit, sub = COPY[lang]["streak"]
    if t < STREAK:
        return
    k = ease_out(seg(t, STREAK, STREAK + 0.4))
    for i, line in enumerate(caption.split("\n")):
        layer = text_layer(line, font(BOLD, 46), WHITE)
        put(img, layer, (W - layer.width) / 2, 520 + i * 58 + 20 * (1 - k), k)

    pop = back(seg(t, STREAK + 0.3, STREAK + 0.75))
    if pop <= 0:
        return
    scale = 0.7 + 0.3 * pop
    bw, bh = int(480 * scale), int(540 * scale)
    x0, y0 = int((W - bw) / 2), int(990 - bh / 2)
    # Frosted glass: the video behind the card, blurred and tinted.
    patch = img.crop((x0, y0, x0 + bw, y0 + bh)).filter(ImageFilter.GaussianBlur(28))
    patch = Image.alpha_composite(patch, Image.new("RGBA", patch.size, (40, 28, 80, 120)))
    card = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    mask = Image.new("L", (bw, bh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, bw - 1, bh - 1], int(64 * scale), fill=255)
    card.paste(patch, (0, 0), mask)

    inner = Image.new("RGBA", (480, 540), (0, 0, 0, 0))
    p = pip(190)
    inner.alpha_composite(p, ((480 - p.width) // 2, 50))
    d = ImageDraw.Draw(inner)
    days = round(STREAK_DAYS * ease_out(seg(t, STREAK + 0.6, STREAK + 1.5)))
    d.text((240, 245), str(days), font=font(BLACK, 150), fill=GOLD, anchor="ma")
    d.text((240, 405), unit, font=font(BLACK, 44), fill=GOLD, anchor="ma")
    d.text((240, 465), sub, font=font(SEMI, 25), fill=(255, 255, 255, 200), anchor="ma")
    card.alpha_composite(inner.resize((bw, bh), Image.LANCZOS))
    put(img, card, x0, y0, clamp(pop))


def frame(source, t, lang):
    img = source.convert("RGBA")
    won_back(img, t, lang)
    streak(img, t, lang)
    if t >= END_CARD:
        k = smooth(seg(t, END_CARD, END_CARD + CROSSFADE))
        card = end(END + (t - END_CARD), lang).convert("RGBA")
        img = Image.blend(img, card, k) if k < 1 else card
    return img.convert("RGB")


# MARK: Sound

def effects(length):
    n = int(length * RATE)
    mix = np.zeros(n)
    rng = np.random.default_rng(3)

    def add(start, sig, gain):
        i = int(start * RATE)
        sig = sig[: max(0, n - i)]
        mix[i:i + len(sig)] += sig * gain

    def tick(start):
        click = rng.standard_normal(int(0.012 * RATE)) * np.exp(-np.linspace(0, 8, int(0.012 * RATE)))
        add(start, click, 0.1)

    def chime(start, notes, gain=0.1):
        for f, d in notes:
            tt = np.arange(int(0.8 * RATE)) / RATE
            add(start + d, (np.sin(2 * np.pi * f * tt) + 0.2 * np.sin(4 * np.pi * f * tt)) * np.exp(-tt * 6), gain)

    def pop(start, gain=0.35):
        tt = np.arange(int(0.14 * RATE)) / RATE
        add(start, np.sin(2 * np.pi * (260 * tt + 2200 * tt ** 2)) * np.exp(-tt * 25), gain)

    for i in range(0, 42, 3):
        tick(WON + 0.2 + 1.4 * (1 - (1 - i / 42) ** (1 / 3)))
    chime(WON + 1.6, [(1318.5, 0), (1975.5, 0.1)])
    pop(STREAK + 0.3)
    for i in range(1, STREAK_DAYS + 1, 2):
        tick(STREAK + 0.6 + 0.9 * (1 - (1 - i / STREAK_DAYS) ** (1 / 3)))
    chime(STREAK + 1.5, [(1046.5, 0), (1568, 0.1)])

    pop(END_CARD + 0.1, 0.3)
    dur = n / RATE - END_CARD
    for f in (130.8, 196.0, 261.6, 329.6, 392.0, 523.3):
        tt = np.arange(int(dur * RATE)) / RATE
        tone = np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(4 * np.pi * f * tt)
        envelope = np.minimum(1, tt / 0.6) * np.linspace(1, 0, len(tt)) ** 0.7
        add(END_CARD, tone * envelope, 0.02)
    return mix


def main():
    source, out = sys.argv[1], sys.argv[2]
    lang = sys.argv[3] if len(sys.argv) > 3 else "sv"
    length = END_CARD + END_LENGTH
    with tempfile.TemporaryDirectory() as tmp:
        sfx = os.path.join(tmp, "effects.wav")
        write_wav(sfx, effects(length))
        decoder = subprocess.Popen(["ffmpeg", "-v", "error", "-i", source, "-vf", f"{to_sdr(source)}scale={W}:{H},fps={FPS}",
                                    "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
        # The clip's own sound (water, wind) stays, quieter than speech would be, under the effects.
        encoder = subprocess.Popen(
            ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
             "-i", "-", "-i", source, "-i", sfx, "-filter_complex",
             f"[1:a:0]aresample={RATE},loudnorm=I=-20:TP=-2:LRA=9,aresample={RATE},apad,"
             f"afade=t=out:st={END_CARD:.2f}:d=0.5[bed];[bed][2:a]amix=inputs=2:duration=shortest:normalize=0[a]",
             "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "medium", "-crf", "18", *SDR_OUTPUT,
             "-c:a", "aac", "-b:a", "192k", "-t", f"{length:.2f}", "-movflags", "+faststart", out],
            stdin=subprocess.PIPE)
        size = W * H * 3
        last = None
        for i in range(int(length * FPS)):
            raw = decoder.stdout.read(size)
            if len(raw) == size:
                last = Image.frombytes("RGB", (W, H), raw)
            encoder.stdin.write(frame(last, i / FPS, lang).tobytes())
        decoder.stdout.close()
        decoder.wait()
        encoder.stdin.close()
        if encoder.wait() != 0:
            raise SystemExit("ffmpeg failed")
    print(f"{out}: {length:.1f} s")


if __name__ == "__main__":
    main()
