class_name Texts
extends RefCounted
## All Hebrew text shown in the game, in one place.
## (To add English later: add a second dictionary and pick by language.)

const GAME_TITLE := "Spellmate"
const SUBTITLE := "מלחמת השמש והתהום"

const TEAM := { Chess.WHITE: "ממלכת השמש", Chess.BLACK: "ממלכת התהום" }

const CHARACTER := {
	Chess.WHITE: {
		Chess.Kind.KING: "מלך השמש",
		Chess.Kind.QUEEN: "כוהנת הזריחה",
		Chess.Kind.ROOK: "ענק השחר",
		Chess.Kind.BISHOP: "נזיר הקרן",
		Chess.Kind.KNIGHT: "קשת הלהבה",
		Chess.Kind.PAWN: "לגיונר השמש",
		Chess.Kind.MINER: "כורה הקריסטל",
	},
	Chess.BLACK: {
		Chess.Kind.KING: "אדון התהום",
		Chess.Kind.QUEEN: "מכשפת הריק",
		Chess.Kind.ROOK: "שומר הסדק",
		Chess.Kind.BISHOP: "כוהן הצללים",
		Chess.Kind.KNIGHT: "צלף התהום",
		Chess.Kind.PAWN: "חייל שלד",
		Chess.Kind.MINER: "חופר העצמות",
	},
}


static func character(kind: int, color: int) -> String:
	return CHARACTER[color][kind]


const ROLE := {
	Chess.Kind.KING: "מלך",
	Chess.Kind.QUEEN: "מלכה",
	Chess.Kind.ROOK: "צריח",
	Chess.Kind.BISHOP: "רץ",
	Chess.Kind.KNIGHT: "פרש",
	Chess.Kind.PAWN: "חייל",
	Chess.Kind.MINER: "כורה",
}

## How each unit type moves (shown on the character panel).
const MOVES := {
	"all": "זז לכל כיוון עד %d משבצות",
	"orth": "זז ישר (לא באלכסון) עד %d משבצות",
	"diag": "זז באלכסון עד %d משבצות",
	"knight": "קופץ בצורת L מעל הכול",
}

## Battle traits: [name, description]
const TRAIT := {
	"royal_armor": ["שריון מלכותי", "+15% הגנה בקרב. אם הוא נופל – המלחמה אבודה."],
	"arcane_strike": ["מכה קסומה", "+15% התקפה בקרב."],
	"stone_skin": ["עור אבן", "+20% הגנה בקרב."],
	"phase": ["חמקמק", "+5% התקפה והגנה. אם הוא מפסיד בהתקפה – הוא לא מת אלא חומק חזרה."],
	"charge": ["הסתערות", "+20% התקפה, אבל -10% בהגנה."],
	"phalanx": ["חומת מגנים", "+10% הגנה לכל חייל צמוד (עד 20%)."],
	"worker": ["עובד קשה", "מייצר אנרגיה בכל תור (+1, ועוד +1 על מכרה). חלש בקרב."],
}

## Lines that explain a win chance in the battle panel.
const ODDS_LINE := {
	"base": "יתרון התוקף",
	"phalanx": "חומת מגנים",
	"hill": "תוקף מגבעה",
	"forest": "מגן ביער",
	"castle": "מגן בטירה שלו",
	"brace": "מגן מורם",
	"frozen": "המגן קפוא",
}


static func odds_line(key: String) -> String:
	if ODDS_LINE.has(key):
		return ODDS_LINE[key]
	if key.begins_with("atk_") or key.begins_with("def_"):
		return TRAIT.get(key.substr(4), [key])[0]
	return key


const ABILITY_NAME := {
	"royal_decree": "צו מלכותי",
	"frost": "כישוף קרח",
	"stone_push": "הדיפת ענק",
	"swap": "שיגור חליפין",
	"fire_breath": "חץ בוער",
	"brace": "קיר מגנים",
	"toil": "משמרת כפולה",
}

const ABILITY_DESC := {
	"royal_decree": "יחידה ידידותית צמודה למלך מקבלת מגן: אי אפשר לתקוף אותה עד התור הבא שלך.",
	"frost": "יחידת אויב בטווח המלכה (לא מלך) קופאת: לא זזה ולא מפעילה כוח בתור הבא.",
	"stone_push": "דוחף יחידת אויב צמודה (לא מלך) משבצת אחת אחורה, אם יש לאן.",
	"swap": "מחליף מקום עם יחידה ידידותית (לא מלך) על משבצת באותו צבע, בכל מקום בשדה.",
	"fire_breath": "מצית משבצת ריקה צמודה ל-2 סבבים. אי אפשר לעבור דרך הלהבות.",
	"brace": "החייל מרים את המגן: +25% הגנה עד התור הבא שלך.",
	"toil": "במקום לזוז, הכורה עובד קשה ומוסיף 2 אנרגיה מיד.",
}

const TURN_OF := "תור %s"
const YOU := "התור שלך"
const AI_THINKING := "המחשב חושב..."
const ENEMY_POWER := "כוח של היריב"
const ENERGY := "אנרגיה"
const INCOME := "+%d בכל תור"
const COST := "עלות: %d"
const COOLDOWN := "מוכן בעוד %d תורות"
const READY := "מוכן!"
const FROZEN := "קפוא"
const SHIELDED := "מוגן"
const NOT_ENOUGH := "חסרה אנרגיה"
const NO_TARGETS := "אין מטרות כרגע"
const CANCEL := "ביטול"
const CHOOSE_TARGET := "בחר מטרה על הלוח"
const UNDO := "ביטול מהלך"
const MENU := "תפריט"
const NEW_GAME := "משחק חדש"
const START := "לקרב!"
const MODE_LOCAL := "שני שחקנים"
const MODE_AI := "נגד המחשב"
const POWERS_ON := "כוחות-על פעילים"
const LEVELS := ["שוליה", "אביר", "מלך"]
const LEVEL := "רמת קושי"
const CAPTURED := "הובסו: %d"
const BATTLE := "קרב!"
const WIN_CHANCE := "סיכוי ניצחון לתוקף"
const VICTORY := "ניצחון!"
const DEFEAT := "הפסד!"
const PHASED := "חמק!"
const KING_FELL := "המלך נפל!"
const ATTACK_HINT := "%d%% לנצח"
const UNITS_LEFT := "יחידות: %d"

const RESULT := {
	"king": "%s ניצחה! מלך היריב נפל",
	"turns": "תיקו - נגמרו התורות",
}
