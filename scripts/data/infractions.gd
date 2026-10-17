class_name InfractionDB
extends RefCounted
## Catalogue des infractions (droit pénal français, peines maximales encourues).
## Les peines sont indicatives et simplifiées pour le jeu.
##
## Format compact : [id, nom, catégorie, article, prison (mois, 999 = perpétuité),
##                   amende max (€), nature ("C" contravention / "D" délit / "X" crime),
##                   GAV max (h), victime ?, faits ("d'avoir ...")]

const PERPETUITE := 999

const CATEGORIES := [
	{"id": "personnes", "name": "Atteintes aux personnes", "icon": "✋", "color": Color("e5484d")},
	{"id": "biens", "name": "Atteintes aux biens", "icon": "◆", "color": Color("f5a524")},
	{"id": "stup", "name": "Stupéfiants", "icon": "✱", "color": Color("8e4ec6")},
	{"id": "route", "name": "Sécurité routière", "icon": "▲", "color": Color("3e9bf2")},
	{"id": "autorite", "name": "Autorité & ordre public", "icon": "⚑", "color": Color("12a594")},
	{"id": "numerique", "name": "Cybercriminalité", "icon": "⌘", "color": Color("00a2c7")},
	{"id": "eco", "name": "Économique & financier", "icon": "€", "color": Color("46a758")},
	{"id": "organise", "name": "Armes & crime organisé", "icon": "✚", "color": Color("d6409f")},
	{"id": "environnement", "name": "Animaux & environnement", "icon": "❦", "color": Color("86b33c")},
	{"id": "contraventions", "name": "Contraventions", "icon": "●", "color": Color("8b8d98")},
]

