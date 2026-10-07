extends RefCounted
## Code art for the reef's friendly species — one implementation shared by the
## swimming creature (scenes/levels/friendly_creature.gd) and the guidebook
## portrait, so the book always shows the animal the player actually met.
##
## Same convention as every other art file here: no textures, no atlases, only
## primitives drawn from data in systems/species_db.gd. `t` is the animation
## clock; the book passes 0.0 for a still pose.
##
## ReefArt.draw_creature(self, shape, centre, radius, tint, accent, t, facing)

const BODY_SEGMENTS := 24


## Draws one helper species centred on `centre`. `radius` is the body half-width
## before the species' own size scale (the caller applies SpeciesDB size).
static func draw_creature(ci: CanvasItem, shape: String, centre: Vector2, radius: float,
		tint: Color, accent: Color, t: float, facing: float = 0.0) -> void:
	match shape:
		"wrasse":
			_draw_wrasse(ci, centre, radius, tint, accent, t, facing)
		"crab":
			_draw_crab(ci, centre, radius, tint, accent, t, facing)
		_:
			_draw_parrotfish(ci, centre, radius, tint, accent, t, facing)


## Soft shadow so a helper still reads as a body rather than a decal on sand.
static func draw_shadow(ci: CanvasItem, centre: Vector2, radius: float) -> void:
	ci.draw_set_transform(centre + Vector2(1.5, radius * 0.62), 0.0, Vector2(1.0, 0.40))
	ci.draw_circle(Vector2.ZERO, radius * 1.05, Color(0.02, 0.08, 0.06, 0.22))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Reef Parrotfish: a blunt grazer — chunky oval body, fused beak, fan tail.
