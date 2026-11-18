"""Split assets/sprites/wolf_player.png into paper-doll layers (GDD: parts layering).

Outputs (64x32, 2 frames, same anchor as wolf_player.png) in assets/sprites/wolf/:
  base.png            body, head, tail, legs, shadow (fur torso painted where the cloak was)
  outfit_default.png  starter cloak (replaced by body armour layers later)
  scarf.png           signature scarf, always drawn on top of armour
  layers.json         draw order + per-frame weapon hand anchor
Invariant: base + outfit_default + scarf == wolf_player.png (pixel exact; checked in tests).
"""
from PIL import Image
import json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "sprites", "wolf_player.png")
OUT = os.path.join(ROOT, "assets", "sprites", "wolf")

OUTLINE = (27, 22, 35, 255)
FUR = (124, 132, 148, 255)
FUR_DARK = (92, 99, 115, 255)
CREAM = (240, 228, 210, 255)
SCARF = {(204, 53, 61, 255), (153, 34, 43, 255)}
CLOAK = {(67, 43, 84, 255), (47, 28, 61, 255)}
CLOAK_DARK = (47, 28, 61, 255)
SCARF_DARK = (153, 34, 43, 255)
CLEAR = (0, 0, 0, 0)
FW = 32

src = Image.open(SRC).convert("RGBA")
W, H = src.size
px = lambda x, y: src.getpixel((x, y)) if 0 <= x < W and 0 <= y < H else CLEAR
body_colors = lambda c: c[3] == 255 and c != OUTLINE and c not in SCARF and c not in CLOAK

def nbrs(x, y):
	return [px(x + 1, y), px(x - 1, y), px(x, y + 1), px(x, y - 1)]

base = src.copy()
cloak = Image.new("RGBA", (W, H), CLEAR)
scarf = Image.new("RGBA", (W, H), CLEAR)
anchors = []

for f in range(W // FW):
	x0 = f * FW
	# torso columns = columns that hold cloak pixels in this frame
	cloak_cols = sorted({x for x in range(x0, x0 + FW) for y in range(H) if px(x, y) in CLOAK})
	cx0, cx1 = cloak_cols[0], cloak_cols[-1]
	cloak_top = min(y for y in range(H) for x in range(x0, x0 + FW) if px(x, y) in CLOAK)
	mid = (cx0 + cx1) // 2
	for y in range(H):
		for x in range(x0, x0 + FW):
			c = px(x, y)
			if c in CLOAK:
				cloak.putpixel((x, y), c)
				base.putpixel((x, y), FUR_DARK if c == CLOAK_DARK else FUR)
			elif c in SCARF:
				scarf.putpixel((x, y), c)
				if cx0 <= x <= cx1:          # neck under the scarf
					base.putpixel((x, y), FUR_DARK if c == SCARF_DARK else (CREAM if abs(x - mid) <= 2 else FUR))
				else:                         # scarf tail outside the body
					base.putpixel((x, y), CLEAR)
			elif c == OUTLINE:
				n = nbrs(x, y)
				touches_scarf = any(k in SCARF for k in n)
				touches_cloak = any(k in CLOAK for k in n)
				touches_body = any(body_colors(k) for k in n)
				if touches_cloak:
					cloak.putpixel((x, y), c)
				if touches_scarf:
					scarf.putpixel((x, y), c)
					if not touches_body and not touches_cloak:
						base.putpixel((x, y), CLEAR)   # outline that only belongs to the scarf tail
	# cream chest V on the fur torso
	for i, half in enumerate((2, 1, 0)):
		for x in range(mid - half, mid + half + 1):
			if base.getpixel((x, cloak_top + i)) == FUR:
				base.putpixel((x, cloak_top + i), CREAM)
	anchors.append({"frame": f, "hand": [cx1 - x0 + 1, cloak_top + 3]})

os.makedirs(OUT, exist_ok=True)
base.save(os.path.join(OUT, "base.png"))
cloak.save(os.path.join(OUT, "outfit_default.png"))
scarf.save(os.path.join(OUT, "scarf.png"))
meta = {
	"frame_size": [FW, H],
	"frames": W // FW,
	"draw_order": ["base.png", "boots (v0.2)", "outfit_default.png | body armour", "scarf.png", "weapon (v0.2)"],
	"weapon_anchor": anchors,
	"note": "Facing is done by flipping the parent node (player.gd _body_node.scale.x); layers must be children of it.",
}
with open(os.path.join(OUT, "layers.json"), "w") as fh:
	json.dump(meta, fh, indent=2, ensure_ascii=False)
	fh.write("\n")

comp = base.copy()
comp.alpha_composite(cloak)
comp.alpha_composite(scarf)
assert comp.tobytes() == src.tobytes(), "layers do not recompose to wolf_player.png"
print("ok", anchors)
