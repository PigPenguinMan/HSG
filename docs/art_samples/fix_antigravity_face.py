"""Repaint only the face of antigravity_wolf.png (symmetric around x=16) -> antigravity_wolf_face_v2.png."""
from PIL import Image
import os
HERE = os.path.dirname(os.path.abspath(__file__))
src = Image.open(os.path.join(HERE, "antigravity_wolf.png")).convert("RGBA")
A = (27, 22, 35, 255)      # outline / eyes / nose
B = (124, 132, 148, 255)   # fur
D = (240, 228, 210, 255)   # cream face
G = (226, 124, 124, 255)   # blush
# Face rows for frame 1 (frame 2 is the same, 1px lower). x ranges are inclusive.
FACE = {
	11: [(8, 23, B)],
	12: [(8, 10, B), (11, 14, D), (15, 17, B), (18, 21, D), (22, 23, B)],   # husky widow's peak
	13: [(9, 9, B), (10, 22, D), (13, 13, A), (19, 19, A), (23, 24, B)],    # eyes
	14: [(8, 9, B), (10, 22, D), (13, 13, A), (19, 19, A), (23, 23, B)],
	15: [(9, 10, B), (11, 21, D), (12, 12, G), (20, 20, G), (22, 23, B)],   # blush, mirrored
	16: [(10, 10, B), (11, 21, D), (16, 16, A), (22, 22, B)],               # small nose
	17: [(12, 20, D)],
}
out = src.copy()
for fx, dy in ((0, 0), (32, 1)):
	for y, spans in FACE.items():
		for x0, x1, col in spans:
			for x in range(x0, x1 + 1):
				out.putpixel((fx + x, y + dy), col)
out.save(os.path.join(HERE, "antigravity_wolf_face_v2.png"))
