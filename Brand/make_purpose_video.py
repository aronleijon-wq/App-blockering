"""The "purpose" edit, shot for shot after a reference: "Just one last time" typed in a white bar, a blinking
REC, the dictionary card for purpose, "False pleasure won't fulfill your purpose" on paper, a figure falling
and one staying down, "Chase your purpose", then Paus.

Run from the repository root: python3 Brand/make_purpose_video.py
Stills: python3 Brand/make_purpose_video.py --stills 1.6,3.6,4.6,5.4,8.1,8.5,9.4,10.3,11.2,12.8,15 out_dir
"""
import functools
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from make_brand import BOLD, OUT, SEMI, app_icon, rounded
from make_video import RATE, back, clamp, ease_out, seg, smooth, write_wav

W, H, FPS = 1080, 1920, 30
REGULAR = "/usr/share/fonts/opentype/inter/Inter-Regular.otf"
MEDIUM = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"
SERIF = "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf"
SERIF_BOLD = "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"

ORANGE = (232, 150, 30)
DARK_RED = (150, 10, 14)
HIGHLIGHT = (238, 220, 60)

TYPED = ["Just", "one", "last", "time"]
PAPER_WORDS = ["False pleasure won't", "fulfill", "your", "purpose"]

# When each shot starts.
BAR, REC, PURPOSE, CARD, PAPER, CLOSE, WIDE, ACCIDENT, CHOICE, GAP, CHASE, PAUS = (
    0.0, 2.4, 4.4, 4.9, 5.9, 8.3, 8.8, 9.9, 10.8, 11.6, 11.9, 14.0)
DURATION = 17.0


@functools.lru_cache(None)
def font(path, size):
    return ImageFont.truetype(path, size)


def black():
    return Image.new("RGBA", (W, H), (0, 0, 0, 255))


def width_of(d, s, f):
    l, _, r, _ = d.textbbox((0, 0), s, font=f)
    return r - l


def alpha_text(img, xy, s, f, fill, k, anchor="la"):
    if k <= 0:
        return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, s, font=f, fill=(*fill[:3], int(255 * k)), anchor=anchor)
    img.alpha_composite(layer)


@functools.lru_cache(None)
def paper():
    rng = np.random.default_rng(11)
    img = np.zeros((H, W, 3), np.float32) + 196
    img += rng.normal(0, 9, (H, W, 1))
    img += rng.normal(0, 6, (H // 5 + 1, W // 5 + 1, 1)).repeat(5, 0).repeat(5, 1)[:H, :W]
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((x - W / 2) / (W * 0.6)) ** 2 + ((y - H / 2) / (H * 0.55)) ** 2)
    img *= (1 - np.clip(r - 0.55, 0, 1) * 1.3)[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


@functools.lru_cache(None)
def grey():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((x - W / 2) / (W * 0.65)) ** 2 + ((y - H / 2) / (H * 0.55)) ** 2)
    img = 185 - np.clip(r - 0.4, 0, 1) * 150
    img = np.repeat(img[..., None], 3, 2)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


# MARK: Pictograms

def limbs(d, lines, joints, ink, width):
    for a, b in lines:
        d.line([joints[a], joints[b]], fill=ink, width=width)
    for p in joints.values():
        d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=ink)


def falling(img, x, ground, u, ink, lean):
    """Stumbling forward to the right, hands reaching for the ground. `lean` goes from 0 (stumbling)
    to 1 (on a knee)."""
    d = ImageDraw.Draw(img)
    drop = 45 * lean * u
    hip = (x, ground - 150 * u + drop)
    shoulder = (x + 80 * u, ground - 235 * u + drop * 1.5)
    head = (shoulder[0] + 42 * u, shoulder[1] - 38 * u)
    j = {
        "hip": hip, "shoulder": shoulder,
        "knee1": (x + 50 * u, ground - 75 * u + drop * 0.4), "foot1": (x + 35 * u, ground - 10 * u),
        "knee2": (x - 40 * u, ground - 70 * u + drop * 0.9), "foot2": (x - 115 * u, ground - 40 * u + drop * 0.5),
        "elbow1": (shoulder[0] + 30 * u, shoulder[1] + 70 * u), "hand1": (shoulder[0] + 35 * u, shoulder[1] + 140 * u - drop * 0.6),
        "elbow2": (shoulder[0] - 5 * u, shoulder[1] + 75 * u), "hand2": (shoulder[0] + 5 * u, shoulder[1] + 145 * u - drop * 0.6),
    }
    limbs(d, [("hip", "shoulder"), ("hip", "knee1"), ("knee1", "foot1"), ("hip", "knee2"), ("knee2", "foot2"),
              ("shoulder", "elbow1"), ("elbow1", "hand1"), ("shoulder", "elbow2"), ("elbow2", "hand2")],
          j, ink, int(34 * u))
    r = 32 * u
    d.ellipse([head[0] - r, head[1] - r, head[0] + r, head[1] + r], fill=ink)


