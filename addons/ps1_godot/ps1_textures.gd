## Procedural 64x64 placeholder textures (until you have hand-painted ones).
class_name PS1Textures

static func _img(size := 64) -> Image:
	return Image.create(size, size, false, Image.FORMAT_RGB8)

static func _noise(seed_: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	return n

static func _quant(c: Color, steps := 6.0) -> Color:
	return Color(floor(c.r * steps) / steps, floor(c.g * steps) / steps, floor(c.b * steps) / steps)

static func stone_bricks() -> ImageTexture:
	var img := _img()
	var n := _noise(3, 0.15)
	for y in 64:
		for x in 64:
			var row := y / 16
			var bx := (x + (8 if row % 2 == 1 else 0)) % 32
			var mortar := (y % 16 < 2) or (bx < 2)
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var c: Color
			if mortar:
				c = Color(0.12, 0.11, 0.10)
			else:
				var tint := 0.9 + 0.2 * (hash(Vector2i(row, (x + (8 if row % 2 == 1 else 0)) / 32)) % 100) / 100.0
				c = Color(0.36, 0.34, 0.30) * (0.6 + 0.5 * v) * tint
			img.set_pixel(x, y, _quant(c, 10.0))
	return ImageTexture.create_from_image(img)

static func ground() -> ImageTexture:
	var img := _img()
	var n := _noise(7, 0.08)
	var n2 := _noise(11, 0.4)
	for y in 64:
		for x in 64:
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var d := 0.5 + 0.5 * n2.get_noise_2d(x, y)
			var mud := Color(0.20, 0.16, 0.11)
			var moss := Color(0.16, 0.22, 0.12)
			var c := mud.lerp(moss, v) * (0.7 + 0.5 * d)
			img.set_pixel(x, y, _quant(c, 12.0))
	return ImageTexture.create_from_image(img)

static func bark() -> ImageTexture:
	var img := _img(32)
	var n := _noise(5, 0.3)
	for y in 32:
		for x in 32:
			var v := 0.5 + 0.5 * n.get_noise_2d(x * 3.0, y * 0.4)
			img.set_pixel(x, y, _quant(Color(0.18, 0.13, 0.10) * (0.5 + 0.7 * v), 10.0))
	return ImageTexture.create_from_image(img)

static func metal() -> ImageTexture:
	var img := _img(32)
	var n := _noise(9, 0.25)
	for y in 32:
		for x in 32:
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var band := 0.15 if (y % 8 == 0) else 0.0
			img.set_pixel(x, y, _quant(Color(0.30, 0.31, 0.34) * (0.6 + 0.5 * v) - Color(band, band, band, 0), 10.0))
	return ImageTexture.create_from_image(img)

static func flat(c: Color) -> ImageTexture:
	var img := _img(4)
	img.fill(c)
	return ImageTexture.create_from_image(img)

static func _img_rgba(size := 64) -> Image:
	return Image.create(size, size, false, Image.FORMAT_RGBA8)

## Wrought-iron fence with transparent gaps (use with mode "cutout").
static func iron_fence() -> ImageTexture:
	var img := _img_rgba()
	img.fill(Color(0, 0, 0, 0))
	var n := _noise(13, 0.3)
	for y in 64:
		for x in 64:
			var bar := x % 16 < 3
			var rail := (y >= 8 and y < 11) or (y >= 52 and y < 55)
			var spike := y < 8 and x % 16 < 3 and absi((x % 16) - 1) <= (y / 3)
			if (bar and y >= 6) or rail or spike:
				var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
				img.set_pixel(x, y, _quant(Color(0.16, 0.15, 0.15) * (0.7 + 0.6 * v), 10.0))
	return ImageTexture.create_from_image(img)

## Grass tuft card (use with mode "cutout" on crossed quads).
static func grass() -> ImageTexture:
	var img := _img_rgba()
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 22:
		var x0 := rng.randf_range(4, 60)
		var hgt := rng.randf_range(24, 60)
		var lean := rng.randf_range(-10, 10)
		var c := Color(0.2, 0.28, 0.12).lerp(Color(0.36, 0.38, 0.16), rng.randf())
		for t in int(hgt):
			var f := t / hgt
			var x := int(x0 + lean * f * f)
			var wdt := int(2.0 * (1.0 - f)) + 1
			for dx in wdt:
				var px := clampi(x + dx, 0, 63)
				img.set_pixel(px, 63 - t, _quant(c * (0.6 + 0.6 * f), 10.0))
	return ImageTexture.create_from_image(img)

## Smooth, colorful texture (many colors): handy to show what PS1Palette does.
static func mossy_rock() -> ImageTexture:
	var img := _img(64)
	var n := _noise(31, 0.06)
	var n2 := _noise(37, 0.25)
	for y in 64:
		for x in 64:
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var d := 0.5 + 0.5 * n2.get_noise_2d(x, y)
			var rock := Color(0.42, 0.40, 0.38).lerp(Color(0.25, 0.27, 0.33), d)
			var moss := Color(0.22, 0.38, 0.14).lerp(Color(0.45, 0.48, 0.18), d)
			img.set_pixel(x, y, rock.lerp(moss, smoothstep(0.45, 0.7, v)) * (0.75 + 0.4 * d))
	return ImageTexture.create_from_image(img)

## 4-frame flame sprite sheet (256x64: 4 frames of 64x64), for PS1Sprite (hframes = 4, unlit).
static func flame_sheet() -> ImageTexture:
	var img := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var n := _noise(41, 0.09)
	for f in 4:
		for y in 64:
			for x in 64:
				var u := (x - 32.0) / 32.0
				var v := 1.0 - y / 63.0   # 0 = bottom, 1 = top
				var wob := n.get_noise_3d(x * 1.0, y * 1.6 + f * 22.0, f * 7.0) * 0.45
				var width := (1.0 - v) * 0.85 + 0.08
				var d := absf(u + wob * v) / width
				var heat := (1.0 - d) * (1.0 - v * 0.75) + 0.2 * n.get_noise_2d(x + f * 30, y)
				if d < 1.0 and heat > 0.15:
					var c := Color(0.85, 0.2, 0.05).lerp(Color(1.0, 0.65, 0.15), smoothstep(0.2, 0.6, heat))
					c = c.lerp(Color(1.0, 0.95, 0.7), smoothstep(0.65, 0.95, heat))
					img.set_pixel(f * 64 + x, y, _quant(c, 8.0))
	return ImageTexture.create_from_image(img)

## Dark pine silhouette for distant sprite trees (64x128, alpha).
static func pine() -> ImageTexture:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var n := _noise(43, 0.25)
	for y in 128:
		for x in 64:
			var v := 1.0 - y / 127.0
			var u := absf(x - 32.0) / 32.0
			var tier := fmod(v * 5.0, 1.0)
			var width := (1.0 - v) * (0.55 + 0.45 * (1.0 - tier)) + 0.02
			var trunk := v < 0.12 and u < 0.08
			if (u < width and v > 0.1) or trunk:
				var k := 0.5 + 0.5 * n.get_noise_2d(x, y)
				var c := Color(0.2, 0.14, 0.1) if trunk else Color(0.07, 0.13, 0.09) * (0.7 + 0.6 * k)
				img.set_pixel(x, y, _quant(c, 10.0))
	return ImageTexture.create_from_image(img)

## Cut ashlar blocks in cool grey stone (gothic walls, towers). Larger, cleaner blocks than
## stone_bricks(), with a few darker, weathered ones.
static func ashlar() -> ImageTexture:
	var img := _img()
	var n := _noise(31, 0.12)
	var n2 := _noise(37, 0.5)
	for y in 64:
		for x in 64:
			var row := y / 21
			var off := 11 if row % 2 == 1 else 0
			var bx := (x + off) % 32
			var by := y % 21
			var mortar := by < 1 or bx < 1 or y >= 63
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var g := 0.5 + 0.5 * n2.get_noise_2d(x, y)
			var c: Color
			if mortar:
				c = Color(0.08, 0.08, 0.09)
			else:
				var block := hash(Vector2i(row, (x + off) / 32)) % 100
				var tint := 0.82 + 0.3 * block / 100.0
				c = Color(0.36, 0.37, 0.40) * (0.65 + 0.45 * v) * tint * (0.9 + 0.2 * g)
				if by == 1 or bx == 1:
					c *= 1.25   # bevel catches the light
			img.set_pixel(x, y, _quant(c, 12.0))
	return ImageTexture.create_from_image(img)

## Worn flagstone paving (courtyards, cathedral floors): irregular slabs with mossy cracks.
static func flagstones() -> ImageTexture:
	var img := _img()
	var n := _noise(41, 0.1)
	var moss := _noise(43, 0.07)
	for y in 64:
		for x in 64:
			var row := y / 16
			var off := (row * 13) % 32
			var w := 32 if row % 2 == 0 else 21
			var bx := (x + off) % w
			var crack := (y % 16 < 1) or (bx < 1)
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var m := 0.5 + 0.5 * moss.get_noise_2d(x, y)
			var c: Color
			if crack:
				c = Color(0.07, 0.08, 0.06).lerp(Color(0.10, 0.14, 0.07), m)
			else:
				var slab := hash(Vector2i(row, (x + off) / w)) % 100
				c = Color(0.30, 0.30, 0.31) * (0.6 + 0.5 * v) * (0.85 + 0.3 * slab / 100.0)
				if m > 0.72:
					c = c.lerp(Color(0.16, 0.19, 0.11), (m - 0.72) * 2.5)
			img.set_pixel(x, y, _quant(c, 12.0))
	return ImageTexture.create_from_image(img)

## Dark slate roof tiles (spires, roofs). Rows of rounded scales.
static func slate_roof() -> ImageTexture:
	var img := _img()
	var n := _noise(53, 0.2)
	for y in 64:
		for x in 64:
			var row := y / 8
			var off := 4 if row % 2 == 1 else 0
			var bx := (x + off) % 8
			var by := y % 8
			var edge := by == 7 or (bx == 0 and by > 2)
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var c := Color(0.16, 0.17, 0.21) * (0.7 + 0.5 * v) * (0.75 + 0.06 * by)
			if edge:
				c = Color(0.05, 0.05, 0.07)
			img.set_pixel(x, y, _quant(c, 12.0))
	return ImageTexture.create_from_image(img)

## Tattered heraldic banner with an emblem (mode "cutout"; map the full 0..1 UV on a quad).
static func banner(cloth := Color(0.35, 0.05, 0.06), trim := Color(0.55, 0.42, 0.2), seed_ := 3) -> ImageTexture:
	var img := _img_rgba()
	img.fill(Color(0, 0, 0, 0))
	var n := _noise(seed_, 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var cuts := []
	for i in 8:
		cuts.append(rng.randi_range(44, 63))
	for x in 64:
		var bottom: int = cuts[x / 8] - absi(x % 8 - 4)   # ragged, torn hem
		for y in bottom:
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var c := cloth * (0.65 + 0.5 * v)
			if x < 3 or x > 60 or (y > 3 and y < 6):
				c = trim * (0.7 + 0.4 * v)
			# emblem: a downward sword inside a ring
			var d := Vector2(x - 32, y - 26).length()
			if (d > 10.0 and d < 12.5) or (absi(x - 32) <= 1 and y > 12 and y < 44) or (absi(y - 20) <= 1 and absi(x - 32) < 7):
				c = trim * (0.8 + 0.3 * v)
			if y < 2:
				c = Color(0.1, 0.09, 0.08)   # rod
			img.set_pixel(x, y, _quant(Color(c.r, c.g, c.b), 12.0))
			img.set_pixel(x, y, Color(img.get_pixel(x, y), 1.0))
	return ImageTexture.create_from_image(img)

## Matted fur (rats, wolves): streaky strands in a dark base color.
static func fur(base := Color(0.25, 0.21, 0.18), seed_ := 61) -> ImageTexture:
	var img := _img()
	var n := _noise(seed_, 0.06)
	var streak := _noise(seed_ + 1, 0.9)
	for y in 64:
		for x in 64:
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var st := 0.5 + 0.5 * streak.get_noise_2d(x * 0.25, y * 2.0)
			var c := base * (0.55 + 0.45 * v + 0.35 * (st - 0.5))
			if st > 0.82:
				c = c * 0.55   # clumps
			img.set_pixel(x, y, _quant(c, 12.0))
	return ImageTexture.create_from_image(img)

## Pale, sickly skin with veins and blotches (undead, grotesque creatures).
static func skin(base := Color(0.62, 0.56, 0.5), seed_ := 71) -> ImageTexture:
	var img := _img()
	var n := _noise(seed_, 0.08)
	var veins := _noise(seed_ + 3, 0.18)
	veins.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	for y in 64:
		for x in 64:
			var v := 0.5 + 0.5 * n.get_noise_2d(x, y)
			var r := 0.5 + 0.5 * veins.get_noise_2d(x, y)
			var c := base * (0.75 + 0.35 * v)
			if r > 0.86:
				c = c.lerp(Color(0.35, 0.22, 0.3), 0.6)
			if v < 0.22:
				c = c.lerp(Color(0.3, 0.32, 0.2), 0.5)   # rot
			img.set_pixel(x, y, _quant(c, 12.0))
	return ImageTexture.create_from_image(img)
