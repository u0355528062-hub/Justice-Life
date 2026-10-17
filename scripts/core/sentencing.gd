class_name Sentencing
extends RefCounted
## Calcule les réquisitions du parquet et la décision de la juridiction
## à partir du dossier et du comportement du joueur pendant la procédure.


static func modifier(gs) -> float:
	var m := 1.0
	match gs.record:
		"vierge": m *= 0.72
		"antecedents": m *= 1.15
		"recidive": m *= 1.45
	m *= 1.0 + 0.12 * gs.aggravations.size()
	if gs.admissions > 0 and gs.denials == 0:
		m *= 0.84
	m *= 1.0 + min(gs.lies, 4) * 0.07
	if gs.trial_changed_story and gs.trial_story != "aveux":
		m *= 1.1
	m *= clamp(1.0 - gs.attitude * 0.035, 0.8, 1.3)
	match gs.lawyer:
		"none": m *= 1.1
		"choisi": m *= 0.93
	m *= clamp(1.0 - gs.lawyer_bond * 0.03, 0.88, 1.06)
	match gs.situation:
		"cdi": m *= 0.88
		"etudiant": m *= 0.9
		"interim": m *= 0.95
		"chomage": m *= 1.05
	match gs.last_word:
		"regrets": m *= 0.9
		"victime": m *= 0.88
		"provocation": m *= 1.25
	return m


static func base_months(gs) -> float:
	var infr: Array = gs.infractions()
	if infr.is_empty():
		return 0.0
	var main: Dictionary = infr[0]
	var mp: int = main.prison
	if mp >= InfractionDB.PERPETUITE:
		mp = 360
	var frac := 0.45 if main.kind == "X" else 0.22
	var b := mp * frac
	for i in range(1, infr.size()):
		var p: int = min(infr[i].prison, 360)
		b += p * 0.07
	return b


## Probabilité d'une relaxe / d'un acquittement (doute raisonnable).
static func acquittal_chance(gs) -> float:
	if gs.admissions > 0 and gs.denials == 0:
		return 0.0
	var p: float = (0.62 - gs.evidence) * 1.8
	if gs.denials > 0 and gs.lies == 0:
		p += 0.08
	if gs.lawyer == "choisi":
		p += 0.06
	if gs.trial_changed_story:
		p -= 0.1
	return clamp(p, 0.0, 0.75)


static func requisitions(gs) -> Dictionary:
	var legal_max: int = gs.max_prison_months()
	var k: String = gs.kind()
	var mod := modifier(gs)
	var r := {"prison": 0, "sursis": 0, "fine": 0, "text": ""}
	if legal_max <= 0:
		var f: int = int(round(gs.max_fine() * 0.4 * mod / 10.0) * 10)
		r.fine = clamp(f, 30, gs.max_fine())
		r.text = "une amende de %s" % InfractionDB.format_eur(r.fine)
		return r
	var months: int = int(round(base_months(gs) * mod * 1.3))
	months = clamp(months, 2, min(legal_max, 360))
	if legal_max >= InfractionDB.PERPETUITE and mod > 1.35 and k == "X":
		r.prison = InfractionDB.PERPETUITE
		r.text = "la réclusion criminelle à perpétuité"
		return r
	r.prison = months
	if gs.record == "vierge" and months <= 36 and k != "X":
		r.sursis = int(months / 2) if months > 12 else int(months * 0.6)
	var word := "de réclusion criminelle" if k == "X" else "d'emprisonnement"
	r.text = "%s %s" % [InfractionDB.prison_label(months), word]
	if r.sursis > 0:
		r.text += ", dont %s assortis du sursis" % InfractionDB.prison_label(r.sursis)
	if months >= 12 or gs.record == "recidive":
		r.text += ", avec maintien en détention" if gs.outcome_after_gav in ["ci", "instruction"] else ", avec mandat de dépôt"
	return r