def sitting(img, x, ground, u, ink):
    """Sitting on the ground, hugging the knees, head down."""
    d = ImageDraw.Draw(img)
    hip = (x - 40 * u, ground - 22 * u)
    shoulder = (x - 30 * u, ground - 130 * u)
    j = {
        "hip": hip, "shoulder": shoulder,
        "knee": (x + 45 * u, ground - 105 * u), "foot": (x + 60 * u, ground - 18 * u),
        "hand": (x + 30 * u, ground - 80 * u),
    }
    limbs(d, [("hip", "shoulder"), ("hip", "knee"), ("knee", "foot"), ("shoulder", "hand")], j, ink, int(34 * u))
    head = (shoulder[0] + 30 * u, shoulder[1] - 25 * u)
    r = 30 * u
    d.ellipse([head[0] - r, head[1] - r, head[0] + r, head[1] + r], fill=ink)


def curved_arrow(d, start, end, bend, ink, width=5):
    pts = []
    for i in range(41):
        k = i / 40
        mx = (start[0] + end[0]) / 2 + bend[0]
        my = (start[1] + end[1]) / 2 + bend[1]
        x = (1 - k) ** 2 * start[0] + 2 * (1 - k) * k * mx + k ** 2 * end[0]
        y = (1 - k) ** 2 * start[1] + 2 * (1 - k) * k * my + k ** 2 * end[1]
        pts.append((x, y))
    d.line(pts, fill=ink, width=width, joint="curve")
    (x1, y1), (x2, y2) = pts[-4], pts[-1]
    a = math.atan2(y2 - y1, x2 - x1)
    for s in (-1, 1):
        d.line([(x2, y2), (x2 - 26 * math.cos(a + s * 0.5), y2 - 26 * math.sin(a + s * 0.5))], fill=ink, width=width)


# MARK: Shots

def bar(t):
    img = black()
    words = TYPED[: min(len(TYPED), int(t / 0.5) + 1)]
    k = 1 - smooth(seg(t, REC, REC + 0.5))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([0, 0, W, 150], fill=(242, 242, 242, int(255 * k)))
    d.text((W / 2, 75), " ".join(words), font=font(REGULAR, 68), fill=(10, 10, 10, int(255 * k)), anchor="mm")
    img.alpha_composite(layer)
    return img


def rec(t):
    img = bar(t) if t < REC + 0.5 else black()
    # Bright, dim, then bright again, like a camera's tally light.
    k = smooth(seg(t, REC, REC + 0.3)) * (0.35 if REC + 0.55 <= t < REC + 1.0 else 1)
    d = ImageDraw.Draw(img)
    f = font(BOLD, 78)
    color = tuple(int(c * k) for c in ORANGE)
    d.ellipse([W / 2 - 150, H / 2 - 32, W / 2 - 86, H / 2 + 32], fill=color)
    d.text((W / 2 - 60, H / 2), "REC", font=f, fill=color, anchor="lm")
    return img


def purpose(t):
    img = black()
    alpha_text(img, (W / 2, H / 2), "Purpose", font(SERIF_BOLD, 80), DARK_RED, smooth(seg(t, PURPOSE, PURPOSE + 0.2)), "mm")
    return img


def card(t):
    img = black()
    d = ImageDraw.Draw(img)
    box = (90, 700, W - 90, 1180)
    d.rectangle(box, outline="white", width=5)
    d.text((140, 750), "purpose", font=font(BOLD, 64), fill="white")
    d.text((140, 835), "/ˈpɜːrpəs/", font=font(REGULAR, 30), fill=(200, 200, 200))
    d.multiline_text((140, 905), "A clear goal or intention that gives\ndirection to your actions and keeps you\nfocused on what truly matters.",
                     font=font(REGULAR, 40), fill="white", spacing=16)
    return img