const RAW := [
	# ── Atteintes aux personnes ───────────────────────────────────────────────
	["meurtre", "Meurtre", "personnes", "Art. 221-1 C. pén.", 360, 0, "X", 48, true, "volontairement donné la mort à autrui"],
	["assassinat", "Assassinat", "personnes", "Art. 221-3 C. pén.", PERPETUITE, 0, "X", 48, true, "volontairement donné la mort à autrui avec préméditation"],
	["tentative_meurtre", "Tentative de meurtre", "personnes", "Art. 121-5 et 221-1 C. pén.", 360, 0, "X", 48, true, "tenté de donner volontairement la mort à autrui"],
	["violences_mort", "Violences ayant entraîné la mort sans intention de la donner", "personnes", "Art. 222-7 C. pén.", 180, 0, "X", 48, true, "commis des violences volontaires ayant entraîné la mort sans intention de la donner"],
	["violences_infirmite", "Violences ayant entraîné une infirmité permanente", "personnes", "Art. 222-9 C. pén.", 120, 150000, "D", 48, true, "commis des violences ayant entraîné une mutilation ou une infirmité permanente"],
	["violences_itt_plus8", "Violences volontaires (ITT > 8 jours)", "personnes", "Art. 222-11 C. pén.", 36, 45000, "D", 48, true, "commis des violences volontaires ayant entraîné une incapacité totale de travail supérieure à huit jours"],
	["violences_aggravees", "Violences aggravées (ITT ≤ 8 jours, en réunion / avec arme)", "personnes", "Art. 222-13 C. pén.", 36, 45000, "D", 48, true, "commis des violences volontaires aggravées ayant entraîné une ITT n'excédant pas huit jours"],
	["violences_conjugales", "Violences sur conjoint ou concubin", "personnes", "Art. 222-13 6° C. pén.", 36, 45000, "D", 48, true, "commis des violences volontaires sur son conjoint ou concubin"],
	["homicide_involontaire", "Homicide involontaire", "personnes", "Art. 221-6 C. pén.", 36, 45000, "D", 48, true, "par maladresse, imprudence ou négligence, causé la mort d'autrui"],
	["blessures_involontaires", "Blessures involontaires (ITT > 3 mois)", "personnes", "Art. 222-19 C. pén.", 24, 30000, "D", 24, true, "par imprudence, causé à autrui une ITT supérieure à trois mois"],
	["menaces_mort", "Menaces de mort", "personnes", "Art. 222-17 C. pén.", 36, 45000, "D", 24, true, "menacé autrui de mort"],
	["menaces_mort_condition", "Menaces de mort sous condition", "personnes", "Art. 222-18 C. pén.", 60, 75000, "D", 24, true, "menacé autrui de mort avec l'ordre de remplir une condition"],
	["harcelement_moral", "Harcèlement moral", "personnes", "Art. 222-33-2-2 C. pén.", 12, 15000, "D", 24, true, "harcelé autrui par des propos ou comportements répétés dégradant ses conditions de vie"],
	["harcelement_conjoint", "Harcèlement moral sur conjoint", "personnes", "Art. 222-33-2-1 C. pén.", 36, 45000, "D", 48, true, "harcelé son conjoint par des propos ou comportements répétés"],
	["harcelement_sexuel", "Harcèlement sexuel", "personnes", "Art. 222-33 C. pén.", 24, 30000, "D", 24, true, "imposé de façon répétée des propos ou comportements à connotation sexuelle"],
	["agression_sexuelle", "Agression sexuelle", "personnes", "Art. 222-27 C. pén.", 60, 75000, "D", 48, true, "commis une atteinte sexuelle avec violence, contrainte, menace ou surprise"],
	["viol", "Viol", "personnes", "Art. 222-23 C. pén.", 180, 0, "X", 48, true, "commis un acte de pénétration sexuelle par violence, contrainte, menace ou surprise"],
	["exhibition", "Exhibition sexuelle", "personnes", "Art. 222-32 C. pén.", 12, 15000, "D", 24, true, "imposé une exhibition sexuelle à la vue d'autrui"],
	["sequestration", "Séquestration / enlèvement", "personnes", "Art. 224-1 C. pén.", 240, 0, "X", 48, true, "arrêté, enlevé, détenu ou séquestré une personne sans ordre des autorités"],
	["mise_danger", "Mise en danger de la vie d'autrui", "personnes", "Art. 223-1 C. pén.", 12, 15000, "D", 24, false, "exposé directement autrui à un risque immédiat de mort ou de blessures graves"],
	["non_assistance", "Non-assistance à personne en danger", "personnes", "Art. 223-6 C. pén.", 60, 75000, "D", 24, true, "volontairement omis de porter assistance à une personne en péril"],
	["atteinte_vie_privee", "Atteinte à l'intimité de la vie privée", "personnes", "Art. 226-1 C. pén.", 12, 45000, "D", 24, true, "capté et diffusé sans consentement des images d'une personne dans un lieu privé"],
	["diffamation", "Diffamation publique", "personnes", "Loi du 29/07/1881, art. 32", 0, 12000, "D", 0, true, "publiquement allégué un fait portant atteinte à l'honneur d'autrui"],
	["injure_publique", "Injure publique", "personnes", "Loi du 29/07/1881, art. 33", 0, 12000, "D", 0, true, "publiquement proféré une expression outrageante envers autrui"],
	["injure_raciste", "Injure publique à caractère raciste", "personnes", "Loi du 29/07/1881, art. 33 al. 3", 12, 45000, "D", 24, true, "publiquement injurié une personne à raison de son origine"],
	["abandon_famille", "Abandon de famille (pension impayée)", "personnes", "Art. 227-3 C. pén.", 24, 15000, "D", 24, true, "omis de verser pendant plus de deux mois la pension alimentaire due"],
	["non_representation", "Non-représentation d'enfant", "personnes", "Art. 227-5 C. pén.", 12, 15000, "D", 24, true, "refusé indûment de représenter un enfant mineur à la personne en droit de le réclamer"],
	["denonciation_calomnieuse", "Dénonciation calomnieuse", "personnes", "Art. 226-10 C. pén.", 60, 45000, "D", 24, true, "dénoncé aux autorités un fait que l'on savait totalement inexact"],

	# ── Atteintes aux biens ───────────────────────────────────────────────────
	["vol_simple", "Vol simple", "biens", "Art. 311-3 C. pén.", 36, 45000, "D", 24, true, "frauduleusement soustrait un bien appartenant à autrui"],
	["vol_aggrave", "Vol aggravé (en réunion, dans un transport…)", "biens", "Art. 311-4 C. pén.", 60, 75000, "D", 48, true, "frauduleusement soustrait un bien d'autrui avec circonstances aggravantes"],
	["vol_etalage", "Vol à l'étalage", "biens", "Art. 311-3 C. pén.", 36, 45000, "D", 24, true, "soustrait frauduleusement des marchandises dans un commerce"],
	["vol_violence", "Vol avec violence (ITT ≤ 8 jours)", "biens", "Art. 311-4 4° C. pén.", 60, 75000, "D", 48, true, "frauduleusement soustrait le bien d'autrui en usant de violences"],
	["vol_violence_itt", "Vol avec violences (ITT > 8 jours)", "biens", "Art. 311-5 C. pén.", 84, 100000, "D", 48, true, "frauduleusement soustrait le bien d'autrui avec violences ayant entraîné une ITT supérieure à huit jours"],
	["vol_arrache", "Vol à l'arraché", "biens", "Art. 311-4 C. pén.", 60, 75000, "D", 48, true, "arraché le bien d'autrui sur la voie publique"],
	["cambriolage", "Cambriolage (vol dans un local d'habitation)", "biens", "Art. 311-4 6° C. pén.", 60, 75000, "D", 48, true, "soustrait frauduleusement des biens après s'être introduit dans un local d'habitation"],
	["vol_main_armee", "Vol à main armée", "biens", "Art. 311-8 C. pén.", 240, 150000, "X", 96, true, "commis un vol avec usage ou menace d'une arme"],
	["vol_vehicule", "Vol de véhicule", "biens", "Art. 311-3 C. pén.", 36, 45000, "D", 24, true, "frauduleusement soustrait un véhicule appartenant à autrui"],
	["recel", "Recel", "biens", "Art. 321-1 C. pén.", 60, 375000, "D", 48, false, "sciemment détenu une chose provenant d'un crime ou d'un délit"],
	["escroquerie", "Escroquerie", "biens", "Art. 313-1 C. pén.", 60, 375000, "D", 48, true, "trompé une personne par des manœuvres frauduleuses pour obtenir la remise de fonds"],
	["abus_confiance", "Abus de confiance", "biens", "Art. 314-1 C. pén.", 60, 375000, "D", 48, true, "détourné des fonds ou biens qui avaient été remis à charge de les rendre"],
	["extorsion", "Extorsion", "biens", "Art. 312-1 C. pén.", 84, 100000, "D", 48, true, "obtenu par violence ou menace la remise de fonds"],
	["chantage", "Chantage", "biens", "Art. 312-10 C. pén.", 60, 75000, "D", 24, true, "obtenu une remise de fonds en menaçant de révéler des faits portant atteinte à l'honneur"],
	["degradation", "Destruction ou dégradation du bien d'autrui", "biens", "Art. 322-1 C. pén.", 24, 30000, "D", 24, true, "détruit, dégradé ou détérioré un bien appartenant à autrui"],
	["tags", "Tags / graffitis", "biens", "Art. 322-1 al. 2 C. pén.", 0, 3750, "D", 0, true, "tracé des inscriptions sans autorisation sur les façades"],
	["incendie_volontaire", "Incendie volontaire", "biens", "Art. 322-6 C. pén.", 120, 150000, "D", 48, true, "volontairement détruit le bien d'autrui par l'effet d'un incendie"],
	["incendie_habitation", "Incendie d'un lieu d'habitation", "biens", "Art. 322-8 C. pén.", 240, 150000, "X", 48, true, "volontairement incendié un immeuble d'habitation"],
	["violation_domicile", "Violation de domicile / squat", "biens", "Art. 226-4 C. pén.", 36, 45000, "D", 24, true, "s'être introduit et maintenu dans le domicile d'autrui"],
	["filouterie", "Filouterie (grivèlerie)", "biens", "Art. 313-5 C. pén.", 6, 7500, "D", 24, true, "consommé dans un restaurant en se sachant dans l'impossibilité absolue de payer"],
	["fraude_transport", "Fraude habituelle dans les transports", "biens", "Art. L2242-6 C. transports", 6, 7500, "D", 24, false, "voyagé de manière habituelle sans titre de transport"],

	# ── Stupéfiants ───────────────────────────────────────────────────────────
	["usage_stup", "Usage de stupéfiants", "stup", "Art. L3421-1 C. santé publ.", 12, 3750, "D", 24, false, "fait usage illicite de substances classées comme stupéfiants"],
	["detention_stup", "Détention de stupéfiants", "stup", "Art. 222-37 C. pén.", 120, 7500000, "D", 96, false, "détenu illicitement des produits stupéfiants"],
	["cession_stup", "Offre ou cession pour usage personnel", "stup", "Art. 222-39 C. pén.", 60, 75000, "D", 96, false, "cédé illicitement des stupéfiants à une personne en vue de sa consommation personnelle"],
	["trafic_stup", "Trafic de stupéfiants (transport, offre, acquisition)", "stup", "Art. 222-37 C. pén.", 120, 7500000, "D", 96, false, "transporté, offert, cédé et acquis illicitement des produits stupéfiants"],
	["importation_stup", "Importation de stupéfiants", "stup", "Art. 222-36 C. pén.", 120, 7500000, "D", 96, false, "importé illicitement des produits stupéfiants"],
	["importation_bo", "Importation de stupéfiants en bande organisée", "stup", "Art. 222-36 al. 2 C. pén.", 360, 7500000, "X", 96, false, "importé des stupéfiants en bande organisée"],
	["direction_reseau", "Direction d'un réseau de trafic", "stup", "Art. 222-34 C. pén.", PERPETUITE, 7500000, "X", 96, false, "dirigé ou organisé un groupement ayant pour objet le trafic de stupéfiants"],
	["provocation_usage", "Provocation à l'usage de stupéfiants", "stup", "Art. L3421-4 C. santé publ.", 60, 75000, "D", 24, false, "provoqué à l'usage de produits stupéfiants"],
	["blanchiment_stup", "Blanchiment du trafic de stupéfiants", "stup", "Art. 222-38 C. pén.", 120, 750000, "D", 96, false, "facilité la justification mensongère de l'origine de fonds issus du trafic"],

	# ── Sécurité routière ─────────────────────────────────────────────────────
	["sans_permis", "Conduite sans permis", "route", "Art. L221-2 C. route", 12, 15000, "D", 24, false, "conduit un véhicule sans être titulaire du permis correspondant"],
	["alcool_volant", "Conduite en état alcoolique", "route", "Art. L234-1 C. route", 24, 4500, "D", 24, false, "conduit un véhicule sous l'empire d'un état alcoolique"],
	["stup_volant", "Conduite après usage de stupéfiants", "route", "Art. L235-1 C. route", 24, 4500, "D", 24, false, "conduit un véhicule après avoir fait usage de stupéfiants"],
	["alcool_stup_volant", "Conduite sous alcool et stupéfiants", "route", "Art. L235-1 al. 2 C. route", 36, 9000, "D", 24, false, "conduit en ayant fait usage de stupéfiants et sous l'empire d'un état alcoolique"],
	["delit_fuite", "Délit de fuite", "route", "Art. 434-10 C. pén.", 36, 75000, "D", 24, true, "omis de s'arrêter après avoir causé un accident pour échapper à sa responsabilité"],
	["refus_obtemperer", "Refus d'obtempérer", "route", "Art. L233-1 C. route", 24, 15000, "D", 24, false, "omis d'obtempérer à une sommation de s'arrêter"],
	["refus_obtemperer_aggrave", "Refus d'obtempérer aggravé (mise en danger)", "route", "Art. L233-1-1 C. route", 60, 75000, "D", 48, false, "refusé d'obtempérer en exposant autrui à un risque de mort"],
	["exces_vitesse_recidive", "Grand excès de vitesse en récidive (≥ 50 km/h)", "route", "Art. L413-1 C. route", 3, 3750, "D", 24, false, "dépassé de 50 km/h ou plus la vitesse maximale autorisée, en état de récidive"],
	["sans_assurance", "Conduite sans assurance", "route", "Art. L324-2 C. route", 0, 3750, "D", 0, false, "mis en circulation un véhicule sans être couvert par une assurance"],
	["refus_depistage", "Refus de se soumettre au dépistage", "route", "Art. L234-8 C. route", 24, 4500, "D", 24, false, "refusé de se soumettre aux vérifications de l'état alcoolique"],
	["rodeo", "Rodéo motorisé", "route", "Art. L236-1 C. route", 12, 15000, "D", 24, false, "adopté une conduite répétant des manœuvres compromettant la sécurité des usagers"],
	["fausses_plaques", "Usurpation de plaques d'immatriculation", "route", "Art. L317-4-1 C. route", 84, 30000, "D", 24, false, "mis en circulation un véhicule muni de plaques attribuées à un autre véhicule"],
	["homicide_routier", "Homicide routier", "route", "Art. 221-18 C. pén.", 84, 100000, "D", 48, true, "causé la mort d'autrui à l'occasion de la conduite d'un véhicule"],
	["blessures_routieres", "Blessures routières", "route", "Art. 222-19-1 C. pén.", 36, 45000, "D", 24, true, "causé des blessures à autrui à l'occasion de la conduite d'un véhicule"],
	["conduite_suspendu", "Conduite malgré suspension de permis", "route", "Art. L224-16 C. route", 24, 4500, "D", 24, false, "conduit malgré une suspension du permis de conduire"],

	# ── Autorité & ordre public ───────────────────────────────────────────────
	["outrage_agent", "Outrage à personne dépositaire de l'autorité publique", "autorite", "Art. 433-5 C. pén.", 12, 15000, "D", 24, true, "outragé par paroles un fonctionnaire de police dans l'exercice de ses fonctions"],
	["rebellion", "Rébellion", "autorite", "Art. 433-6 C. pén.", 24, 30000, "D", 24, false, "opposé une résistance violente à des agents agissant pour l'exécution des lois"],
	["violences_policier", "Violences sur personne dépositaire de l'autorité publique", "autorite", "Art. 222-14-5 C. pén.", 60, 75000, "D", 48, true, "commis des violences volontaires sur un fonctionnaire de la police nationale"],
	["attroupement", "Participation à un attroupement après sommation", "autorite", "Art. 431-4 C. pén.", 12, 15000, "D", 24, false, "continué volontairement à participer à un attroupement après les sommations"],
	["groupement_violences", "Participation à un groupement en vue de violences", "autorite", "Art. 222-14-2 C. pén.", 12, 15000, "D", 24, false, "participé sciemment à un groupement en vue de commettre des violences"],
	["faux_usage", "Faux et usage de faux", "autorite", "Art. 441-1 C. pén.", 36, 45000, "D", 24, false, "altéré frauduleusement un document et fait usage de ce faux"],
	["faux_document_admin", "Faux document administratif", "autorite", "Art. 441-2 C. pén.", 60, 75000, "D", 48, false, "fabriqué un faux document délivré par une administration publique"],
	["usurpation_identite", "Usurpation d'identité", "autorite", "Art. 226-4-1 C. pén.", 12, 15000, "D", 24, true, "fait usage de l'identité d'un tiers en vue de troubler sa tranquillité"],
	["faux_temoignage", "Faux témoignage", "autorite", "Art. 434-13 C. pén.", 60, 75000, "D", 24, false, "fait un témoignage mensonger sous serment"],
	["evasion", "Évasion", "autorite", "Art. 434-27 C. pén.", 36, 45000, "D", 48, false, "s'être soustrait à la garde à laquelle il était soumis"],
	["corruption", "Corruption active d'agent public", "autorite", "Art. 433-1 C. pén.", 120, 1000000, "D", 96, false, "proposé des avantages à une personne dépositaire de l'autorité publique"],
	["apologie_terrorisme", "Apologie du terrorisme (en ligne)", "autorite", "Art. 421-2-5 C. pén.", 84, 100000, "D", 144, false, "fait publiquement l'apologie d'actes de terrorisme via un service en ligne"],
	["intrusion_scolaire", "Intrusion dans un établissement scolaire", "autorite", "Art. 431-22 C. pén.", 12, 7500, "D", 24, false, "pénétré sans autorisation dans un établissement scolaire"],
	["entrave_secours", "Entrave à l'arrivée des secours", "autorite", "Art. 223-5 C. pén.", 84, 100000, "D", 24, false, "volontairement entravé l'arrivée de secours destinés à faire échapper une personne à un péril"],
	["violation_controle_judiciaire", "Violation d'une interdiction judiciaire", "autorite", "Art. 434-41 C. pén.", 24, 30000, "D", 24, false, "violé les obligations ou interdictions résultant d'une décision judiciaire"],

	# ── Cybercriminalité ──────────────────────────────────────────────────────
	["acces_stad", "Accès frauduleux à un système informatique", "numerique", "Art. 323-1 C. pén.", 36, 100000, "D", 24, true, "accédé frauduleusement à tout ou partie d'un système de traitement automatisé de données"],
	["entrave_stad", "Entrave à un système informatique (ransomware, DDoS)", "numerique", "Art. 323-2 C. pén.", 60, 150000, "D", 48, true, "entravé ou faussé le fonctionnement d'un système de traitement automatisé de données"],
	["extraction_donnees", "Extraction frauduleuse de données", "numerique", "Art. 323-3 C. pén.", 60, 150000, "D", 48, true, "frauduleusement extrait et transmis des données d'un système informatique"],
	["phishing", "Escroquerie en ligne (hameçonnage)", "numerique", "Art. 313-1 C. pén.", 60, 375000, "D", 48, true, "obtenu des identifiants bancaires au moyen de faux messages électroniques"],
	["cyberharcelement", "Cyberharcèlement", "numerique", "Art. 222-33-2-2 4° C. pén.", 24, 30000, "D", 24, true, "harcelé une personne par l'utilisation d'un service de communication en ligne"],
	["revenge_porn", "Diffusion d'images intimes sans consentement", "numerique", "Art. 226-2-1 C. pén.", 24, 60000, "D", 24, true, "diffusé sans son accord des images à caractère sexuel d'une personne"],
	["deepfake", "Diffusion d'un hypertrucage (deepfake)", "numerique", "Art. 226-8 C. pén.", 24, 45000, "D", 24, true, "diffusé un contenu visuel généré par traitement algorithmique représentant une personne sans son consentement"],
	["contrefacon", "Contrefaçon / piratage d'œuvres", "numerique", "Art. L335-2 C. propr. intell.", 36, 300000, "D", 24, false, "reproduit et diffusé des œuvres protégées en violation des droits d'auteur"],
	["fraude_cb", "Fraude à la carte bancaire", "numerique", "Art. L163-4 C. monét. fin.", 84, 750000, "D", 48, true, "fait usage de données de cartes de paiement contrefaites"],
	["sextorsion", "Sextorsion", "numerique", "Art. 312-10 C. pén.", 60, 75000, "D", 24, true, "menacé de diffuser des images intimes afin d'obtenir une remise de fonds"],

	# ── Économique & financier ────────────────────────────────────────────────
	["blanchiment", "Blanchiment", "eco", "Art. 324-1 C. pén.", 60, 375000, "D", 48, false, "facilité la justification mensongère de l'origine de biens issus d'un délit"],
	["fraude_fiscale", "Fraude fiscale", "eco", "Art. 1741 C. gén. impôts", 60, 500000, "D", 48, false, "frauduleusement soustrait à l'établissement et au paiement de l'impôt"],
	["abs", "Abus de biens sociaux", "eco", "Art. L241-3 C. com.", 60, 375000, "D", 48, false, "fait de mauvaise foi des biens de la société un usage contraire à son intérêt"],
	["travail_dissimule", "Travail dissimulé", "eco", "Art. L8224-1 C. trav.", 36, 45000, "D", 24, false, "exercé une activité en se soustrayant intentionnellement aux déclarations obligatoires"],
	["delit_initie", "Délit d'initié", "eco", "Art. L465-1 C. monét. fin.", 60, 100000000, "D", 48, false, "réalisé des opérations boursières en faisant usage d'une information privilégiée"],
	["banqueroute", "Banqueroute", "eco", "Art. L654-2 C. com.", 60, 75000, "D", 24, false, "détourné l'actif d'une société en procédure collective"],
	["prise_interets", "Prise illégale d'intérêts", "eco", "Art. 432-12 C. pén.", 60, 500000, "D", 48, false, "pris un intérêt dans une opération dont il avait la charge d'assurer la surveillance"],
	["corruption_passive", "Corruption passive", "eco", "Art. 432-11 C. pén.", 120, 1000000, "D", 96, false, "sollicité des avantages pour accomplir un acte de sa fonction"],
	["fraude_sociale", "Fraude aux prestations sociales", "eco", "Art. 441-6 C. pén.", 24, 30000, "D", 24, false, "fourni de fausses déclarations en vue d'obtenir des prestations indues"],
	["contrebande_tabac", "Contrebande de tabac", "eco", "Art. 414 C. douanes", 36, 150000, "D", 96, false, "détenu et transporté du tabac de contrebande"],
	["fausse_monnaie", "Fausse monnaie", "eco", "Art. 442-1 C. pén.", 360, 450000, "X", 96, false, "contrefait des billets de banque ayant cours légal"],

	# ── Armes & crime organisé ────────────────────────────────────────────────
	["port_arme", "Port d'arme prohibé (catégorie D)", "organise", "Art. L317-8 C. séc. int.", 12, 15000, "D", 24, false, "porté sans motif légitime une arme de catégorie D"],
	["detention_arme_b", "Détention illégale d'arme (catégorie B)", "organise", "Art. L317-5 C. séc. int.", 60, 75000, "D", 48, false, "acquis et détenu sans autorisation une arme de catégorie B"],
	["trafic_armes", "Trafic d'armes", "organise", "Art. L317-4 C. séc. int.", 120, 500000, "D", 96, false, "cédé et vendu illégalement des armes à feu"],
	["association_malfaiteurs", "Association de malfaiteurs", "organise", "Art. 450-1 C. pén.", 120, 150000, "D", 96, false, "participé à un groupement formé en vue de la préparation de délits"],
	["amt", "Association de malfaiteurs terroriste", "organise", "Art. 421-2-1 C. pén.", 120, 225000, "D", 144, false, "participé à un groupement formé en vue de la préparation d'actes de terrorisme"],
	["explosif", "Fabrication d'engin explosif", "organise", "Art. 322-11-1 C. pén.", 60, 75000, "D", 96, false, "détenu et fabriqué un engin explosif ou incendiaire"],
	["proxenetisme", "Proxénétisme", "organise", "Art. 225-5 C. pén.", 84, 150000, "D", 96, true, "aidé, assisté ou protégé la prostitution d'autrui et en avoir tiré profit"],
	["traite", "Traite des êtres humains", "organise", "Art. 225-4-1 C. pén.", 84, 150000, "D", 96, true, "recruté, transporté et hébergé une personne à des fins d'exploitation"],
	["aide_sejour", "Aide à l'entrée ou au séjour irrégulier", "organise", "Art. L823-1 CESEDA", 60, 30000, "D", 48, false, "facilité l'entrée ou le séjour irrégulier d'un étranger en France"],
	["bande_organisee_vol", "Vol en bande organisée", "organise", "Art. 311-9 C. pén.", 180, 150000, "X", 96, true, "commis un vol en bande organisée"],

	# ── Animaux & environnement ───────────────────────────────────────────────
	["cruaute_animal", "Sévices graves ou actes de cruauté envers un animal", "environnement", "Art. 521-1 C. pén.", 36, 45000, "D", 24, false, "exercé des sévices graves envers un animal domestique"],
	["abandon_animal", "Abandon d'animal", "environnement", "Art. 521-1 C. pén.", 36, 45000, "D", 24, false, "abandonné un animal domestique"],
	["braconnage", "Chasse de nuit avec engin motorisé (braconnage)", "environnement", "Art. L428-5 C. env.", 24, 4500, "D", 24, false, "chassé la nuit à l'aide d'un véhicule et d'engins prohibés"],
	["pollution_eaux", "Pollution des eaux", "environnement", "Art. L216-6 C. env.", 60, 1000000, "D", 24, false, "jeté ou déversé des substances nuisibles dans les eaux"],
	["dechets_dangereux", "Abandon de déchets dangereux", "environnement", "Art. L541-46 C. env.", 36, 150000, "D", 24, false, "abandonné ou déposé des déchets dangereux dans des conditions contraires à la loi"],
	["espece_protegee", "Destruction d'espèce protégée", "environnement", "Art. L415-3 C. env.", 36, 150000, "D", 24, false, "détruit des spécimens d'espèces animales protégées"],
	["incendie_foret", "Incendie de forêt involontaire", "environnement", "Art. 322-5 C. pén.", 24, 30000, "D", 24, false, "involontairement provoqué un incendie de bois et forêts"],

	# ── Contraventions ────────────────────────────────────────────────────────
	["exces_vitesse", "Excès de vitesse (< 20 km/h)", "contraventions", "Art. R413-14 C. route", 0, 750, "C", 0, false, "dépassé la vitesse maximale autorisée de moins de 20 km/h"],
	["grand_exces", "Grand excès de vitesse (≥ 50 km/h)", "contraventions", "Art. R413-14-1 C. route", 0, 1500, "C", 0, false, "dépassé de 50 km/h ou plus la vitesse maximale autorisée"],
	["feu_rouge", "Franchissement de feu rouge", "contraventions", "Art. R412-30 C. route", 0, 750, "C", 0, false, "franchi un feu de signalisation rouge"],
	["telephone_volant", "Téléphone tenu en main au volant", "contraventions", "Art. R412-6-1 C. route", 0, 750, "C", 0, false, "fait usage d'un téléphone tenu en main en conduisant"],
	["ivresse_publique", "Ivresse publique et manifeste", "contraventions", "Art. R3353-1 C. santé publ.", 0, 150, "C", 0, false, "été trouvé en état d'ivresse manifeste sur la voie publique"],
	["tapage", "Tapage nocturne", "contraventions", "Art. R623-2 C. pén.", 0, 450, "C", 0, false, "troublé la tranquillité d'autrui par des bruits nocturnes"],
	["violences_legeres", "Violences légères sans ITT", "contraventions", "Art. R624-1 C. pén.", 0, 750, "C", 0, true, "commis des violences légères n'ayant entraîné aucune incapacité"],
	["violences_itt_moins8", "Violences avec ITT ≤ 8 jours (sans aggravation)", "contraventions", "Art. R625-1 C. pén.", 0, 1500, "C", 0, true, "commis des violences ayant entraîné une ITT inférieure ou égale à huit jours"],
	["injure_non_publique", "Injure non publique", "contraventions", "Art. R621-2 C. pén.", 0, 38, "C", 0, true, "adressé une injure non publique à autrui"],
	["degradation_legere", "Dégradation légère", "contraventions", "Art. R635-1 C. pén.", 0, 1500, "C", 0, true, "causé un dommage léger au bien d'autrui"],
	["depot_dechets", "Dépôt sauvage de déchets", "contraventions", "Art. R635-8 C. pén.", 0, 1500, "C", 0, false, "déposé des déchets sur la voie publique à l'aide d'un véhicule"],
	["sans_titre", "Voyage sans titre de transport", "contraventions", "Art. R2241-1 C. transports", 0, 450, "C", 0, false, "voyagé sans titre de transport valable"],
	["ceinture", "Défaut de port de la ceinture", "contraventions", "Art. R412-1 C. route", 0, 750, "C", 0, false, "circulé sans être attaché par une ceinture de sécurité"],
	["stationnement_genant", "Stationnement très gênant", "contraventions", "Art. R417-11 C. route", 0, 750, "C", 0, false, "stationné un véhicule de manière très gênante"],
	["chien_dangereux", "Défaut de muselière (chien de catégorie)", "contraventions", "Art. R215-2 C. rural", 0, 750, "C", 0, false, "laissé circuler un chien de catégorie sans muselière"],
	["urine_voie", "Épanchement d'urine sur la voie publique", "contraventions", "Règlement sanitaire départemental", 0, 450, "C", 0, false, "uriné sur la voie publique"],
]

