class_name HeroTexts
extends RefCounted
## Hebrew names, descriptions and funny lines of the heroes, spells and powers.

const NAMES := {
	"king": "המלך", "queen": "המלכה", "miner": "כורה", "soldier": "חייל", "archer": "קשת",
	"shield": "שומר העצמות", "knight": "אביר", "healer": "מרפאה", "ice_witch": "מכשפת הקרח",
	"fire_mage": "קוסם האש", "assassin": "מתנקש הצללים", "giant": "ענק", "ballista": "בליסטרה",
	"dragon": "דרקון",
	"ice_bomb": "פצצת קרח", "fire_bomb": "פצצת אש", "heal_potion": "שיקוי ריפוי", "shield_wall": "חומת מגן",
}

const ROLES := {
	"king": "יושב בארמון. אם הוא נופל - הפסדת!",
	"queen": "קוסמת חזקה מרחוק, פוגעת בכמה אויבים יחד",
	"miner": "הולך לבד למכרה וחופר קריסטלים = אנרגיה",
	"soldier": "זול ואמיץ, טוב בהמון",
	"archer": "יורה מרחוק",
	"shield": "שלד ענק עם מגן. סופג מכות ומגן על החברים",
	"knight": "מהיר מאוד, מסתער על קשתים וקוסמים",
	"healer": "לא תוקפת - מרפאה את החברים",
	"ice_witch": "כל פגיעה שלה מאטה את האויב",
	"fire_mage": "כדורי אש שפוגעים בקבוצות",
	"assassin": "פוגע כפול באויב שעסוק במישהו אחר",
	"giant": "איטי וחזק מאוד. אוהב לשבור מגדלים ושערים",
	"ballista": "יורה רחוק מאוד, מעולה נגד מבנים",
	"dragon": "עף מעל חומות ומים ונושף אש",
	"ice_bomb": "מקפיא את כל מי שבאזור ל-3 שניות",
	"fire_bomb": "פיצוץ ענק ואש שבוערת עוד קצת",
	"heal_potion": "מרפא את כל החברים באזור",
	"shield_wall": "חומה זמנית שהאויבים לא יכולים לעבור",
}

const ABILITIES := {
	"royal_decree": ["צו מלכותי", "מגן זהב על כל מי שליד המלך"],
	"frost_nova": ["כוכב קרח", "פיצוץ קרח שמקפיא אויבים"],
	"rally": ["קריאת קרב", "החברים מסביב נכנסים לזעם: מכים חזק ורצים מהר"],
	"volley": ["מטח חצים", "גשם חצים על אזור"],
	"guard": ["חומת עצמות", "מגן על כל החברים מסביב"],
	"charge": ["הסתערות", "קופץ על אויב ומהמם אותו"],
	"mass_heal": ["ריפוי המוני", "מרפאה את כולם מסביב"],
	"blizzard": ["סופת שלג", "מאטה את כל האויבים באזור"],
	"meteor": ["מטאור", "סלע בוער נופל מהשמיים"],
	"shadow_strike": ["פגיעת צל", "נעלם ומופיע ליד האויב עם מכה ענקית"],
	"ground_smash": ["ריסוק אדמה", "מכה ברצפה ומהמם את כולם מסביב"],
	"piercing_bolt": ["חץ חודר", "חץ ענק שפוגע חזק במיוחד"],
	"fire_breath": ["נשימת אש", "גל אש ששורף את כולם"],
}

## Funny lines the characters say (shown in a speech bubble with a gibberish voice).
const LINES := {
	"king": ["מי העז לדפוק על השער שלי?!", "אני המלך! ...איפה הכתר שלי?", "שומרים! שומרים!!"],
	"queen": ["קר פה? זה בגללי.", "הכתר שלי יותר יפה משלו.", "אחד, שתיים, קפוא!"],
	"miner": ["קריסטל! עוד קריסטל!", "היי הו, היי הו!", "תנו לי רק לחפור…"],
	"soldier": ["כן המפקד!", "אני לא מפחד! …קצת.", "לתקוף!"],
	"archer": ["פספסתי בכוונה.", "חץ אחד, אויב אחד!", "תעמדו רגע בשקט…"],
	"shield": ["העצמות שלי חזקות!", "קדימה, תנסה להכות אותי.", "קרש-קרש-קרש"],
	"knight": ["הסוס שלי בחופש היום.", "להסתער!!!", "בשביל הכבוד!"],
	"healer": ["אל תדאגו, יש לי פלסטרים.", "מי עוד קיבל מכה?", "נשיקה וזה עובר!"],
	"ice_witch": ["ברררר…", "תתקררו קצת.", "שלג בקיץ!"],
	"fire_mage": ["חם, חם, חם!", "מישהו הזמין מנגל?", "הזקן שלי לא נשרף. עדיין."],
	"assassin": ["לא ראית אותי.", "ששש…", "מאחוריך!"],
	"giant": ["ענק רעב!", "בוםםם!", "מגדל = חטיף."],
	"ballista": ["טעון ומוכן!", "קליק… בום!", "מאיפה זה הגיע? ממני."],
	"dragon": ["רוווווארר!", "מי רוצה קלוי?", "אני רק דרקון קטן וחמוד."],
}


static func name_of(id: String) -> String:
	return NAMES.get(id, id)


static func role_of(id: String) -> String:
	return ROLES.get(id, "")


static func ability_name(ability_id: String) -> String:
	return ABILITIES.get(ability_id, [ability_id, ""])[0]


static func ability_desc(ability_id: String) -> String:
	return ABILITIES.get(ability_id, ["", ""])[1]


static func random_line(id: String) -> String:
	var l: Array = LINES.get(id, [])
	return "" if l.is_empty() else l[randi() % l.size()]