def paper_shot(t):
    img = paper().copy()
    d = ImageDraw.Draw(img)
    f = font(SERIF, 86)
    shown = min(len(PAPER_WORDS), int((t - PAPER - 0.1) / 0.5) + 1)
    line1 = PAPER_WORDS[0]
    line2 = " ".join(PAPER_WORDS[1:shown])
    y1, y2 = H / 2 - 80, H / 2 + 20
    hk = ease_out(seg(t, PAPER + 1.9, PAPER + 2.2))
    if hk > 0:
        for y, line in ((y1, line1), (y2, " ".join(PAPER_WORDS[1:]))):
            w = width_of(d, line, f)
            x0 = (W - w) / 2 - 14
            d.rectangle([x0, y - 6, x0 + (w + 28) * hk, y + 92], fill=HIGHLIGHT)
    d.text((W / 2, y1), line1, font=f, fill=(20, 20, 20), anchor="ma")
    if line2:
        full = " ".join(PAPER_WORDS[1:])
        x = (W - width_of(d, full, f)) / 2
        d.text((x, y2), line2, font=f, fill=(20, 20, 20))
    return img


def close(t):
    """Grey, black figure, close: the stumble."""
    img = grey().copy()
    falling(img, W / 2 - 60, H / 2 + 240, 1.6, (12, 12, 12), 0.3 + 0.4 * seg(t, CLOSE, WIDE))
    return img


def wide(t):
    img = black()
    s = 1.15 - 0.15 * ease_out(seg(t, WIDE, ACCIDENT))
    ground = H / 2 + 200
    d = ImageDraw.Draw(img)
    d.line([(0, ground), (W, ground)], fill="white", width=6)
    falling(img, W / 2 - 250 * s, ground, 1.3 * s, (245, 245, 245), 0.7 + 0.3 * seg(t, WIDE, WIDE + 0.4))
    sitting(img, W / 2 + 270 * s, ground, 1.3 * s, (245, 245, 245))
    return img


def accident(t):
    img = grey().copy()
    ground = H / 2 + 330
    d = ImageDraw.Draw(img)
    d.line([(0, ground), (W, ground)], fill=(12, 12, 12), width=6)
    falling(img, W / 2 - 120, ground, 1.5, (12, 12, 12), 1.0)
    sitting(img, W - 30, ground, 1.5, (12, 12, 12))
    k = ease_out(seg(t, ACCIDENT, ACCIDENT + 0.25))
    alpha_text(img, (W - 90, 690), "Falling down is an", font(MEDIUM, 56), (12, 12, 12), k, "ra")
    alpha_text(img, (W - 230, 760), "accident", font(BOLD, 60), (12, 12, 12), k, "ra")
    if k > 0:
        curved_arrow(ImageDraw.Draw(img), (W - 560, 760), (W / 2 + 60, 1020), (-120, -10), (12, 12, 12), 6)
    return img


def choice(t):
    img = black()
    ground = H / 2 - 40
    d = ImageDraw.Draw(img)
    d.line([(0, ground), (W, ground)], fill="white", width=6)
    falling(img, 60, ground, 1.5, (245, 245, 245), 1.0)
    sitting(img, W / 2 + 160, ground, 1.5, (245, 245, 245))
    k = ease_out(seg(t, CHOICE, CHOICE + 0.25))
    alpha_text(img, (120, ground + 330), "Staying down is a", font(MEDIUM, 56), (245, 245, 245), k)
    alpha_text(img, (250, ground + 400), "choice", font(BOLD, 60), (245, 245, 245), k)
    if k > 0:
        curved_arrow(ImageDraw.Draw(img), (460, ground + 440), (W / 2 + 170, ground + 30), (260, 90), (245, 245, 245), 6)
    return img


def chase(t):
    img = black()
    out = 1 - smooth(seg(t, PAUS - 0.6, PAUS - 0.1))
    f = font(SERIF_BOLD, 112)
    alpha_text(img, (W / 2, H / 2 - 120), "Chase", f, DARK_RED, smooth(seg(t, CHASE, CHASE + 0.3)) * out, "ma")
    words = "your purpose".split()
    shown = " ".join(words[: 1 + int(t >= CHASE + 0.9)]) if t >= CHASE + 0.5 else ""
    if shown:
        d = ImageDraw.Draw(img)
        x = (W - width_of(d, "your purpose", f)) / 2
        alpha_text(img, (x, H / 2 + 10), shown, f, DARK_RED, out)
    return img


