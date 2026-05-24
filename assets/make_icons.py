from PIL import Image

SRC   = r'c:\Users\emman\Desktop\Plates _ bare _ light.png'
FG    = r'D:\Git Repos\fitnessPlanner\FitnessPlanner\assets\icon_fg.png'
ICON  = r'D:\Git Repos\fitnessPlanner\FitnessPlanner\assets\icon.png'
SIZE  = 1024
MINT  = (230, 237, 231, 255)   # #E6EDE7

# Plate bounds (all 3 plates, no label)
PLATE_TOP, PLATE_BOT   = 174, 438   # top=first plate top, bot=last plate bottom
PLATE_LEFT, PLATE_RIGHT = 153, 530
BUFFER = 8  # small buffer so we don't clip anti-aliased edges

# 1. Crop just the plates (tight, no label)
src = Image.open(SRC).convert('RGBA')
region = src.crop((
    PLATE_LEFT  - BUFFER,
    PLATE_TOP   - BUFFER,
    PLATE_RIGHT + BUFFER,
    PLATE_BOT   + BUFFER,
))

# 2. Scale plates so they fill ~58% of the output width
target_w = int(SIZE * 0.58)
pw, ph = region.size
scale = target_w / pw
target_h = int(ph * scale)
region = region.resize((target_w, target_h), Image.LANCZOS)

# 3. Remove white pixels -> transparent
px = region.load()
TOL = 8   # tight — plates have near-white edges; only remove true white background
for y in range(target_h):
    for x in range(target_w):
        r, g, b, a = px[x, y]
        if abs(r-255) <= TOL and abs(g-255) <= TOL and abs(b-255) <= TOL:
            px[x, y] = (0, 0, 0, 0)

# 4. Paste centered on a transparent canvas -> icon_fg.png
fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
ox = (SIZE - target_w) // 2
oy = (SIZE - target_h) // 2
fg.paste(region, (ox, oy), region)
fg.save(FG)
print(f'Saved {FG}  (plates {target_w}x{target_h} at {ox},{oy})')

# 5. Composite over mint background -> icon.png
bg = Image.new('RGBA', (SIZE, SIZE), MINT)
bg.alpha_composite(fg)
bg.convert('RGB').save(ICON)
print(f'Saved {ICON}')
