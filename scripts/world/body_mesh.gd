class_name BodyMesh
extends RefCounted
## Générateur de maillages anatomiques (sans aucun fichier 3D) :
## tubes à sections elliptiques (torse, membres, robes plissées), tête sculptée
## (arcades, orbites, nez, pommettes, lèvres, menton), mains à cinq doigts,
## chaussures, chevelures et barbes.

static var _cache := {}


# ── Assemblage de maillage ───────────────────────────────────────────────────
class Builder:
	var st := SurfaceTool.new()
	var n := 0
	var colored := false

	func _init(p_colored: bool = false) -> void:
		colored = p_colored
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## Anneaux ordonnés de haut en bas ; points d'un anneau ordonnés par angle
	## (x = cos a, z = sin a). Pôles optionnels (null = ouvert).
	func add_rings(rings: Array, top_pole, bottom_pole, xf: Transform3D = Transform3D.IDENTITY,
			colors: Array = [], pole_colors: Array = [], closed: bool = true) -> void:
		var r_count: int = (rings[0] as PackedVector3Array).size()
		var seg: int = r_count if closed else r_count - 1
		var base := n
		var rows := rings.size()
		for i in rows:
			var ring: PackedVector3Array = rings[i]
			for j in r_count:
				st.set_uv(Vector2(float(j) / r_count, float(i) / max(rows - 1, 1)))
				if colored:
					st.set_color(colors[i][j])
				st.add_vertex(xf * ring[j])
				n += 1
		for i in rows - 1:
			for j in seg:
				var j2 := (j + 1) % r_count
				var a := base + i * r_count + j
				var b := base + i * r_count + j2
				var c := base + (i + 1) * r_count + j
				var d := base + (i + 1) * r_count + j2
				st.add_index(a); st.add_index(c); st.add_index(b)
				st.add_index(b); st.add_index(c); st.add_index(d)
		if top_pole != null:
			st.set_uv(Vector2(0.5, 0.0))
			if colored:
				st.set_color(pole_colors[0])
			st.add_vertex(xf * (top_pole as Vector3))
			var p := n
			n += 1
			for j in seg:
				st.add_index(p); st.add_index(base + j); st.add_index(base + (j + 1) % r_count)
		if bottom_pole != null:
			st.set_uv(Vector2(0.5, 1.0))
			if colored:
				st.set_color(pole_colors[1])
			st.add_vertex(xf * (bottom_pole as Vector3))
			var p2 := n
			n += 1
			var last := base + (rows - 1) * r_count
			for j in seg:
				st.add_index(p2); st.add_index(last + (j + 1) % r_count); st.add_index(last + j)

	func commit() -> ArrayMesh:
		st.generate_normals()
		st.generate_tangents()
		return st.commit()


static func _g1(t: float, s: float) -> float:
	return exp(-(t * t) / (2.0 * s * s))


static func _g2(dx: float, dy: float, sx: float, sy: float) -> float:
	return exp(-(dx * dx / (2.0 * sx * sx) + dy * dy / (2.0 * sy * sy)))


# ── Tubes ────────────────────────────────────────────────────────────────────
## sections : [[y, rx, rz, avant, arrière, plis], …] — « avant » / « arrière » gonflent
## la face -z / +z (pectoraux, mollets…), « plis » ajoute des drapés (robes).
static func tube_rings(sections: Array, radial: int, pleat_count: int = 12,
		a0: float = 0.0, a1: float = TAU, closed: bool = true) -> Array:
	var secs := sections.duplicate()
	secs.sort_custom(func(a, b): return a[0] > b[0])
	var rings := []
	for s in secs:
		var y: float = s[0]
		var rx: float = s[1]
		var rz: float = s[2]
		var fb: float = s[3] if s.size() > 3 else 0.0
		var bb: float = s[4] if s.size() > 4 else 0.0
		var pl: float = s[5] if s.size() > 5 else 0.0
		var cz: float = s[6] if s.size() > 6 else 0.0
		var ring := PackedVector3Array()
		var cnt := radial if closed else radial + 1
		for j in cnt:
			var a := a0 + (a1 - a0) * float(j) / radial
			var fw := pow(max(0.0, -sin(a)), 2.0)
			var bw := pow(max(0.0, sin(a)), 2.0)
			var k := 1.0 + fb * fw + bb * bw + pl * sin(a * pleat_count + y * 9.0)
			ring.append(Vector3(cos(a) * rx * k, y, cz + sin(a) * rz * k))
		rings.append(ring)
	return rings