def paus(t):
    img = black()
    k = [ease_out(seg(t, PAUS + 0.2 + i * 0.3, PAUS + 0.6 + i * 0.3)) for i in range(3)]
    icon = rounded(app_icon(180))
    icon.putalpha(icon.getchannel("A").point(lambda v: int(v * k[0])))
    img.alpha_composite(icon, ((W - 180) // 2, 700))
    alpha_text(img, (W / 2, 930), "Paus", font(BOLD, 72), (245, 245, 245), k[1], "ma")
    alpha_text(img, (W / 2, 1040), "Block the apps that steal your purpose.", font(REGULAR, 40), (220, 220, 220), k[2], "ma")
    alpha_text(img, (W / 2, 1110), "Free on the App Store", font(SEMI, 36), DARK_RED if False else (160, 160, 160), k[2], "ma")
    return img


SHOTS = [(BAR, bar), (REC, rec), (PURPOSE, purpose), (CARD, card), (PAPER, paper_shot), (CLOSE, close),
         (WIDE, wide), (ACCIDENT, accident), (CHOICE, choice), (GAP, lambda t: black()), (CHASE, chase), (PAUS, paus)]


def frame(t):
    draw = [f for start, f in SHOTS if t >= start][-1]
    return draw(t).convert("RGB")


# MARK: Sound

def soundtrack():
    n = int(DURATION * RATE)
    mix = np.zeros(n)
    rng = np.random.default_rng(8)

    def add(start, sig, gain):
        i = int(start * RATE)
        sig = sig[: max(0, n - i)]
        mix[i:i + len(sig)] += sig * gain

    def key(start):
        click = rng.standard_normal(int(0.02 * RATE)) * np.exp(-np.linspace(0, 9, int(0.02 * RATE)))
        add(start, click, 0.18)

    def tone(start, f, dur, gain, decay=3.0):
        tt = np.arange(int(dur * RATE)) / RATE
        add(start, (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)) * np.exp(-tt * decay), gain)

    def thud(start, gain=0.5):
        tt = np.arange(int(0.4 * RATE)) / RATE
        add(start, np.sin(2 * np.pi * (80 * tt - 40 * tt ** 2)) * np.exp(-tt * 10), gain)

    for i in range(4):
        for j in range(3):
            key(i * 0.5 + j * 0.06)
    tone(REC, 880, 0.25, 0.08, 12)
    tone(REC + 1.0, 880, 0.25, 0.08, 12)
    thud(PURPOSE, 0.3)
    for i in range(4):
        key(PAPER + 0.1 + i * 0.5)
    noise = np.convolve(rng.standard_normal(int(0.3 * RATE)), np.ones(12) / 12, mode="same")
    add(PAPER + 1.9, noise * np.sin(np.linspace(0, np.pi, len(noise))), 0.12)
    thud(CLOSE + 0.1)
    thud(WIDE + 0.3, 0.35)
    for start in (ACCIDENT, CHOICE):
        tone(start, 523.3, 1.0, 0.05, 2.5)
    # A low, slow piano-like chord under "Chase your purpose", resolving on Paus.
    for f in (110.0, 164.8, 220.0, 261.6):
        tone(CHASE, f, 2.2, 0.06, 1.2)
    for f in (130.8, 196.0, 261.6, 329.6, 392.0):
        tone(PAUS + 0.2, f, 2.8, 0.045, 0.9)
    return mix


def render(path):
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
            ffmpeg.stdin.write(frame(i / FPS).tobytes())
        ffmpeg.stdin.close()
        if ffmpeg.wait() != 0:
            raise SystemExit("ffmpeg failed")
    print(path)


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--stills":
        out = sys.argv[3] if len(sys.argv) > 3 else "."
        for t in sys.argv[2].split(","):
            frame(float(t)).save(os.path.join(out, f"p-{t}.png"))
        return
    render(os.path.join(OUT, "ads", "en", "real-life", "purpose-1080x1920.mp4"))


if __name__ == "__main__":
    main()
