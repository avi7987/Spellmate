class_name Texts
extends RefCounted
## All Hebrew text shown in the game, in one place.
## (To add English later: add a second dictionary and pick by language.)

const GAME_TITLE := "Spellmate"
const SUBTITLE := "שחמט של כישופים"

const TEAM := { Chess.WHITE: "ממלכת האור", Chess.BLACK: "ממלכת הצל" }

const CHARACTER := {
	Chess.WHITE: {
		Chess.Kind.KING: "המלך הזהוב",
		Chess.Kind.QUEEN: "המכשפה הגדולה",
		Chess.Kind.ROOK: "ענק ההרים",
		Chess.Kind.BISHOP: "הנזיר המסתורי",
		Chess.Kind.KNIGHT: "הצלף הבוער",
		Chess.Kind.PAWN: "נושא המגן",
	},
	Chess.BLACK: {
		Chess.Kind.KING: "מלך העצמות",
		Chess.Kind.QUEEN: "מכשפת הקבר",
		Chess.Kind.ROOK: "שומר הקבר",
		Chess.Kind.BISHOP: "כוהן הצללים",
		Chess.Kind.KNIGHT: "צלף המתים",
		Chess.Kind.PAWN: "חייל שלד",
	},
}


static func character(kind: int, color: int) -> String:
	return CHARACTER[color][kind]


const CHESS_ROLE := {
	Chess.Kind.KING: "מלך",
	Chess.Kind.QUEEN: "מלכה",
	Chess.Kind.ROOK: "צריח",
	Chess.Kind.BISHOP: "רץ",
	Chess.Kind.KNIGHT: "פרש",
	Chess.Kind.PAWN: "רגלי",
}

const ABILITY_NAME := {
	"royal_decree": "צו מלכותי",
	"frost": "כישוף קרח",
	"stone_push": "הדיפת ענק",
	"swap": "שיגור חליפין",
	"fire_breath": "חץ בוער",
	"charge": "הסתערות",
}

const ABILITY_DESC := {
	"royal_decree": "כלי ידידותי צמוד למלך מקבל מגן ולא ניתן להכות אותו עד התור הבא שלך.",
	"frost": "כלי אויב שהמלכה מאיימת עליו (לא מלך) קופא: לא זז ולא מפעיל כוח בתור הבא.",
	"stone_push": "דוחף כלי אויב צמוד (לא מלך) משבצת אחת אחורה, אם היא פנויה.",
	"swap": "מחליף מקום עם כלי ידידותי (לא מלך) על משבצת באותו צבע, בכל מקום בלוח.",
	"fire_breath": "מצית משבצת ריקה צמודה ל-2 סבבים. אי אפשר לעבור דרך הלהבות.",
	"charge": "הרגלי מתקדם 2 משבצות קדימה מכל מקום, בלי להכות.",
}

const TURN_OF := "תור %s"
const YOU := "התור שלך"
const AI_THINKING := "המחשב חושב..."
const CHECK := "שח!"
const CHECKMATE := "מט!"
const IN_CHECK_NO_POWER := "בשח אין כוחות"
const ENEMY_POWER := "כוח של היריב"
const ENERGY := "אנרגיה"
const COST := "עלות: %d"
const COOLDOWN := "מוכן בעוד %d תורות"
const READY := "מוכן!"
const FROZEN := "קפוא"
const SHIELDED := "מוגן"
const NOT_ENOUGH := "חסרה אנרגיה"
const NO_TARGETS := "אין מטרות כרגע"
const USE_POWER := "הפעל כוח"
const CANCEL := "ביטול"
const CHOOSE_TARGET := "בחר מטרה על הלוח"
const UNDO := "ביטול מהלך"
const MENU := "תפריט"
const NEW_GAME := "משחק חדש"
const START := "התחל!"
const MODE_LOCAL := "שני שחקנים"
const MODE_AI := "נגד המחשב"
const POWERS_ON := "כוחות-על פעילים"
const LEVELS := ["שוליה", "אביר", "מלך"]
const LEVEL := "רמת קושי"
const PROMOTE := "במה להכתיר את הרגלי?"
const CAPTURED := "הובסו: %d"

const RESULT := {
	"checkmate": "מט! %s ניצחה",
	"stalemate": "פט - תיקו",
	"fifty_moves": "תיקו - 50 מסעים בלי הכאה",
	"repetition": "תיקו - אותו מצב חזר 3 פעמים",
	"material": "תיקו - לא נשאר מספיק כוח למט",
}
