class_name Texts
extends RefCounted
## All Hebrew text shown in the game, in one place.
## (To add English later: add a second dictionary and pick by language.)

const GAME_TITLE := "Spellmate"
const SUBTITLE := "מלחמת השמש והתהום"

const TEAM := { Chess.WHITE: "ממלכת השמש", Chess.BLACK: "ממלכת התהום" }

## Both kingdoms field the same characters, in their own colours.
const CHARACTER := {
	Chess.Kind.KING: "המלך",
	Chess.Kind.QUEEN: "המכשפה",
	Chess.Kind.ROOK: "הענק",
	Chess.Kind.BISHOP: "הנזיר",
	Chess.Kind.KNIGHT: "הקשת",
	Chess.Kind.PAWN: "הלגיונר",
	Chess.Kind.MINER: "הכורה",
}


static func character(kind: int, color: int) -> String:
	return CHARACTER[kind]


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
	"frost": "סערת קרח",
	"stone_push": "הדיפת ענק",
	"swap": "שיגור חליפין",
	"fire_breath": "סופת אש",
	"brace": "קיר מגנים",
	"toil": "משמרת כפולה",
}

const ABILITY_DESC := {
	"royal_decree": "כל היחידות הידידותיות סביב המלך מקבלות מגן: אי אפשר לתקוף אותן עד התור הבא שלך.",
	"frost": "יחידת אויב בטווח המלכה וכל האויבים שסביבה קופאים לתור אחד (לא מלכים).",
	"stone_push": "הענק הודף יחידת אויב צמודה עד 2 משבצות אחורה, והיא המומה לתור אחד.",
	"swap": "מחליף מקום עם יחידה ידידותית על משבצת באותו צבע, והיא מגיעה עם מגן.",
	"fire_breath": "מצית משבצת ריקה צמודה ואת המשבצות סביבה ל-2 סבבים. אי אפשר לעבור דרך האש.",
	"brace": "החייל וכל החיילים הצמודים אליו מרימים מגנים: +25% הגנה עד התור הבא שלך.",
	"toil": "במקום לזוז, הכורה עובד קשה ומוסיף 3 אנרגיה מיד.",
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
const POWER := "כוח"
const SKIP := "דלג"
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
