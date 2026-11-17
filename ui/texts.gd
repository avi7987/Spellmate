class_name Texts
extends RefCounted
## All Hebrew text shown in the game, in one place.
## (To add English later: add a second dictionary and pick by language.)

const GAME_TITLE := "Spellmate"
const SUBTITLE := "שחמט של כישופים"

const TEAM := { Chess.WHITE: "ממלכת האור", Chess.BLACK: "ממלכת הצל" }

const CHARACTER := {
	Chess.Kind.KING: "המלך הזהוב",
	Chess.Kind.QUEEN: "המכשפה הגדולה",
	Chess.Kind.ROOK: "גולם האבן",
	Chess.Kind.BISHOP: "הקוסם המסתורי",
	Chess.Kind.KNIGHT: "הדרקון הקטן",
	Chess.Kind.PAWN: "נושא המגן",
}

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
	"stone_push": "הדף אבן",
	"swap": "שיגור חליפין",
	"fire_breath": "נשיפת אש",
	"charge": "הסתערות",
}

const ABILITY_DESC := {
	"royal_decree": "כלי ידידותי צמוד למלך מקבל מגן ולא ניתן להכות אותו עד התור הבא שלך.",
	"frost": "כלי אויב שהמלכה מאיימת עליו (לא מלך) קופא: לא זז ולא מפעיל כוח בתור הבא.",
	"stone_push": "דוחף כלי אויב צמוד (לא מלך) משבצת אחת אחורה, אם היא פנויה.",
	"swap": "מחליף מקום עם כלי ידידותי (לא מלך) על משבצת באותו צבע, בכל מקום בלוח.",
	"fire_breath": "משבצת ריקה צמודה הופכת ללבה ל-2 סבבים. אף כלי לא נכנס אליה ולא עובר דרכה.",
	"charge": "הרגלי מתקדם 2 משבצות קדימה מכל מקום, בלי להכות.",
}

const TURN_OF := "התור של %s"
const YOU := "התור שלך"
const AI_THINKING := "המחשב חושב..."
const CHECK := "שח!"
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
