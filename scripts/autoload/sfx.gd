extends Node
## Sons entièrement synthétisés au démarrage (aucun fichier audio requis) :
## bourdonnement de néons, ventilation, pas, portes métalliques, cœur, marteau…

const RATE := 22050

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_build()


func play(name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


func loop(name: String, db: float = -12.0, fade: float = 1.5) -> void:
	if not _streams.has(name):
		return
	var p: AudioStreamPlayer = _loops.get(name)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = _streams[name]
		add_child(p)
		_loops[name] = p
	if not p.playing:
		p.volume_db = -60.0
		p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, fade)


func stop_loop(name: String, fade: float = 1.2) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if p == null or not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.stop)


func stop_all_loops(fade: float = 1.0) -> void:
	for n in _loops.keys():
		stop_loop(n, fade)


func set_loop_volume(name: String, db: float, t: float = 0.5) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if p and p.playing:
		create_tween().tween_property(p, "volume_db", db, t)


func set_loop_pitch(name: String, pitch: float) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if p:
		p.pitch_scale = pitch


# ── Synthèse ────────────────────────────────────────────────────────────────
func _wav(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clamp(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	# Bourdonnement de néon (100 Hz + harmoniques), boucle de 2 s
	var hum := _buf(2.0)
	for i in hum.size():
		var t := float(i) / RATE
		hum[i] = 0.16 * sin(TAU * 100.0 * t) + 0.07 * sin(TAU * 200.0 * t) \
			+ 0.035 * sin(TAU * 300.0 * t) + 0.02 * sin(TAU * 1200.0 * t) + rng.randf_range(-0.012, 0.012)
	_streams["hum"] = _wav(hum, true)

	# Ventilation / ton de pièce (bruit brun), 4 s
	var room := _buf(4.0)
	var last := 0.0
	for i in room.size():
		last = (last + 0.02 * rng.randf_range(-1, 1)) / 1.02
		room[i] = last * 3.2
	_smooth_loop(room)
	_streams["room"] = _wav(room, true)

	# Moteur de fourgon : grondement 38 Hz + bruit filtré, 4 s
	var van := _buf(4.0)
	last = 0.0
	for i in van.size():
		var t := float(i) / RATE
		last = (last + 0.05 * rng.randf_range(-1, 1)) / 1.05
		van[i] = 0.35 * sin(TAU * 38.0 * t) * (0.8 + 0.2 * sin(TAU * 0.5 * t)) + 0.2 * sin(TAU * 76.0 * t) + last * 2.5
	_smooth_loop(van)
	_streams["van"] = _wav(van, true)

	# Brouhaha de salle (bruit modulé + formants), 6 s
	var crowd := _buf(6.0)
	last = 0.0
	var l2 := 0.0
	for i in crowd.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1, 1)
		last += (n - last) * 0.18
		l2 += (last - l2) * 0.3
		var env := 0.5 + 0.25 * sin(TAU * 0.5 * t) + 0.25 * sin(TAU * (1.0 / 3.0) * t + 1.0)
		crowd[i] = (last - l2) * 1.6 * env
	_smooth_loop(crowd)
	_streams["crowd"] = _wav(crowd, true)

	# Drone musical sombre (boucle parfaite de 8 s)
	var drone := _buf(8.0)
	var freqs := [55.0, 82.5, 110.0, 130.75, 164.875]
	var amps := [0.22, 0.14, 0.12, 0.07, 0.04]
	for i in drone.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			var lfo := 0.6 + 0.4 * sin(TAU * 0.125 * t + k * 1.3)
			v += amps[k] * sin(TAU * freqs[k] * t + 0.3 * sin(TAU * 0.25 * t)) * lfo
		drone[i] = v * 0.9
	_streams["drone"] = _wav(drone, true)

	# Pluie / extérieur nocturne (bruit rose), 4 s
	var rain := _buf(4.0)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	for i in rain.size():
		var w := rng.randf_range(-1, 1)
		b0 = 0.997 * b0 + w * 0.029591
		b1 = 0.985 * b1 + w * 0.032534
		b2 = 0.950 * b2 + w * 0.048056
		rain[i] = (b0 + b1 + b2 + w * 0.05) * 0.9
		if rng.randf() < 0.002:
			rain[i] += rng.randf_range(-0.5, 0.5)
	_smooth_loop(rain)
	_streams["rain"] = _wav(rain, true)

	# Pas
	var step := _buf(0.14)
	last = 0.0
	for i in step.size():
		var t := float(i) / RATE
		var env := exp(-t * 45.0)
		last += (rng.randf_range(-1, 1) - last) * 0.35
		step[i] = (last * 0.7 + 0.5 * sin(TAU * 90.0 * t)) * env * 0.9
	_streams["step"] = _wav(step)

	# Porte métallique qui claque
	var door := _buf(1.6)
	for i in door.size():
		var t := float(i) / RATE
		var hit := exp(-t * 30.0) * rng.randf_range(-1, 1)
		var thump := exp(-t * 8.0) * sin(TAU * 55.0 * t)
		var ring := exp(-t * 2.6) * (0.25 * sin(TAU * 420.0 * t) + 0.15 * sin(TAU * 671.0 * t) + 0.1 * sin(TAU * 1187.0 * t))
		door[i] = hit * 0.6 + thump * 0.8 + ring * 0.5
	_streams["door"] = _wav(door)

	# Verrou (clac-clac)
	var lock := _buf(0.5)
	for i in lock.size():
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.0, 0.18, 0.24]:
			if t >= c:
				var tt: float = t - c
				v += exp(-tt * 90.0) * (rng.randf_range(-1, 1) * 0.6 + sin(TAU * 2400.0 * tt) * 0.4)
		lock[i] = v * 0.8
	_streams["lock"] = _wav(lock)

	# Coulissement porte vitrée
	var slide := _buf(1.1)
	last = 0.0
	for i in slide.size():
		var t := float(i) / RATE
		last += (rng.randf_range(-1, 1) - last) * 0.08
		slide[i] = last * sin(PI * t / 1.1) * 1.4
	_streams["slide"] = _wav(slide)

	# Marteau du juge (bois)
	var gavel := _buf(0.6)
	for i in gavel.size():
		var t := float(i) / RATE
		gavel[i] = exp(-t * 35.0) * (0.7 * sin(TAU * 180.0 * t) + 0.4 * sin(TAU * 520.0 * t) + 0.3 * rng.randf_range(-1, 1))
	_streams["gavel"] = _wav(gavel)

	# Battement de cœur (boucle 0,9 s)
	var heart := _buf(0.9)
	for i in heart.size():
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.0, 0.22]:
			if t >= c:
				var tt: float = t - c
				v += exp(-tt * 18.0) * sin(TAU * (48.0 - tt * 30.0) * tt) * (1.0 if c == 0.0 else 0.7)
		heart[i] = v
	_streams["heart"] = _wav(heart, true)

	# Tic de machine à écrire / texte
	var tick := _buf(0.03)
	for i in tick.size():
		var t := float(i) / RATE
		tick[i] = exp(-t * 400.0) * rng.randf_range(-1, 1) * 0.5
	_streams["tick"] = _wav(tick)

	# Frappe clavier (OPJ qui tape le PV)
	var typing := _buf(3.0)
	var hits := []
	var tt2 := 0.0
	while tt2 < 2.9:
		hits.append(tt2)
		tt2 += rng.randf_range(0.07, 0.2) + (0.45 if rng.randf() < 0.08 else 0.0)
	for h in hits:
		var s0 := int(h * RATE)
		var amp := rng.randf_range(0.25, 0.5)
		for j in 500:
			if s0 + j < typing.size():
				var t := float(j) / RATE
				typing[s0 + j] += exp(-t * 260.0) * (rng.randf_range(-1, 1) * 0.7 + sin(TAU * 1800.0 * t) * 0.3) * amp
	_streams["typing"] = _wav(typing, true)

	# Clic UI / survol
	var ui := _buf(0.06)
	for i in ui.size():
		var t := float(i) / RATE
		ui[i] = exp(-t * 90.0) * sin(TAU * 1500.0 * t) * 0.35
	_streams["ui"] = _wav(ui)
	var hover := _buf(0.04)
	for i in hover.size():
		var t := float(i) / RATE
		hover[i] = exp(-t * 120.0) * sin(TAU * 2600.0 * t) * 0.2
	_streams["hover"] = _wav(hover)

	# Impact sourd (tampon, verdict, carte de chapitre)
	var boom := _buf(2.5)
	for i in boom.size():
		var t := float(i) / RATE
		boom[i] = exp(-t * 2.2) * (0.8 * sin(TAU * (42.0 - 8.0 * t) * t) + 0.25 * sin(TAU * 84.0 * t)) \
			+ exp(-t * 25.0) * rng.randf_range(-1, 1) * 0.3
	_streams["boom"] = _wav(boom)

	# Menottes (cliquetis métallique)
	var cuffs := _buf(0.8)
	for i in cuffs.size():
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.0, 0.09, 0.15, 0.41, 0.47]:
			if t >= c:
				var tt: float = t - c
				v += exp(-tt * 60.0) * (sin(TAU * 3100.0 * tt) * 0.5 + sin(TAU * 4700.0 * tt) * 0.3 + rng.randf_range(-1, 1) * 0.3)
		cuffs[i] = v * 0.6
	_streams["cuffs"] = _wav(cuffs)

	# Sirène lointaine (deux tons), 4 s
	var siren := _buf(4.0)
	var ph := 0.0
	for i in siren.size():
		var t := float(i) / RATE
		var f := 435.0 if fmod(t, 1.0) < 0.5 else 580.0
		ph += TAU * f / RATE
		siren[i] = sin(ph) * 0.12 * (0.7 + 0.3 * sin(TAU * 0.25 * t))
	_streams["siren"] = _wav(siren, true)


func _smooth_loop(b: PackedFloat32Array) -> void:
	# fondu croisé début/fin pour éviter les clics de boucle
	var n := int(0.15 * RATE)
	var sz := b.size()
	for i in n:
		var a := float(i) / n
		var mixed := b[i] * a + b[sz - n + i] * (1.0 - a)
		b[i] = mixed
	b.resize(sz - n)