## Ajoute des anneaux d'arrondi aux extrémités d'un tube.
static func round_caps(rings: Array, top_len: float, bottom_len: float, steps: int = 3) -> Dictionary:
	var out := rings.duplicate()
	var top_pole = null
	var bot_pole = null
	if top_len > 0.0:
		var first: PackedVector3Array = rings[0]
		var c := _center(first)
		for k in range(steps, 0, -1):
			var t := float(k) / (steps + 1)
			var sc := cos(t * PI * 0.5)
			var dy := top_len * sin(t * PI * 0.5)
			var r := PackedVector3Array()
			for p in first:
				r.append(Vector3(c.x + (p.x - c.x) * sc, p.y + dy, c.z + (p.z - c.z) * sc))
			out.push_front(r)
		top_pole = c + Vector3(0, top_len, 0)
	if bottom_len > 0.0:
		var last: PackedVector3Array = rings[-1]
		var c2 := _center(last)
		for k in range(1, steps + 1):
			var t := float(k) / (steps + 1)
			var sc := cos(t * PI * 0.5)
			var dy := bottom_len * sin(t * PI * 0.5)
			var r2 := PackedVector3Array()
			for p in last:
				r2.append(Vector3(c2.x + (p.x - c2.x) * sc, p.y - dy, c2.z + (p.z - c2.z) * sc))
			out.append(r2)
		bot_pole = c2 - Vector3(0, bottom_len, 0)
	return {"rings": out, "top": top_pole, "bottom": bot_pole}


