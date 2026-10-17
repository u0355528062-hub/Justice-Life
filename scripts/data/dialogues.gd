class_name Dialogues
extends RefCounted
## Banque de répliques adaptées aux catégories d'infractions.

const EVIDENCE := {
	"personnes": ["La victime vous a formellement reconnu. Elle a été examinée aux urgences médico-judiciaires, il y a un certificat.",
		"Deux témoins décrivent précisément la scène. Leur description correspond à vous."],
	"biens": ["Les caméras de vidéoprotection vous filment sur place, à l'heure des faits.",
		"L'objet a été retrouvé lors de votre interpellation. Vos empreintes sont dessus."],
	"stup": ["Les produits ont été saisis sur vous. Il y a aussi votre téléphone, et ses messages.",
		"On a trouvé une balance de précision et des sachets conditionnés. Ça ne ressemble pas à de la consommation."],
	"route": ["Le dépistage est positif et l'éthylomètre a confirmé. Les collègues vous ont suivi sur deux kilomètres.",
		"Le radar et la vidéo embarquée ne laissent pas beaucoup de place au doute."],
	"autorite": ["Trois fonctionnaires ont rédigé des procès-verbaux concordants. Il y a aussi les images des caméras-piétons.",
		"La scène a été filmée par un passant. On l'a récupérée."],
	"numerique": ["Les réquisitions auprès de l'opérateur rattachent l'adresse IP à votre domicile, et à votre téléphone.",
		"Votre ordinateur a été saisi. L'expertise est en cours, mais les premiers résultats sont parlants."],
	"eco": ["Les relevés bancaires montrent une série de virements vers des comptes que vous contrôlez.",
		"Le comptable de la société a été entendu. Il dit que vous donniez les instructions."],
	"organise": ["Vous apparaissez sur plusieurs semaines d'interceptions téléphoniques.",
		"La géolocalisation de votre véhicule vous place à chaque rendez-vous."],
	"environnement": ["Des photographies horodatées et le témoignage d'un agent de l'OFB vous mettent en cause.",
		"Un voisin a filmé la scène. On vous reconnaît clairement."],
	"contraventions": ["Les agents ont constaté l'infraction directement.",
		"C'est consigné dans le procès-verbal de constatation."],
}

const MINIMIZE := {
	"personnes": "Il m'a provoqué. Je me suis défendu, c'est tout.",
	"biens": "J'avais besoin d'argent… Je comptais rembourser.",
	"stup": "C'est pour ma consommation personnelle, rien de plus.",
	"route": "J'avais un peu bu, mais je me sentais capable de conduire.",
	"autorite": "Ce sont eux qui m'ont mal parlé en premier.",
	"numerique": "C'était une blague. Je ne pensais pas que ça irait aussi loin.",
	"eco": "C'est une erreur de gestion, pas une fraude.",
	"organise": "Je rendais service à quelqu'un. Je ne savais pas tout.",
	"environnement": "Je ne savais pas que c'était interdit.",
	"contraventions": "Je n'ai pas fait attention. C'était exceptionnel.",
}

const OPJ_ON_ADMIT := ["C'est noté. Ça vous honore de le reconnaître.", "D'accord. Je l'écris tel quel.",
	"Bien. On avance."]
const OPJ_ON_DENY := ["Vous êtes sûr ? Parce que ce n'est pas ce que dit le dossier.", "Je note que vous contestez.",
	"Comme vous voulez. Le procureur appréciera."]
const OPJ_ON_SILENCE := ["C'est votre droit. Je note : « ne souhaite pas répondre ».", "Très bien. Silence.",
	"Je l'inscris au procès-verbal."]
const OPJ_ON_MINIMIZE := ["Hm. Donc vous reconnaissez une partie des faits, si je comprends bien.",
	"Je note votre version."]


static func evidence_line(cat: String) -> String:
	var l: Array = EVIDENCE.get(cat, EVIDENCE["contraventions"])
	return l[randi() % l.size()]


static func minimize_line(cat: String) -> String:
	return MINIMIZE.get(cat, MINIMIZE["contraventions"])


static func pick(arr: Array) -> String:
	return arr[randi() % arr.size()]
