# Justice Life

Simulation **3D à la première personne** d'un parcours judiciaire en France, faite avec **Godot 4.3+**.
Vous choisissez les infractions commises, puis vous vivez la procédure de l'intérieur :
commissariat, garde à vue, interrogatoires, transfert, procès, délibéré et, éventuellement, la prison.

> Prototype · **Étape 1** : tout le parcours fonctionne de bout en bout. La suite se construira petit à petit.

## Lancer le jeu

1. Installer [Godot 4.3 ou plus récent](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot → **Importer** → choisir `project.godot` dans ce dossier.
3. Appuyer sur **F5**.

Le rendu utilise **Forward+** (Vulkan) : une carte graphique récente est conseillée (SDFGI, brouillard volumétrique,
SSAO/SSIL, réflexions en espace écran, profondeur de champ).

## Commandes

| Touche | Action |
|---|---|
| Z Q S D / W A S D | Se déplacer |
| Souris | Regarder |
| E | Interagir |
| Espace / clic | Continuer un dialogue |
| 1 – 4 / clic | Choisir une réponse |
| Tab | Consulter son dossier (procès-verbal) |
| Échap | Pause (sensibilité, plein écran, quitter) |
| F9 | (test) accélérer le temps ×10 |
| F12 | Capture d'écran (`user://captures`) |

## Déroulé

1. **Constitution du dossier** — catalogue de **150+ infractions** classées en 10 catégories
   (personnes, biens, stupéfiants, route, autorité, cyber, économique, crime organisé, environnement,
   contraventions), avec article de loi, peine de prison et amende maximales. Recherche, filtres
   contravention / délit / crime, casier judiciaire, circonstances d'interpellation et aggravantes.
   Le panneau de droite calcule la qualification, la juridiction compétente, la peine encourue et la durée
   maximale de garde à vue.
2. **Chapitre I – L'interpellation** : arrivée de nuit sous la pluie, gyrophares, entrée dans l'hôtel de police,
   notification de la garde à vue et des droits (proche, médecin, avocat, silence), signature du PV,
   fouille (lacets, ceinture), signalisation (photos, empreintes).
3. **Chapitre II – La garde à vue** (**1 heure = 3 secondes**) : cellule vitrée, banc en béton, néon,
   voisins de cellule. Visite du médecin, entretien confidentiel de 30 min avec l'avocat, auditions avec l'OPJ
   (questions adaptées à chaque infraction : avouer, contester, se taire, minimiser), repas, prolongation
   par le procureur pour les faits graves, puis décision du parquet : classement sans suite, convocation,
   comparution immédiate, ou juge d'instruction et détention provisoire pour un crime.
   Les contraventions passent par une **audition libre** (pas de garde à vue possible).
4. **Chapitre III – Le transfert** en fourgon cellulaire.
5. **Chapitre IV – L'audience** devant la bonne juridiction (tribunal de police, tribunal correctionnel,
   cour criminelle départementale ou cour d'assises avec jurés) : identité, droit au délai en comparution
   immédiate, lecture des faits, questions du président et de l'assesseur, partie civile, réquisitions,
   plaidoirie, dernier mot, **délibéré** (attente tendue), verdict.
6. **Chapitre V – La détention** (**1 mois = 1 minute**) : une cellule de 9 m², calendrier, bâtonnets
   au mur, lumière du jour qui tourne, courrier, fouilles, travail, formation, incidents, réductions de peine
   annuelles selon la conduite, libération conditionnelle à mi-peine, levée d'écrou.

Tout ce que vous dites est consigné : aveux, dénégations, silences, contradictions entre la garde à vue et
l'audience, attitude, avocat, situation personnelle et casier influencent les réquisitions et la peine.

## Graphismes et personnages

Tout est généré par le code, **sans aucun fichier 3D** : surfaces PBR procédurales (carrelage, béton, bois,
lambris, lino, asphalte mouillé, métal brossé) via `shaders/surface.gdshader`, éclairage dynamique, ombres
douces, brouillard volumétrique, bloom, vignettage et grain de film. Les sons (néons, ventilation, pluie,
portes, verrous, cœur, marteau du juge…) sont aussi synthétisés au lancement.

Les personnages procéduraux respirent, clignent des yeux, vous suivent du regard, parlent, marchent,
s'assoient et se lèvent. **Pour des humains réalistes**, il suffit de déposer des modèles riggés au format
`.glb` dans `assets/characters/` avec le nom du rôle — ils remplacent automatiquement les modèles
procéduraux (animations `idle`, `walk`, `talk` jouées si présentes) :

| Fichier | Rôle |
|---|---|
| `police.glb` | policiers en uniforme |
| `opj.glb` | officier de police judiciaire (civil + brassard) |
| `avocat.glb` | avocat·e |
| `magistrat.glb` | président·e, assesseurs, greffier |
| `procureur.glb` | ministère public |
| `surveillant.glb` | surveillant pénitentiaire |
| `medecin.glb` | médecin |
| `public.glb`, `jure.glb`, `famille.glb`, `victime.glb`, `detenu.glb` | autres personnages |

## Structure

```
project.godot
scenes/                 scènes minimales (la construction est faite en code)
scripts/autoload/       GameState (dossier, horloge), Sfx (audio), Transition, Devtools
scripts/data/           catalogue d'infractions, répliques
scripts/core/           calcul des peines, kit d'interface
scripts/world/          constructeur de décors, matériaux, joueur, personnages
scripts/ui/hud.gd       interface en jeu (dialogues, horloge, minuteurs, dossier, pause)
scripts/scenes/         menu, dossier, commissariat, transfert, tribunal, prison, fin
shaders/                surfaces procédurales, vignettage, grain
```

## Tests automatisés

Le jeu peut se jouer tout seul (choix automatiques, temps accéléré) pour vérifier le parcours :

```
godot --path . -- --jl-scene=commissariat --jl-preset=delit --jl-autoplay --jl-policy=random --jl-speed=40 --jl-quit=300
```

Préréglages : `contravention`, `delit`, `crime`, `lourd`. Ajouter `--jl-shots=/dossier --jl-every=5` pour des captures.

---

Simulation à visée immersive et pédagogique : peines et procédures sont simplifiées et ne constituent pas
un conseil juridique. Polices : Inter, Playfair Display, JetBrains Mono (SIL Open Font License).
