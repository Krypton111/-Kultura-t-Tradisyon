extends RefCounted
## Single source of truth for living-room heritage story content.
## Kept separate from scene input handling and dialogue orchestration.

const STORIES: Dictionary = {
	"FamilyPicture": {
		"title": "A Family Photograph",
		"migs": "Lola, who is in this family picture?",
		"lola": "That was one of our family gatherings. This picture keeps those happy moments close.",
		"entry": "Family photographs preserve loved ones, gatherings, and shared memories."
	},
	"LolaNenaPortrait": {
		"title": "A Face from the Past",
		"migs": "Lola, who is in this old portrait?",
		"lola": "Your great-grandmother. Her stories remind us of the people who came before us.",
		"entry": "Portraits preserve memories of earlier generations and the lives they lived."
	},
	"Salakot": {
		"title": "The Salakot",
		"migs": "What was the salakot used for, Lola?",
		"lola": "It helped protect farmers from the sun and rain. It was made for everyday work.",
		"entry": "The salakot reflects Filipino ingenuity and traditional everyday life."
	},
	"Books": {
		"title": "Books Full of Stories",
		"migs": "Why do you keep these old books?",
		"lola": "Books carry ideas, language, and memories from one generation to the next.",
		"entry": "Books preserve knowledge, language, and ideas across generations."
	},
	"Urn": {
		"title": "The Old Urn",
		"migs": "Do you know where this urn came from?",
		"lola": "It has been here for years. We should ask our elders before guessing its story.",
		"entry": "Record an object's history carefully, using reliable memories instead of guesses."
	},
	"Plants": {
		"title": "Lessons in the Garden",
		"migs": "Who taught you to care for plants, Lola?",
		"lola": "My mother did. I learned by watching her and caring for them every day.",
		"entry": "Plant care can preserve family routines and knowledge passed down over time."
	},
	"Plants3": {
		"title": "A Living Tradition",
		"migs": "Have we always kept plants at home?",
		"lola": "As long as I can remember. Caring for them taught us patience.",
		"entry": "Everyday habits can become traditions when families pass them on."
	},
	"Banig": {
		"title": "The Woven Banig",
		"migs": "Who makes a banig, Lola?",
		"lola": "Skilled weavers make these mats by hand. Their patterns and techniques deserve to be remembered.",
		"entry": "A banig preserves traditional weaving skills, patterns, and local craft knowledge."
	},
	"TableRadio": {
		"title": "Voices on the Radio",
		"migs": "Did you listen to this radio when you were young?",
		"lola": "We listened to news and music together. Those broadcasts became family memories.",
		"entry": "Old radios show how families once shared news, music, and entertainment."
	},
	"PictureFrameTopleft": {
		"title": "More Than a Frame",
		"migs": "Why keep old pictures instead of replacing them?",
		"lola": "The people and moments matter, hijo. Their stories make each picture precious.",
		"entry": "Names, dates, and memories give photographs meaning beyond their frames."
	},
	"Plants2Up": {
		"title": "Care Passed Down",
		"migs": "These plants look carefully tended, Lola.",
		"lola": "They remind me of the small lessons my family taught me about caring for our home.",
		"entry": "Caring for household plants can preserve family knowledge and daily traditions."
	}
}