static func decide(gs) -> Dictionary:
	var v := {
		"guilty": true, "prison": 0, "sursis": 0, "fine": 0, "ddse": false,
		"incarcerated": false, "to_serve": 0, "extras": [], "damages": 0,
		"headline": "", "detail": "",
	}
	var k: String = gs.kind()
	var legal_max: int = gs.max_prison_months()
	if randf() < acquittal_chance(gs):
		v.guilty = false
		v.headline = "ACQUITTÉ" if k == "X" else "RELAXÉ"
		v.detail = "Le tribunal estime que les faits ne sont pas suffisamment établis. Le doute profite à l'%s." % gs.jurisdiction().accused
		return v

	var mod := modifier(gs) * randf_range(0.85, 1.08)
	if legal_max <= 0:
		var f: int = int(round(gs.max_fine() * 0.3 * mod / 10.0) * 10)
		v.fine = clamp(f, 20, gs.max_fine())
		v.headline = "AMENDE"
		v.detail = "Condamné à une amende de %s." % InfractionDB.format_eur(v.fine)
		_extras(gs, v)
		return v

	var months: int = int(round(base_months(gs) * mod))
	if legal_max >= InfractionDB.PERPETUITE and mod > 1.5 and k == "X":
		months = InfractionDB.PERPETUITE
	else:
		months = clamp(months, 0, min(legal_max, 360))
	# Les peines d'emprisonnement ferme de moins d'un mois sont interdites.
	if months < 1:
		var f2: int = int(round(gs.max_fine() * 0.06 * mod / 50.0) * 50)
		v.fine = max(f2, 150)
		v.headline = "AMENDE"
		v.detail = "Condamné à une amende de %s." % InfractionDB.format_eur(v.fine)
		_extras(gs, v)
		return v

	v.prison = months
	# Sursis
	if k != "X" and months <= 60 and gs.record != "recidive":
		if gs.record == "vierge" and months <= 12 and gs.attitude >= -1:
			v.sursis = months
		elif months <= 36:
			v.sursis = int(round(months * (0.5 if gs.record == "vierge" else 0.3)))
	if k == "X" and months <= 60 and gs.record == "vierge" and mod < 0.8:
		v.sursis = int(months / 2)
	var ferme: int = months - v.sursis if months < InfractionDB.PERPETUITE else months
	# Aménagement : peine ferme ≤ 6 mois → aménagée (sauf récidive / pas d'insertion)
	if ferme > 0 and ferme <= 6 and gs.record != "recidive" and gs.situation in ["cdi", "etudiant", "interim"]:
		v.ddse = true
	if ferme > 0 and not v.ddse:
		v.incarcerated = true
		var served: int = gs.detention_provisoire_months
		v.to_serve = max(ferme - served, 0) if ferme < InfractionDB.PERPETUITE else 360 - served
		if v.to_serve <= 0:
			v.incarcerated = false

	var word := "de réclusion criminelle" if k == "X" else "d'emprisonnement"
	if months >= InfractionDB.PERPETUITE:
		v.headline = "PERPÉTUITÉ"
		v.detail = "Condamné à la réclusion criminelle à perpétuité, assortie d'une période de sûreté de 18 ans."
	elif v.sursis == months:
		v.headline = "SURSIS"
		v.detail = "Condamné à %s %s, entièrement assortis du sursis simple." % [InfractionDB.prison_label(months), word]
	else:
		v.headline = "COUPABLE"
		v.detail = "Condamné à %s %s" % [InfractionDB.prison_label(months), word]
		if v.sursis > 0:
			v.detail += ", dont %s avec sursis" % InfractionDB.prison_label(v.sursis)
		v.detail += "."
		if v.ddse:
			v.detail += " La partie ferme sera exécutée sous surveillance électronique (bracelet)."
		elif v.incarcerated:
			v.detail += " Mandat de dépôt : incarcération immédiate."
			if gs.detention_provisoire_months > 0:
				v.detail += " (%d mois de détention provisoire déduits)" % gs.detention_provisoire_months
	if gs.max_fine() > 0 and k == "D" and months < 60:
		v.fine = int(round(gs.max_fine() * 0.02 * mod / 50.0) * 50)
		if v.fine >= 100:
			v.detail += " Amende de %s." % InfractionDB.format_eur(v.fine)
		else:
			v.fine = 0
	_extras(gs, v)
	return v


static func _extras(gs, v: Dictionary) -> void:
	var cats: Array = gs.categories()
	if "route" in cats:
		v.extras.append("Suspension du permis de conduire : %d mois" % randi_range(6, 24))
	if "stup" in cats:
		v.extras.append("Stage de sensibilisation aux dangers des stupéfiants")
	if "organise" in cats:
		v.extras.append("Interdiction de détenir ou porter une arme pendant 5 ans")
	if "personnes" in cats and gs.kind() != "C":
		v.extras.append("Interdiction d'entrer en contact avec la victime")
	if "eco" in cats:
		v.extras.append("Interdiction de gérer une entreprise pendant 5 ans")
	if gs.has_victim():
		v.damages = randi_range(8, 60) * 100
		v.extras.append("Dommages et intérêts à la partie civile : %s" % InfractionDB.format_eur(v.damages))
	if gs.record == "recidive":
		v.extras.append("État de récidive légale retenu")