static func _center(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in r:
		c += p
	return c / max(r.size(), 1)


static func tube(key: String, sections: Array, radial: int = 20, cap_top: float = 0.02, cap_bottom: float = 0.02,
		pleats: int = 12) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var rc := round_caps(tube_rings(sections, radial, pleats), cap_top, cap_bottom)
	var b := Builder.new()
	b.add_rings(rc.rings, rc.top, rc.bottom)
	var m := b.commit()
	_cache[key] = m
	return m


## Demi-tube ouvert (chevelure longue, capuche…).
static func open_tube(key: String, sections: Array, a0: float, a1: float, radial: int = 16) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var rings := tube_rings(sections, radial, 12, a0, a1, false)
	var b := Builder.new()
	b.add_rings(rings, null, null, Transform3D.IDENTITY, [], [], false)
	var m := b.commit()
	_cache[key] = m
	return m


# ── Corps ────────────────────────────────────────────────────────────────────
static func torso(fem: bool, build: float) -> ArrayMesh:
	var k := "torso_%s_%.2f" % [fem, build]
	var w := build
	var s: Array
	if fem:
		s = [[-0.06, 0.15 * w, 0.095 * w], [0.05, 0.12 * w, 0.085 * w], [0.16, 0.13 * w, 0.09 * w],
			[0.27, 0.15 * w, 0.1 * w, 0.32], [0.34, 0.16 * w, 0.1 * w, 0.22], [0.42, 0.175 * w, 0.085 * w],
			[0.47, 0.12 * w, 0.07], [0.51, 0.06, 0.05]]
	else:
		s = [[-0.06, 0.145 * w, 0.095 * w], [0.05, 0.135 * w, 0.09 * w, 0.05], [0.16, 0.145 * w, 0.095 * w],
			[0.27, 0.165 * w, 0.105 * w, 0.14, 0.05], [0.36, 0.18 * w, 0.105 * w, 0.08, 0.06],
			[0.43, 0.195 * w, 0.09 * w], [0.48, 0.13 * w, 0.075], [0.52, 0.065, 0.055]]
	return tube(k, s, 28, 0.015, 0.0)


static func pelvis(fem: bool, build: float) -> ArrayMesh:
	var w := build * (1.1 if fem else 1.0)
	return tube("pelvis_%s_%.2f" % [fem, build], [[0.08, 0.145 * w, 0.095 * w], [0.0, 0.16 * w, 0.105 * w, 0.0, 0.12],
		[-0.08, 0.162 * w, 0.105 * w, 0.0, 0.16], [-0.14, 0.12 * w, 0.09 * w]], 28, 0.0, 0.03)


static func thigh(build: float) -> ArrayMesh:
	var w := build
	return tube("thigh_%.2f" % build, [[0.03, 0.078 * w, 0.08 * w], [-0.06, 0.082 * w, 0.085 * w], [-0.2, 0.072 * w, 0.075 * w, 0.06],
		[-0.4, 0.055 * w, 0.058 * w], [-0.47, 0.05 * w, 0.053 * w]], 20, 0.03, 0.03)


static func shin(build: float) -> ArrayMesh:
	var w := build
	return tube("shin_%.2f" % build, [[0.02, 0.052 * w, 0.054 * w], [-0.08, 0.054 * w, 0.056 * w, 0.0, 0.2], [-0.24, 0.045 * w, 0.046 * w, 0.0, 0.08],
		[-0.42, 0.034 * w, 0.036 * w], [-0.46, 0.031 * w, 0.033 * w]], 18, 0.02, 0.02)


static func upper_arm(build: float) -> ArrayMesh:
	var w := build
	return tube("uarm_%.2f" % build, [[0.03, 0.054 * w, 0.056 * w], [-0.05, 0.05 * w, 0.052 * w], [-0.15, 0.047 * w, 0.049 * w, 0.12],
		[-0.27, 0.04 * w, 0.041 * w], [-0.3, 0.038 * w, 0.039 * w]], 18, 0.03, 0.025)


static func forearm(build: float, sleeve_bell: float = 0.0) -> ArrayMesh:
	var w := build
	var e := sleeve_bell
	return tube("farm_%.2f_%.2f" % [build, e], [[0.02, 0.04 * w + e * 0.2, 0.041 * w + e * 0.2], [-0.05, 0.043 * w + e * 0.4, 0.044 * w + e * 0.4],
		[-0.18, 0.033 * w + e * 0.8, 0.035 * w + e * 0.8], [-0.25, 0.028 * w + e, 0.03 * w + e]], 18, 0.02, 0.015 if e == 0.0 else 0.0)


static func neck(fem: bool) -> ArrayMesh:
	var r := 0.047 if fem else 0.055
	return tube("neck_%s" % fem, [[0.16, r * 0.9, r * 0.95], [0.08, r * 0.92, r], [-0.02, r * 1.15, r * 1.05]], 18, 0.0, 0.0)


## Main : paume + quatre doigts légèrement fléchis + pouce (côté s = ±1).
static func hand(s: float, fem: bool) -> ArrayMesh:
	var key := "hand_%d_%s" % [int(s), fem]
	if _cache.has(key):
		return _cache[key]
	var k := 0.9 if fem else 1.0
	var b := Builder.new()
	var palm := round_caps(tube_rings([[0.0, 0.016 * k, 0.036 * k], [-0.05, 0.017 * k, 0.043 * k], [-0.085, 0.014 * k, 0.04 * k]], 14), 0.012, 0.0)
	b.add_rings(palm.rings, palm.top, null)
	var lens := [0.072, 0.082, 0.077, 0.062]
	for i in 4:
		var z := (-0.028 + i * 0.0187) * k
		var fl: float = lens[i] * k
		var f := round_caps(tube_rings([[0.0, 0.0085 * k, 0.0085 * k], [-fl * 0.5, 0.0078 * k, 0.008 * k], [-fl, 0.0068 * k, 0.007 * k]], 8), 0.0, 0.006)
		var xf := Transform3D(Basis(Vector3.RIGHT, 0.28 - i * 0.02).rotated(Vector3.FORWARD, s * 0.08), Vector3(s * 0.002, -0.08 * k, z))
		b.add_rings(f.rings, null, f.bottom, xf)
	var th := round_caps(tube_rings([[0.0, 0.011 * k, 0.011 * k], [-0.035, 0.0095 * k, 0.0095 * k], [-0.06, 0.008 * k, 0.008 * k]], 8), 0.006, 0.006)
	var txf := Transform3D(Basis(Vector3.RIGHT, -0.75).rotated(Vector3.FORWARD, s * -0.35), Vector3(-s * 0.008, -0.025 * k, -0.03 * k))
	b.add_rings(th.rings, th.top, th.bottom, txf)
	var m := b.commit()
	_cache[key] = m
	return m


static func shoe(kind: String) -> ArrayMesh:
	var key := "shoe_" + kind
	if _cache.has(key):
		return _cache[key]
	var s: Array
	if kind == "sneaker":
		s = [[0.06, 0.044, 0.045], [-0.02, 0.048, 0.05], [-0.14, 0.052, 0.042], [-0.22, 0.047, 0.032], [-0.26, 0.036, 0.026]]
	else:
		s = [[0.055, 0.042, 0.042], [-0.02, 0.045, 0.046], [-0.14, 0.048, 0.034], [-0.23, 0.042, 0.024], [-0.27, 0.03, 0.019]]
	var rc := round_caps(tube_rings(s, 18), 0.02, 0.02)
	var b := Builder.new()
	b.add_rings(rc.rings, rc.top, rc.bottom)
	var m := b.commit()
	_cache[key] = m
	return m


## Robe de magistrat / d'avocat à plis (debout ou assis).
static func robe(sitting: bool, sw: float) -> ArrayMesh:
	var s: Array
	if sitting:
		s = [[0.5, 0.12, 0.08], [0.44, 0.21 * sw, 0.125], [0.3, 0.2 * sw, 0.13, 0.05], [0.05, 0.19 * sw, 0.13, 0.0, 0.0, 0.02],
			[-0.1, 0.2 * sw, 0.14, 0.0, 0.0, 0.03]]
	else:
		s = [[0.5, 0.12, 0.08], [0.44, 0.21 * sw, 0.125], [0.3, 0.2 * sw, 0.13, 0.05], [0.0, 0.195 * sw, 0.135, 0.0, 0.0, 0.02],
			[-0.3, 0.235 * sw, 0.16, 0.0, 0.0, 0.04], [-0.6, 0.27 * sw, 0.19, 0.0, 0.0, 0.055], [-0.87, 0.3 * sw, 0.21, 0.0, 0.0, 0.065]]
	return tube("robe_%s_%.2f" % [sitting, sw], s, 40, 0.01, 0.0, 14)


## Blouse de médecin.
static func coat(sw: float) -> ArrayMesh:
	return tube("coat_%.2f" % sw, [[0.5, 0.12, 0.08], [0.44, 0.205 * sw, 0.12], [0.3, 0.195 * sw, 0.125, 0.06], [0.0, 0.19 * sw, 0.13],
		[-0.25, 0.215 * sw, 0.15, 0.0, 0.0, 0.02], [-0.42, 0.23 * sw, 0.16, 0.0, 0.0, 0.03]], 32, 0.01, 0.0, 9)


# ── Tête sculptée ────────────────────────────────────────────────────────────
const HEAD_LAT := 40
const HEAD_LON := 56


static func head_point(d: Vector3, p: Dictionary) -> Vector3:
	var rx: float = 0.074 * p.get("width", 1.0)
	var ry := 0.112
	var rz := 0.095
	var v := Vector3(d.x * rx, d.y * ry, d.z * rz)
	var y := v.y
	var jt := smoothstep(-0.005, -0.112, y)
	v.x *= lerpf(1.0, 0.56 * p.get("jaw", 1.0), jt * jt * 0.9 + jt * 0.1)
	if v.z > 0.0 and y < -0.02:
		v.z *= lerpf(1.0, 0.5, smoothstep(-0.02, -0.105, y))
	if v.z > 0.0 and y > -0.02:
		v.z *= 1.07
	if v.z < 0.0:
		v.z *= lerpf(0.94, 0.84, smoothstep(-0.03, -0.11, y))
	var w := smoothstep(0.2, 0.7, -d.z)
	if w > 0.0:
		var x := v.x
		var off := 0.0
		var nose: float = p.get("nose", 1.0)
		for s in [-1.0, 1.0]:
			off -= 0.011 * _g2(x - s * 0.031, y - 0.004, 0.016, 0.011)
			off += 0.0065 * _g2(x - s * 0.046, y + 0.014, 0.02, 0.015)
			off += 0.0055 * _g2(x - s * 0.013, y + 0.036, 0.0075, 0.0065)
		off += 0.0055 * _g1(y - 0.026, 0.008) * smoothstep(0.068, 0.02, absf(x))
		var ny := clampf((0.024 - y) / 0.062, 0.0, 1.0)
		var f_above := smoothstep(0.034, 0.016, y)
		var f_below := smoothstep(-0.048, -0.037, y)
		off += lerpf(0.004, 0.027 * nose, pow(ny, 1.35)) * f_above * f_below * _g1(x, lerpf(0.007, 0.0125, ny))
		off += 0.0016 * _g2(x, y + 0.049, 0.004, 0.005)
		off += 0.0075 * _g2(x, y + 0.057, 0.02, 0.0052) * p.get("lips", 1.0)
		off += 0.0068 * _g2(x, y + 0.071, 0.018, 0.0058) * p.get("lips", 1.0)
		off -= 0.0032 * _g2(x, y + 0.0635, 0.022, 0.0016)
		off += 0.0072 * _g2(x, y + 0.1, 0.019, 0.012) * p.get("chin", 1.0)
		v.z -= off * w
	return v


static func head_color(v: Vector3, d: Vector3, p: Dictionary) -> Color:
	var c := Color(1, 1, 1)
	var w := smoothstep(0.2, 0.7, -d.z)
	if w <= 0.0:
		return c
	var x := v.x
	var y := v.y
	var lip: float = max(_g2(x, y + 0.057, 0.019, 0.005), _g2(x, y + 0.071, 0.017, 0.0055)) * w
	c = c.lerp(Color(0.8, 0.52, 0.52), lip * 0.75)
	for s in [-1.0, 1.0]:
		var ch := _g2(x - s * 0.045, y + 0.03, 0.02, 0.018) * w
		c = c.lerp(Color(1.0, 0.86, 0.84), ch * 0.5)
		var so := _g2(x - s * 0.031, y - 0.006, 0.02, 0.014) * w
		c = c.lerp(Color(0.84, 0.76, 0.74), so * 0.55)
	var tip := _g2(x, y + 0.03, 0.01, 0.01) * w
	c = c.lerp(Color(1.0, 0.85, 0.83), tip * 0.4)
	if p.get("stubble", false):
		var jaw: float = smoothstep(-0.035, -0.06, y) * (1.0 - lip)
		var mous: float = _g2(x, y + 0.048, 0.022, 0.004) * (1.0 - lip)
		c = c.lerp(Color(0.72, 0.7, 0.68), clampf(jaw + mous, 0.0, 1.0) * 0.6)
	return c


static func head(p: Dictionary) -> ArrayMesh:
	var key := "head_%.2f_%.2f_%.2f_%.2f_%.2f_%s" % [p.get("width", 1.0), p.get("jaw", 1.0), p.get("nose", 1.0),
		p.get("lips", 1.0), p.get("chin", 1.0), p.get("stubble", false)]
	if _cache.has(key):
		return _cache[key]
	var rings := []
	var cols := []
	for i in range(1, HEAD_LAT):
		var th := PI * i / HEAD_LAT
		var ring := PackedVector3Array()
		var cr := []
		for j in HEAD_LON:
			var a := TAU * j / HEAD_LON
			var d := Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a))
			var v := head_point(d, p)
			ring.append(v)
			cr.append(head_color(v, d, p))
		rings.append(ring)
		cols.append(cr)
	var b := Builder.new(true)
	b.add_rings(rings, head_point(Vector3.UP, p), head_point(Vector3.DOWN, p), Transform3D.IDENTITY, cols,
		[Color.WHITE, Color.WHITE])
	var m := b.commit()
	_cache[key] = m
	return m