static var _cache: Array = []
static var _by_id: Dictionary = {}


static func all() -> Array:
	if _cache.is_empty():
		for r in RAW:
			var d := {
				"id": r[0], "name": r[1], "cat": r[2], "article": r[3],
				"prison": int(r[4]), "fine": int(r[5]), "kind": r[6],
				"gav": int(r[7]), "victim": bool(r[8]), "facts": r[9],
			}
			_cache.append(d)
			_by_id[d.id] = d
	return _cache


static func get_by_id(id: String) -> Dictionary:
	all()
	return _by_id.get(id, {})


static func category(id: String) -> Dictionary:
	for c in CATEGORIES:
		if c.id == id:
			return c
	return CATEGORIES[0]


static func count_in(cat_id: String) -> int:
	var n := 0
	for d in all():
		if d.cat == cat_id:
			n += 1
	return n


static func kind_label(kind: String) -> String:
	match kind:
		"X": return "CRIME"
		"D": return "DÉLIT"
		_: return "CONTRAVENTION"


static func kind_color(kind: String) -> Color:
	match kind:
		"X": return Color("e5484d")
		"D": return Color("f5a524")
		_: return Color("46a758")


static func prison_label(months: int) -> String:
	if months >= PERPETUITE:
		return "Perpétuité"
	if months <= 0:
		return "Pas de prison"
	if months < 12:
		return "%d mois" % months
	if months % 12 == 0:
		var y := months / 12
		return "%d an%s" % [y, "s" if y > 1 else ""]
	return "%d ans %d mois" % [months / 12, months % 12]


static func fine_label(eur: int) -> String:
	if eur <= 0:
		return "—"
	return format_eur(eur)


static func format_eur(eur: int) -> String:
	var s := str(eur)
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = " " + out
	return out + " €"
