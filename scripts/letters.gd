## The pages nailed up in the dark. Pure data, no nodes.
## Pages come in the order you READ them, not by where they hang: the map reshuffles every
## night, so the first page you find is always page one and the story still reads in order.
## Keep each page short enough to read on a phone without scrolling (about 75 words).
extends RefCounted

const PAGES := [
	{
		"head": "A PAGE, WATER-STAINED",
		"body": "My Tobias came home at the third hour, wet to the collar, though no rain had fallen. He would not speak. He stood at the foot of our bed until the grey of morning, and the boards beneath him never dried.\n\nTonight I have barred the door. He does not knock. He only waits, as patient as the tide.\n\nIf you pass the quay, do not let him see your light.",
		"sign": "Martha Hale, of the Rope Walk",
	},
	{
		"head": "A PAGE, PERFUMED",
		"body": "Beloved, they say the bell will ring for us at dawn, and all the harbour will hear it.\n\nI have sewn the veil myself. If the fog comes before you do, I shall wait in the chapel lane. Look upon me as you used to, and I will be as still as a portrait. Only do not turn from me again.\n\nI have never liked the dark. I have been in it so long.",
		"sign": "Your Ada",
	},
	{
		"head": "A PAGE, UNDER SEAL",
		"body": "By order of the Watch: the cathedral bell shall not be rung.\n\nThe founders' bargain holds only while the town forgets, and the river cannot do its work beneath a ringing bell. Let the drowned keep their quiet. Let the bride keep her lane.\n\nBurn this page once it is read. If you read it now by lantern-light, Captain, you have already disobeyed.",
		"sign": "The hand that signed it is your own.",
	},
]


## Page for the n-th letter read this night (0-based). Past the last page, the last repeats.
static func page(n: int) -> Dictionary:
	return PAGES[clampi(n, 0, PAGES.size() - 1)]


## Roman numeral for the page kicker (I, II, III...).
static func numeral(n: int) -> String:
	return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(n, 0, 9)]
