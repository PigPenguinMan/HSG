#!/usr/bin/env python3
"""Generate 2.5-head chibi pixel art sprites for enemies (enemy_feral.png, enemy_rare.png, boss_brun.png)."""

from pathlib import Path
from PIL import Image

PALETTE = {
	".": (0, 0, 0, 0),           # transparent
	"O": (27, 22, 35, 255),      # dark 1px outline / nose
	"S": (18, 14, 24, 95),       # ground shadow
	"C": (235, 220, 198, 255),   # cream face / muzzle
	"c": (212, 194, 170, 255),   # cream shadow
	"P": (198, 108, 118, 255),   # ear inner pink
	"F": (48, 38, 56, 255),      # dark boots / paws
	"W": (245, 242, 232, 255),   # bone / tusk / fang white
	"H": (122, 78, 52, 255),     # wood handle / leather

	# Feral hound colors (rust-crimson feral beastfolk)
	"R": (162, 62, 58, 255),     # feral rust red fur
	"r": (122, 42, 42, 255),     # feral dark fur
	"Y": (250, 208, 68, 255),    # feral glowing yellow eyes
	"T": (88, 58, 48, 255),      # ragged tunic
	"t": (64, 42, 36, 255),      # ragged tunic shadow
	"M": (176, 184, 198, 255),   # iron blade / claw

	# Rare champion colors (golden-mane blood-eyed alpha)
	"G": (214, 158, 54, 255),    # golden ochre fur
	"g": (168, 118, 36, 255),    # golden fur shadow
	"E": (236, 48, 58, 255),     # crimson glowing eyes
	"K": (248, 214, 84, 255),    # bright gold crown / pauldrons
	"k": (196, 152, 44, 255),    # gold shadow
	"A": (92, 46, 58, 255),      # dark crimson-iron plate
	"a": (64, 30, 42, 255),      # dark plate shadow

	# Boss Ironhide Brun colors (corrupted giant bear chieftain)
	"B": (98, 76, 72, 255),      # dark grizzly brown-grey fur
	"b": (72, 54, 52, 255),      # dark fur shadow
	"I": (126, 132, 148, 255),   # ironhide armour
	"i": (88, 94, 110, 255),     # ironhide armour shadow
	"X": (210, 42, 52, 255),     # bloodmoon corruption core / axe edge
	"x": (148, 26, 36, 255),     # corruption dark crimson
}

