## Texturas procedurais 64x64 (placeholder até termos as texturas pintadas à mão).
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
