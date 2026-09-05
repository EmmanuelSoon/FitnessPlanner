"""Generates the PlateUp app icon (ascending plates) into assets/.

Self-contained: the mark is drawn from primitives, so this can be re-run by
anyone without external source images.

    uv run --with Pillow python assets/make_icons.py

Then regenerate the platform assets:

    dart run flutter_launcher_icons

Outputs:
  assets/icon.png     1024x1024, mark on the ground colour (legacy/iOS icon)
  assets/icon_fg.png  1024x1024, transparent, mark only (adaptive foreground)

Four bars rising left to right, each a step brighter than the last, so the
mark reads as progression rather than as a static object.

MARK_W_FG is smaller than MARK_W_SQ on purpose. Android adaptive icons are
masked to an arbitrary shape and only a centre circle of ~66% diameter is
guaranteed visible. The tallest bar's top corner is the furthest point from
centre, so the foreground is scaled until that corner sits inside that circle.
"""

from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).parent
SIZE = 1024
SS = 4  # supersample factor, for clean anti-aliased edges
W = SIZE * SS

GROUND = (16, 18, 22)  # #101216
RAMP = [               # muted -> vivid, shortest bar to tallest
    (120, 84, 46),     # #78542E
    (190, 124, 44),    # #BE7C2C
    (240, 168, 44),    # #F0A82C
    (255, 205, 80),    # #FFCD50
]

MARK_W_SQ = 0.62  # mark width as a fraction of the square icon
MARK_W_FG = 0.50  # smaller, to stay inside the adaptive-icon safe circle

# Bar layout, as fractions of the mark's own width.
BAR_W = 0.190
GAP = 0.080
BAR_H = [0.331, 0.513, 0.695, 0.877]
MARK_ASPECT = BAR_H[-1]  # mark height / mark width


def draw_mark(d: ImageDraw.ImageDraw, canvas: int, width_frac: float) -> None:
    mw = canvas * width_frac
    mh = mw * MARK_ASPECT
    left = (canvas - mw) / 2
    base = (canvas + mh) / 2  # baseline, so the mark is vertically centred

    bw, gap = mw * BAR_W, mw * GAP
    for i, hf in enumerate(BAR_H):
        x = left + i * (bw + gap)
        h = mw * hf
        d.rounded_rectangle(
            [x, base - h, x + bw, base], radius=bw / 2, fill=RAMP[i]
        )


def render(background, width_frac: float, path: Path) -> None:
    im = Image.new("RGBA", (W, W), background)
    draw_mark(ImageDraw.Draw(im), W, width_frac)
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    if background[3] == 255:
        im.convert("RGB").save(path)
    else:
        im.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    render(GROUND + (255,), MARK_W_SQ, OUT / "icon.png")
    render((0, 0, 0, 0), MARK_W_FG, OUT / "icon_fg.png")