## Position de la surface du visage en (x, y) (face avant) — pour placer yeux, sourcils…
static func face_z(x: float, y: float, p: Dictionary) -> float:
	var d := Vector3(x / 0.074, y / 0.112, -0.8).normalized()
	var v := Vector3.ZERO
	for i in 12:
		v = head_point(d, p)
		d = Vector3(d.x + (x - v.x) / 0.074, d.y + (y - v.y) / 0.112, d.z).normalized()
		if d.z > -0.05:
			d.z = -0.05
	return head_point(d, p).z


## Chevelure : calotte décalée vers l'extérieur au-dessus d'une ligne d'implantation.
static func hair(p: Dictionary, style: String) -> ArrayMesh:
	var key := "hair_%s_%.2f_%.2f" % [style, p.get("width", 1.0), p.get("jaw", 1.0)]
	if _cache.has(key):
		return _cache[key]
	var thick := 0.0025 if style == "buzz" else (0.009 if style in ["short", "bob", "long", "bun"] else 0.006)
	var rings := []
	for i in range(1, HEAD_LAT):
		var th := PI * i / HEAD_LAT
		var ring := PackedVector3Array()
		for j in HEAD_LON:
			var a := TAU * j / HEAD_LON
			var d := Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a))
			var v := head_point(d, p)
			var t := (d.z + 1.0) * 0.5
			var line := lerpf(0.052, -0.072, smoothstep(0.22, 0.85, t))
			if style in ["long", "bob", "bun"]:
				line -= 0.006
			var depth := smoothstep(line - 0.004, line + 0.01, v.y)
			var nrm := v.normalized()
			var vol: float = thick + 0.008 * max(d.y, 0.0) * (1.0 if style != "buzz" else 0.0)
			var hp: Vector3 = v + nrm * (vol * depth - 0.006 * (1.0 - depth))
			ring.append(hp)
		rings.append(ring)
	var b := Builder.new()
	var top := head_point(Vector3.UP, p) + Vector3(0, thick + 0.008, 0)
	b.add_rings(rings, top, null)
	var m := b.commit()
	_cache[key] = m
	return m


