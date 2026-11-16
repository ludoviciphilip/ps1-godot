## Texture palettes: reduce a texture to N colors (k-means), like PS1 CLUT textures
## (4-bit = 16 colors, 8-bit = 256). Do it once (editor tool or at load), not per frame.
##   var tex16 := PS1Palette.quantize(my_texture, 16)
class_name PS1Palette

const BAYER := [0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0]
const LUMA := Vector3(0.299, 0.587, 0.114)

## Returns a new texture with at most `colors` colors. dither (0..1) adds ordered dithering.
static func quantize(tex: Texture2D, colors := 16, dither := 0.0, iterations := 8) -> ImageTexture:
	# get_image() may share data with the source texture: always work on a copy.
	var img := tex.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	apply_palette(img, palette(img, colors, iterations), dither)
	return ImageTexture.create_from_image(img)

## K-means palette of an image (ignores transparent pixels).
static func palette(img: Image, colors := 16, iterations := 8) -> PackedColorArray:
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, int(sqrt(w * h / 4096.0)))
	var samples: Array[Vector3] = []
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				samples.append(Vector3(c.r, c.g, c.b))
	if samples.is_empty():
		return PackedColorArray([Color.BLACK])
	samples.sort_custom(func(a: Vector3, b: Vector3): return a.dot(LUMA) < b.dot(LUMA))
	var n := mini(colors, samples.size())
	var centers: Array[Vector3] = []
	for k in n:
		centers.append(samples[int((k + 0.5) / n * samples.size())])
	for _i in iterations:
		var sums: Array[Vector3] = []
		var counts := PackedInt32Array()
		sums.resize(n)
		counts.resize(n)
		for k in n:
			sums[k] = Vector3.ZERO
		for a in samples:
			var k := _nearest(centers, a)
			sums[k] += a
			counts[k] += 1
		for k in n:
			if counts[k] > 0:
				centers[k] = sums[k] / counts[k]
	var pal := PackedColorArray()
	for c in centers:
		pal.append(Color(c.x, c.y, c.z))
	return pal

## Maps every pixel of img (in place) to the nearest palette color, keeping alpha.
static func apply_palette(img: Image, pal: PackedColorArray, dither := 0.0) -> void:
	var centers: Array[Vector3] = []
	for c in pal:
		centers.append(Vector3(c.r, c.g, c.b))
	var strength := dither * 0.25
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v := Vector3(c.r, c.g, c.b)
			if strength > 0.0:
				v += Vector3.ONE * ((BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0 - 0.5) * strength
			var p := centers[_nearest(centers, v)]
			img.set_pixel(x, y, Color(p.x, p.y, p.z, c.a))

static func _nearest(centers: Array[Vector3], v: Vector3) -> int:
	var best := 0
	var md := INF
	for k in centers.size():
		var d := centers[k].distance_squared_to(v)
		if d < md:
			md = d
			best = k
	return best