# 32x32 Frame 0 — Feral Hound (enemy_feral.png)
FERAL_0 = [
	"................................",
	"................................",
	"................................",
	"..........OO.......OO...........",
	".........ORRO.....ORRO..........",
	".........ORPRO...ORPRO..........",
	"........ORRPROOOORRPRO..........",
	"........ORRRRRRRRRRRRRO.........",
	".......ORRRRRRRRRRRRRRRO........",
	".......ORRRRRRRRRRRRRRRO........",
	"......ORRRRRRCRRRRCCRRRRO.......",
	"......ORRRCCCCCCCCCCRRRRO.......",
	"......ORRCCYCCCCCCYCCRRRO.......",
	".......ORCCYCCCCCCYCCROO........",
	"........ORCCCCCOCCCCCOO.........",
	"........OORCWCCCCWCCRO..........",
	".........OOTTTTTTTTTTO..........",
	".......OOHHTTTTTTTTTtO..........",
	"......OHHOOTTTTTTTTTtOMMO.......",
	"....OO.OO.OTTTTTTTTTtOMMMO......",
	"...ORRO...OTTTTTTTTTtOOMMO......",
	"..ORRRRO..OttttttttttO.OO.......",
	"..ORRrrOOO.OOFFOOFFOO...........",
	"...OrrrO....OFFOOFFO............",
	"....OOO....SSSSSSSSSS...........",
	"..........SSSSSSSSSSSS..........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

# 32x32 Frame 1 — Feral Hound (1px lower body + alternating feet)
FERAL_1 = [
	"................................",
	"................................",
	"................................",
	"................................",
	"..........OO.......OO...........",
	".........ORRO.....ORRO..........",
	".........ORPRO...ORPRO..........",
	"........ORRPROOOORRPRO..........",
	"........ORRRRRRRRRRRRRO.........",
	".......ORRRRRRRRRRRRRRRO........",
	".......ORRRRRRRRRRRRRRRO........",
	"......ORRRRRRCRRRRCCRRRRO.......",
	"......ORRRCCCCCCCCCCRRRRO.......",
	"......ORRCCYCCCCCCYCCRRRO.......",
	".......ORCCYCCCCCCYCCROO........",
	"........ORCCCCCOCCCCCOO.........",
	"........OORCWCCCCWCCRO..........",
	".........OOTTTTTTTTTTO..........",
	".......OOHHTTTTTTTTTtO..........",
	"......OHHOOTTTTTTTTTtOMMO.......",
	"....OO.OO.OTTTTTTTTTtOMMMO......",
	"...ORRO...OTTTTTTTTTtOOMMO......",
	"..ORRRRO..OttttttttttO.OO.......",
	"..ORRrrOO..OFFOOOOOFFO..........",
	"...OrrrO...SSSSSSSSSS...........",
	"....OOO...SSSSSSSSSSSS..........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

# 32x32 Frame 0 — Rare Champion (enemy_rare.png)
RARE_0 = [
	"................................",
	"................................",
	"..........O...OOO...O...........",
	".........OKO.OKKKO.OKO..........",
	".........OGKOOKKKOOKGO..........",
	"........OGGPOKKKKKOPGGO.........",
	"........OGGPOOOOOOOPGGO.........",
	"........OGGGGGGGGGGGGGO.........",
	".......OGGGGGGGGGGGGGGGO........",
	"......OGGGGGGGGGGGGGGGGGO.......",
	"......OGGGGGGCGGGGCCGGGGO.......",
	"......OGGGCCCCCCCCCCGGGGO.......",
	".....OGgGCCECCCCCCECCGGGGO......",
	"......OGGCCECCCCCCECCGGGO.......",
	".......OGGCCCCCOCCCCCCOO........",
	"........OOGCWCCCCWCCGOO.........",
	"......OOKKKRRRRRRRRRKKKOO.......",
	".....OKKKkOAAAAAAAAAOkKKKO......",
	".....OKkOOAAAAAAAAAAAOOKkO......",
	"...OO.OO.OAAAAOKOAAAAOMMMO......",
	"..OKGO...OAAAOKXKOAAAOMMMMO.....",
	".OKGGGO..OAAAAOKOAAAAOMMMO......",
	".OGGGgOOO.OaaaaaaaaaaOOMO.......",
	"..OgggO....OOFFOOFFOO.OO........",
	"...OOO......OFFOOFFO............",
	"...........SSSSSSSSSS...........",
	"..........SSSSSSSSSSSS..........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

# 32x32 Frame 1 — Rare Champion (1px lower body + alternating feet)
RARE_1 = [
	"................................",
	"................................",
	"................................",
	"..........O...OOO...O...........",
	".........OKO.OKKKO.OKO..........",
	".........OGKOOKKKOOKGO..........",
	"........OGGPOKKKKKOPGGO.........",
	"........OGGPOOOOOOOPGGO.........",
	"........OGGGGGGGGGGGGGO.........",
	".......OGGGGGGGGGGGGGGGO........",
	"......OGGGGGGGGGGGGGGGGGO.......",
	"......OGGGGGGCGGGGCCGGGGO.......",
	"......OGGGCCCCCCCCCCGGGGO.......",
	".....OGgGCCECCCCCCECCGGGGO......",
	"......OGGCCECCCCCCECCGGGO.......",
	".......OGGCCCCCOCCCCCCOO........",
	"........OOGCWCCCCWCCGOO.........",
	"......OOKKKRRRRRRRRRKKKOO.......",
	".....OKKKkOAAAAAAAAAOkKKKO......",
	".....OKkOOAAAAAAAAAAAOOKkO......",
	"...OO.OO.OAAAAOKOAAAAOMMMO......",
	"..OKGO...OAAAOKXKOAAAOMMMMO.....",
	".OKGGGO..OAAAAOKOAAAAOMMMO......",
	".OGGGgOOO.OaaaaaaaaaaOOMO.......",
	"..OgggO...OFFOOOOOOFFO.OO.......",
	"...OOO.....SSSSSSSSSS...........",
	"..........SSSSSSSSSSSS..........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]


def _make_boss_frame(dy: int, step_alt: bool) -> list[str]:
	grid = [["." for _ in range(48)] for _ in range(48)]

	def put_row(y: int, x0: int, s: str) -> None:
		if 0 <= y < 48:
			for i, ch in enumerate(s):
				if ch != "." and 0 <= x0 + i < 48:
					grid[y][x0 + i] = ch

	# Ground shadow (stays anchored)
	put_row(42, 11, "SSSSSSSSSSSSSSSSSSSSSSSSSS")
	put_row(43, 9, "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSS")
	put_row(44, 11, "SSSSSSSSSSSSSSSSSSSSSSSSSS")

	# Round Bear Ears + Ivory Horns (y=3..9)
	put_row(3 + dy, 8, ".OOOO..OO.........OO..OOOO.")
	put_row(4 + dy, 8, "OBBBBOOWWO.......OWWOOBBBBO")
	put_row(5 + dy, 8, "OBPPBOOWWOOOOOOOOOWWOOBPPBO")
	put_row(6 + dy, 8, "OBPPBOOWWBBBBBBBBBWWOOBPPBO")
	put_row(7 + dy, 10, "OBBBBBBBBBBBBBBBBBBBBO")
	put_row(8 + dy, 9, "OBBBBBBBBBBBBBBBBBBBBBBO")
	put_row(9 + dy, 8, "OBBIIIIIIIIIIIIIIIIIIIBBBO")
	put_row(10 + dy, 8, "OBBIIiiiiiiiiiiiiiiiiIIBBO")
	put_row(11 + dy, 8, "OBBOOOOOOOOOOOOOOOOOOOOBBO")

	# Bear Chibi Head & Cream Face (y=12..20)
	put_row(12 + dy, 7, "OBBBBCCCCCCCBBBBCCCCCCCBBBBO")
	put_row(13 + dy, 7, "OBBBCCCCCCCCCCCCCCCCCCCCBBBO")
	put_row(14 + dy, 7, "OBbBCCCCEECCCCCCCCEECCCCBBBO")
	put_row(15 + dy, 7, "OBbBCCCCEECCCCCCCCEECCCCBBBO")
	put_row(16 + dy, 8, "OBBCCCCCCCCCOOCCCCCCCCCBBBO")
	put_row(17 + dy, 8, "OBBCCCCCCCCOOOOCCCCCCCCBBBO")
	put_row(18 + dy, 9, "OBBCCCCWCccccccCWCCCCBBBO")
	put_row(19 + dy, 10, "OOBCCCWCCCCCCCCWCCCBOO")
	put_row(20 + dy, 12, "OOCCCCCCCCCCCCCCOO")

	# Crimson Fur Mantle / Scarf + Spiked Iron Pauldrons (y=21..26)
	put_row(19 + dy, 6, "..OO............................OO..")
	put_row(20 + dy, 5, ".OWWOO....OORRRRRRRRRRRRRROO....OOWWO")
	put_row(21 + dy, 5, "OIIIIIO..ORRRRRRRRRRRRRRRRRRO..OIIIIIO")
	put_row(22 + dy, 4, "OIIIIIIIOORRRrRRRRRRRRRRRRrRRROOIIIIIIIO")
	put_row(23 + dy, 4, "OIIIIiiiOOBBBBBBBBBBBBBBBBBBBBOOiiiIIIIO")
	put_row(24 + dy, 4, "OiiiiiiiOOBBIIIIIIIIIIIIIIIIBBOOiiiiiiiO")
	put_row(25 + dy, 5, "OOOOOOOOOBBIIiBBBBBBBBBBiIIBBOOOOOOOOO")

	# Ironhide Chest Armour + Bloodmoon Core (y=26..36)
	put_row(26 + dy, 9, "ObbOBBIIBBBBBBBBBBBBIIBBObbO")
	put_row(27 + dy, 8, "ObbbOBBIIBBBOOXXXXOOBBIIBBObbbO")
	put_row(28 + dy, 8, "ObbbOBBIIBBBOXxxxxXOBBIIBBObbbO")
	put_row(29 + dy, 9, "OOOOBBIIBBBOXxXXxXOBBIIBBOOOO")
	put_row(30 + dy, 12, "OBBIIBBBOXxxxxXOBBIIBBO")
	put_row(31 + dy, 12, "OBBIIBBBOOXXXXOOBBIIBBO")
	put_row(32 + dy, 12, "OBBIIBBBBBBBBBBBBIIBBBO")
	put_row(33 + dy, 12, "OBBIIIIIIIIIIIIIIIIBBBO")
	put_row(34 + dy, 12, "ObbiiiiiiiiiiiiiiiiibbO")
	put_row(35 + dy, 13, "OOOOOOOOOOOOOOOOOOOOO")

	# Giant Blood-Greataxe held on right side (x=35..46, y=10..39)
	put_row(10 + dy, 36, ".OOOOOOOO.")
	put_row(11 + dy, 35, "OIMMMMMMMXO")
	put_row(12 + dy, 35, "OIIIIIIIIXXO")
	put_row(13 + dy, 35, "OIIIIIIIXXXO")
	put_row(14 + dy, 35, "OIIIIIIXXXXO")
	put_row(15 + dy, 35, "OIIIIIIXXXXO")
	put_row(16 + dy, 35, "OIIIIIIXXXXO")
	put_row(17 + dy, 35, "OIIIIIIIXXXO")
	put_row(18 + dy, 35, "OIIIIIIIIXXO")
	put_row(19 + dy, 35, "OiiiiiiiiiXO")
	put_row(20 + dy, 36, "OOOOOOOOOO")
	for ay in range(21 + dy, 39 + dy):
		put_row(ay, 38, "OHHO")
	put_row(39 + dy, 38, "OOOO")

	# Heavy Iron Boots (alternating step)
	if not step_alt:
		for by in range(36 + dy, 41 + dy):
			put_row(by, 14, "OFFFO...OFFFO")
		put_row(41 + dy, 14, "OOOOO...OOOOO")
	else:
		for by in range(36 + dy, 41 + dy):
			put_row(by, 12, "OFFFO.......OFFFO")
		put_row(41 + dy, 12, "OOOOO.......OOOOO")

	return ["".join(r) for r in grid]


def render_strip(frames: list[list[str]], w: int, h: int) -> Image.Image:
	img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
	px = img.load()
	for f_idx, grid in enumerate(frames):
		assert len(grid) == h
		ox = f_idx * w
		for y, row in enumerate(grid):
			assert len(row) == w, f"Row {y} len {len(row)} != {w}"
			for x, ch in enumerate(row):
				px[ox + x, y] = PALETTE[ch]
	return img


def main() -> None:
	root = Path(__file__).resolve().parents[2]
	sprites_dir = root / "assets" / "sprites"

	feral_img = render_strip([FERAL_0, FERAL_1], 32, 32)
	feral_img.save(sprites_dir / "enemy_feral.png", "PNG")

	rare_img = render_strip([RARE_0, RARE_1], 32, 32)
	rare_img.save(sprites_dir / "enemy_rare.png", "PNG")

	boss_0 = _make_boss_frame(0, False)
	boss_1 = _make_boss_frame(1, True)
	boss_img = render_strip([boss_0, boss_1], 48, 48)
	boss_img.save(sprites_dir / "boss_brun.png", "PNG")

	print("Generated enemy_feral.png (64x32), enemy_rare.png (64x32), boss_brun.png (96x48)")


if __name__ == "__main__":
	main()