## Barbe (et moustache) épousant le bas du visage.
static func beard(p: Dictionary) -> ArrayMesh:
	var key := "beard_%.2f_%.2f_%.2f" % [p.get("width", 1.0), p.get("jaw", 1.0), p.get("chin", 1.0)]
	if _cache.has(key):
		return _cache[key]
	var rings := []
	for i in range(1, HEAD_LAT):
		var th := PI * i / HEAD_LAT
		var ring := PackedVector3Array()
		for j in HEAD_LON:
			var a := TAU * j / HEAD_LON
			var d := Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a))
			var v := head_point(d, p)
			var front := smoothstep(0.05, 0.4, -d.z)
			var region := smoothstep(-0.03, -0.05, v.y) * front
			var lips: float = max(_g2(v.x, v.y + 0.064, 0.024, 0.009), 0.0)
			region *= 1.0 - lips
			region = max(region, _g2(v.x, v.y + 0.049, 0.022, 0.0035) * front)
			var hp := v + v.normalized() * (0.0045 * region - 0.004 * (1.0 - region))
			ring.append(hp)
		rings.append(ring)
	var b := Builder.new()
	b.add_rings(rings, null, head_point(Vector3.DOWN, p) + Vector3(0, -0.004, 0))
	var m := b.commit()
	_cache[key] = m
	return m
