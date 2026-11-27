## The pages nailed up in the dark. Pure data, no nodes.
## Pages come in the order you READ them, not by where they hang: the map reshuffles every
## night, so the first page you find is always page one and the story still reads in order.
## Every page has its own scrap of paper (`paper` = assets/art/letters/<name>.png, drawn by
## tools/gen_letter_pages.py), ink colour, tilt and width, so no two notes look alike.
## Keep each page short enough to read on a phone without scrolling (about 75 words).
extends RefCounted

const PAGES := [
	{
		"head": "A PAGE, WATER-STAINED",
		"body": "Tobias came home at the third hour, wet to the collar, though no rain fell. He would not speak. He stood at the foot of our bed until the grey of morning, and the boards never dried.\n\nHis lobster pots still stand by the Rope Walk. I have barred the door; he does not knock. He waits, as patient as the tide.\n\nIf you pass the quay, do not let him see your light.",
		"sign": "Martha Hale, of the Rope Walk",
		# the look: a damp, yellowed scrap in faded brown ink, torn off along the bottom
		"paper": "page_1", "ink": Color("#3b2a17"), "head_ink": Color("#5b3a1c"), "tilt": -1.6, "width": 480,
	},
	{
		"head": "A PAGE, PERFUMED",
		"body": "Beloved, they say the bell will ring for us at dawn, and the harbour will hear it.\n\nI have sewn the veil myself. Our oar lies beneath the upturned boat. If fog comes first, I shall wait in Chapel Lane. Look upon me as you used to, and I will be still as a portrait. Only do not turn from me again.\n\nI have never liked the dark. I have been in it so long.",
		"sign": "Your Ada",
		# pale folded notepaper, violet-black ink, a rose blot: smaller, like a note slipped under a door
		"paper": "page_2", "ink": Color("#2b1f33"), "head_ink": Color("#6a2f4a"), "tilt": 1.2, "width": 440,
	},
	{
		"head": "A PAGE, UNDER SEAL",
		"body": "By order of the Watch: the cathedral bell shall not be rung.\n\nThe founders' bargain holds only while the town forgets, and the river cannot do its work beneath a ringing bell. Let the drowned keep their quiet. Let the bride keep her lane.\n\nBurn this page once it is read. If you read it now by lantern-light, Captain, you have already disobeyed.",
		"sign": "The hand that signed it is your own.",
		# dark official stock, scorched along the top, broken red seal: iron-gall black ink
		"paper": "page_3", "ink": Color("#140d08"), "head_ink": Color("#6e1410"), "tilt": -0.6, "width": 490,
	},
]


## Page for the n-th letter read this night (0-based). Past the last page, the last repeats.
static func page(n: int) -> Dictionary:
	return PAGES[clampi(n, 0, PAGES.size() - 1)]


## Roman numeral for the page kicker (I, II, III...).
static func numeral(n: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(n, 0, 9)]