## It noses down into the coral as it works, so the body tilts with the clock.
static func _draw_parrotfish(ci: CanvasItem, c: Vector2, r: float, tint: Color,
		accent: Color, t: float, facing: float) -> void:
	var tilt := facing + sin(t * 1.1) * 0.16
	ci.draw_set_transform(c, tilt, Vector2.ONE)
	var sway := sin(t * 3.4)
	# tail
	var tail := PackedVector2Array([
		Vector2(-r * 1.15, 0.0),
		Vector2(-r * 1.95, -r * 0.62 + sway * r * 0.22),
		Vector2(-r * 2.30, -r * 0.18 + sway * r * 0.30),
		Vector2(-r * 2.30, r * 0.18 + sway * r * 0.30),
		Vector2(-r * 1.95, r * 0.62 + sway * r * 0.22),
	])
	ci.draw_colored_polygon(tail, Color(tint.darkened(0.18), 0.95))
	ci.draw_polyline(_ring(tail), Color(accent, 0.55), 1.4, true)
	# body
	ci.draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(r * 1.35, r * 0.90)), tint)
	ci.draw_polyline(_ring(_ellipse(Vector2.ZERO, Vector2(r * 1.35, r * 0.90))),
			Color(tint.darkened(0.35), 1.0), 1.8, true)
	# scale rows
	for i in range(3):
		var f := 0.34 + float(i) * 0.24
		ci.draw_arc(Vector2(-r * 0.22, 0.0), r * f, -PI * 0.42, PI * 0.42, 10,
				Color(accent, 0.30), 1.2, true)
	ci.draw_colored_polygon(_ellipse(Vector2(0.0, r * 0.30), Vector2(r * 1.00, r * 0.34)),
			Color(accent, 0.35))
	# pectoral fin, beating
	var fin := sin(t * 4.2) * 0.30
	var pectoral := PackedVector2Array([
		Vector2(r * 0.30, r * 0.10),
		Vector2(r * 0.95, r * (0.55 + fin)),
		Vector2(r * 0.20, r * 0.70),
	])
	ci.draw_colored_polygon(pectoral, Color(accent, 0.60))
	# beak: the beak is the tool, so it gets the accent colour
	var beak := PackedVector2Array([
		Vector2(r * 1.20, -r * 0.42),
		Vector2(r * 1.95, -r * 0.14),
		Vector2(r * 1.95, r * 0.16),
		Vector2(r * 1.16, r * 0.46),
	])
	ci.draw_colored_polygon(beak, accent)
	ci.draw_polyline(_ring(beak), Color(accent.darkened(0.35), 1.0), 1.6, true)
	# eye + gill line
	ci.draw_circle(Vector2(r * 0.72, -r * 0.30), r * 0.19, Color(0.10, 0.12, 0.14))
	ci.draw_circle(Vector2(r * 0.76, -r * 0.34), r * 0.07, Color(1, 1, 1, 0.9))
	ci.draw_arc(Vector2(r * 0.42, 0.0), r * 0.72, -PI * 0.30, PI * 0.30, 10,
			Color(tint.darkened(0.45), 1.0), 1.6, true)
	# dorsal ridge
	ci.draw_polyline(PackedVector2Array([
		Vector2(-r * 0.95, -r * 0.62), Vector2(-r * 0.30, -r * 0.95),
		Vector2(r * 0.45, -r * 0.72)]), Color(accent, 0.75), 2.2, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Cleaner Wrasse: long slim body, one pale racing stripe, tiny fins.
static func _draw_wrasse(ci: CanvasItem, c: Vector2, r: float, tint: Color,
		accent: Color, t: float, facing: float) -> void:
	var wiggle := sin(t * 4.6) * 0.10
	ci.draw_set_transform(c, facing + wiggle, Vector2.ONE)
	var sway := sin(t * 5.2)
	var tail := PackedVector2Array([
		Vector2(-r * 1.40, 0.0),
		Vector2(-r * 2.10, -r * 0.48 + sway * r * 0.26),
		Vector2(-r * 2.10, r * 0.48 + sway * r * 0.26),
	])
	ci.draw_colored_polygon(tail, Color(accent, 0.85))
	# body: a long spindle
	var body := _ellipse(Vector2(-r * 0.15, 0.0), Vector2(r * 1.65, r * 0.52))
	ci.draw_colored_polygon(body, tint)
	ci.draw_polyline(_ring(body), Color(tint.darkened(0.38), 1.0), 1.6, true)
	# racing stripe
	ci.draw_polyline(PackedVector2Array([
		Vector2(-r * 1.55, 0.0), Vector2(0.0, -r * 0.06), Vector2(r * 1.30, -r * 0.10),
	]), Color(accent, 0.95), r * 0.22, true)
	# dorsal + anal fins
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.80, -r * 0.44), Vector2(-r * 0.10, -r * 0.86), Vector2(r * 0.70, -r * 0.40),
	]), Color(accent, 0.55))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.70, r * 0.40), Vector2(-r * 0.05, r * 0.74), Vector2(r * 0.60, r * 0.36),
	]), Color(accent, 0.40))
	# blunt nose + eye
	ci.draw_circle(Vector2(r * 1.52, -r * 0.02), r * 0.18, Color(tint.darkened(0.25), 1.0))
	ci.draw_circle(Vector2(r * 0.82, -r * 0.14), r * 0.14, Color(0.08, 0.10, 0.14))
	ci.draw_circle(Vector2(r * 0.86, -r * 0.18), r * 0.05, Color(1, 1, 1, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Gardener Crab: broad shell, two working claws, six legs. Slower and stockier
## than the fish — it walks the sand rather than swimming.
static func _draw_crab(ci: CanvasItem, c: Vector2, r: float, tint: Color,
		accent: Color, t: float, facing: float) -> void:
	ci.draw_set_transform(c, facing, Vector2.ONE)
	# legs, each on its own phase so the walk reads even at a low frame rate
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		for j in range(3):
			var base := Vector2(side * r * (0.42 + float(j) * 0.24), r * (0.30 + float(j) * 0.10))
			var step := sin(t * 6.0 + float(j) * 1.7 + (0.0 if i == 0 else PI)) * r * 0.16
			var knee := base + Vector2(side * r * 0.55, r * 0.30 + step)
			var foot := knee + Vector2(side * r * 0.30, r * 0.26 + step)
			ci.draw_line(base, knee, Color(tint.darkened(0.45), 1.0), 2.4, true)
			ci.draw_line(knee, foot, Color(tint.darkened(0.55), 1.0), 2.0, true)
	# carapace: a wide domed shell with a pale rim
	var shell := _ellipse(Vector2.ZERO, Vector2(r * 1.15, r * 0.82))
	ci.draw_colored_polygon(shell, tint)
	ci.draw_colored_polygon(_ellipse(Vector2(0.0, -r * 0.16), Vector2(r * 0.86, r * 0.50)),
			tint.lightened(0.16))
	ci.draw_polyline(_ring(shell), Color(accent, 0.70), 2.0, true)
	# shell markings — three raised ridges
	for i in range(3):
		var x := (float(i) - 1.0) * r * 0.42
		ci.draw_line(Vector2(x, -r * 0.40), Vector2(x, r * 0.26), Color(accent, 0.35), 1.6, true)
	# claws: the gardener's whole job, so they lead the silhouette
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var open := sin(t * 2.2 + (0.0 if i == 0 else 1.4)) * 0.18
		var arm := Vector2(side * r * 1.05, -r * 0.10)
		var claw := Vector2(side * r * 1.85, -r * 0.55 - open * r)
		ci.draw_line(arm, claw, Color(tint.darkened(0.30), 1.0), 3.4, true)
		ci.draw_colored_polygon(_ellipse(claw, Vector2(r * 0.42, r * 0.34)), tint.lightened(0.10))
		ci.draw_polyline(PackedVector2Array([
			claw + Vector2(side * r * 0.30, -r * 0.20),
			claw + Vector2(side * r * 0.62, -r * 0.44),
			claw + Vector2(side * r * 0.52, -r * 0.02),
		]), Color(accent, 0.9), 1.8, true)
	# eye stalks
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var base := Vector2(side * r * 0.34, -r * 0.62)
		var tip := base + Vector2(side * r * 0.06, -r * 0.42)
		ci.draw_line(base, tip, Color(tint.darkened(0.40), 1.0), 1.8, true)
		ci.draw_circle(tip, r * 0.16, Color(0.10, 0.12, 0.14))
		ci.draw_circle(tip + Vector2(0.0, -r * 0.04), r * 0.06, Color(1, 1, 1, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Closed ellipse polygon — the workhorse for every body in here.
static func _ellipse(centre: Vector2, radius: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(BODY_SEGMENTS):
		var a := TAU * float(i) / float(BODY_SEGMENTS)
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts


static func _ring(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out
