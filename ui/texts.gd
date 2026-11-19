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
	Chess.Kind.QUEEN: "המכשפה הגדולה",
	Chess.Kind.MINER: "הכורה",
	Chess.Kind.PAWN: "החייל",
	Chess.Kind.ARCHER: "הקשת",
	Chess.Kind.SHIELD: "אביר המגן",
	Chess.Kind.KNIGHT: "הפרש",
	Chess.Kind.HEALER: "המרפאה",
	Chess.Kind.ICE_WITCH: "מכשפת הקרח",
	Chess.Kind.FIRE_MAGE: "קוסם האש",
	Chess.Kind.ASSASSIN: "המתנקש",
	Chess.Kind.GIANT: "הענק",
	Chess.Kind.BALLISTA: "הבליסטרה",
	Chess.Kind.DRAGON: "הדרקון",
}


static func character(kind: int, color: int) -> String:
	return CHARACTER[kind]




## Special traits: [name, description]
const TRAIT := {
	"royal": ["המלך", "יושב בארמון ולא יוצא ממנו. אם הוא נופל - המלחמה אבודה."],
	"sorceress": ["קוסמת", "תוקפת מרחוק (3 משבצות)."],
	"worker": ["עובד קשה", "מייצר אנרגיה בכל תור (+1, ו-+2 נוספים על מכרה קריסטל)."],
	"phalanx": ["חומת מגנים", "+1 שריון לכל חייל צמוד."],
	"ranged": ["יורה מרחוק", "תוקף מ-3 משבצות. יחידות קרובות לא יכולות להחזיר לו."],
	"bulwark": ["מגן כבד", "הרבה חיים ושריון חזק."],
	"charge": ["הסתערות", "+3 נזק אם עבר 3 משבצות או יותר לפני ההתקפה."],
	"mender": ["מרפאה", "מרפאה יחידות ידידותיות צמודות."],
	"chill": ["מגע קר", "מי שהיא פוגעת בו מואט בתור הבא (2 צעדים פחות)."],
	"blast": ["פיצוץ", "פוגע גם בכל האויבים שצמודים למטרה (חצי נזק)."],
	"shadow": ["צל", "עובר ביער בלי להאט. +50% נזק נגד יורים, קוסמים ותומכים."],
	"siege": ["הורס חומות", "נזק כפול לשערים ולמגדלים."],
	"artillery": ["ארטילריה", "טווח 5, נזק כפול לשערים ולמגדלים. לא יורה בתור שבו זז."],
	"flying": ["עף", "עובר מעל נהרות וחומות."],
}



const ABILITY_NAME := {
	"royal_decree": "צו מלכותי",
	"frost": "סערת קרח",
	"stone_push": "הדיפת ענק",
	"swap": "שיגור חליפין",
	"fire_breath": "סופת אש",
	"brace": "קיר מגנים",
	"toil": "משמרת כפולה",
	"heal": "אור מרפא",
}

const ABILITY_DESC := {
	"royal_decree": "כל היחידות הידידותיות סביב המלך מקבלות מגן: אי אפשר לתקוף אותן עד התור הבא שלך.",
	"frost": "יחידת אויב בטווח וכל האויבים שסביבה נפגעים מקרח וקופאים לתור אחד (לא מלכים).",
	"fire_breath": "הדרקון נושף אש על משבצת צמודה ועל המשבצות סביבה: נזק מיד, ואש שבוערת 2 סבבים.",
	"brace": "החייל וכל החיילים הצמודים אליו מרימים מגנים: +3 שריון עד התור הבא שלך.",
	"toil": "במקום לפעול, הכורה עובד קשה ומוסיף 3 אנרגיה מיד.",
	"heal": "מחזירה 6 חיים ליחידה ידידותית צמודה (או לעצמה).",
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

const END_TURN := "סיים תור"
const RECRUIT := "גיוס"
const HP := "חיים"
const ATK := "התקפה"
const DEF := "שריון"
const MOVE := "צעדים"
const RANGE := "טווח"
const PREVIEW := "נזק ~%d"
const PREVIEW_COUNTER := "מכה חוזרת ~%d"
const PREVIEW_KILL := "הורג!"
const PREVIEW_DIES := "תמות!"
const DONE := "סיים את התור שלו"
const BATTLE_SCENES := "סצנות קרב"
const SCENE_MODES := ["תמיד", "רק קרבות חשובים", "אף פעם"]
const GATE := "שער הארמון"
const TOWER := "מגדל שמירה"
const NO_SPAWN := "השער חסום"
const TURN_N := "תור %d"

const RESULT := {
	"king": "%s ניצחה! מלך היריב נפל",
	"turns": "תיקו - נגמרו התורות",
}
