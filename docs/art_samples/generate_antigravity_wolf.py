#!/usr/bin/env python3
"""Generate docs/art_samples/antigravity_wolf.png (64x32, two 32x32 walk frames)."""

from pathlib import Path
from PIL import Image

PALETTE = {
	".": (0, 0, 0, 0),          # transparent
	"O": (27, 22, 35, 255),     # dark 1px outline & eyes/nose
	"G": (124, 132, 148, 255),  # wolf grey fur
	"g": (92, 99, 115, 255),    # wolf grey fur shadow
	"T": (208, 213, 224, 255),  # tail tip light fur
	"P": (217, 132, 148, 255),  # ear inner pink
	"C": (240, 228, 210, 255),  # cream face
	"c": (222, 206, 184, 255),  # cream face subtle shadow
	"B": (226, 124, 124, 255),  # blush
	"R": (204, 53, 61, 255),    # red scarf
	"r": (153, 34, 43, 255),    # red scarf shadow
	"V": (67, 43, 84, 255),     # dark purple cloak
	"v": (47, 28, 61, 255),     # dark purple cloak shadow
	"F": (52, 44, 62, 255),     # boots / feet
	"S": (18, 14, 24, 95),      # semi-transparent ground shadow
}

# 32x32 Frame 0 (idle)
FRAME_0 = [
	"................................",
	"................................",
	"................................",
	"...........O.......O............",
	"..........OGO.....OGO...........",
	"..........OGPO...OGPO...........",
	".........OGGPO...OGGPO..........",
	".........OGGPOOOOGGGPO..........",
	".........OGGGGGGGGGGGGO.........",
	"........OGGGGGGGGGGGGGGO........",
	"........OGGGGGGGGGGGGGGO........",
	".......OGGGGGCGGGGCCGGGGO.......",
	".......OGGGCCCCCCCCCGGGGO.......",
	"......OGgGCCCOCcCCCOCCCGGO......".replace("OcC", "OCC"),
	".......OGGCCCOCcCCCOCCCCOO......".replace("OcC", "OCC"),
	"........OGGCBCCCCCCBCCCCO.......",
	".........OGCCCCCCCCCCCCO........",
	"..........OOCCCCCCCCcOO.........",
	".........OORRRRRRRRRRO..........",
	".......OORRrRRRRRRRRrO..........",
	"......ORrOOVVVVVVVVVVO..........",
	"....OO.OOOVVVVVVVVVVVO..........",
	"...OTGO..OVVVVVVVVVVvO..........",
	"..OTGGGO.OVVVVVVVVVVvO..........",
	"..OGGGgOOOVVVVVVVVVvvO..........",
	"...OggGGOOvvvvvvvvvvvO..........",
	"....OOOO..OOFFOOFFOO............",
	"...........OFFOOFFO.............",
	"..........SSSSSSSSSS............",
	".........SSSSSSSSSSSS...........",
	"................................",
	"................................",
]

# 32x32 Frame 1 (walk: body 1px down + alternating feet)
FRAME_1 = [
	"................................",
	"................................",
	"................................",
	"................................",
	"...........O.......O............",
	"..........OGO.....OGO...........",
	"..........OGPO...OGPO...........",
	".........OGGPO...OGGPO..........",
	".........OGGPOOOOGGGPO..........",
	".........OGGGGGGGGGGGGO.........",
	"........OGGGGGGGGGGGGGGO........",
	"........OGGGGGGGGGGGGGGO........",
	".......OGGGGGCGGGGCCGGGGO.......",
	".......OGGGCCCCCCCCCGGGGO.......",
	"......OGgGCCCOCcCCCOCCCGGO......".replace("OcC", "OCC"),
	".......OGGCCCOCcCCCOCCCCOO......".replace("OcC", "OCC"),
	"........OGGCBCCCCCCBCCCCO.......",
	".........OGCCCCCCCCCCCCO........",
	"..........OOCCCCCCCCcOO.........",
	".........OORRRRRRRRRRO..........",
	".......OORRrRRRRRRRRrO..........",
	"......ORrOOVVVVVVVVVVO..........",
	"....OO.OOOVVVVVVVVVVVO..........",
	"...OTGO..OVVVVVVVVVVvO..........",
	"..OTGGGO.OVVVVVVVVVVvO..........",
	"..OGGGgOOOVVVVVVVVVvvO..........",
	"...OggGGOOvvvvvvvvvvvO..........",
	"....OOOO.OFFOOOOOOFFO...........",
	"..........SSSSSSSSSS............",
	".........SSSSSSSSSSSS...........",
	"................................",
	"................................",
]


def render_frames(frames: list[list[str]]) -> Image.Image:
	assert len(frames) == 2
	for idx, f in enumerate(frames):
		assert len(f) == 32, f"Frame {idx} height {len(f)} != 32"
		for y, row in enumerate(f):
			assert len(row) == 32, f"Frame {idx} row {y} width {len(row)} != 32"

	img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
	px = img.load()
	for frame_idx, grid in enumerate(frames):
		ox = frame_idx * 32
		for y, row in enumerate(grid):
			for x, ch in enumerate(row):
				px[ox + x, y] = PALETTE[ch]
	return img


def main() -> None:
	out_dir = Path(__file__).resolve().parent
	out_path = out_dir / "antigravity_wolf.png"
	img = render_frames([FRAME_0, FRAME_1])
	img.save(out_path, "PNG")
	print(f"Saved {out_path} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
	main()
