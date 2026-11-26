extends SceneTree
## Plays many dealt nights with tools/eyes/first_timer.gd: a newcomer who knows only what's on the
## screen (see that file). The balance bot (tools/balance_bot.gd) knows the whole map; this one
## says how a first night feels.
##   godot --headless --path . --script tools/first_timer_bot.gd -- [nights=200]
## BOT_FIRST=n starts at night n (default 1). BOT_TRACE=1 prints every move. BOT_GENTLE=1 plays
## them as a newcomer's first nights (a thrall fewer, Record.gentle).
## BOT_HALF=1 plays nights 4-6 (Record.easing 1: chalk, a little more oil).

const Night = preload("res://scripts/sim/night.gd")
const Pilot = preload("res://tools/eyes/first_timer.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var count := maxi(1, int(args[0])) if args.size() > 0 else 200
	var first := int(OS.get_environment("BOT_FIRST")) if OS.get_environment("BOT_FIRST") != "" else 1
	var trace := OS.get_environment("BOT_TRACE") != ""
	var text := FileAccess.get_file_as_string("res://rooms/one_night.txt")
	var won := 0
	var died := 0
	var lost := 0
	var oil_sum := 0
	var turns_sum := 0
	var early := 0
	var causes := {}
	var grades := {}
	var death_turns: Array = []
	var dry := 0                        # deaths after the oil ran out
	for s in range(first, first + count):
		var g = Night.start_dealt(text, s, false, OS.get_environment("BOT_GENTLE") == "1", OS.get_environment("BOT_HALF") == "1")
		for _i in 300:
			if g.over():
				break
			var a: String = Pilot.choose(g)
			if trace:
				print(g.turn, " ", g.hunter, " f=", g.facing, " oil=", g.oil, " -> ", a)
			match a:
				"forward": g.step_dir(g.facing)
				"back": g.step_dir(-g.facing)
				"left": g.turn_by(-1)
				"right": g.turn_by(1)
				"hook": g.hook()
				_: g.wait()
		if g.rang:
			won += 1
			oil_sum += g.oil
			turns_sum += g.turn
			grades[g.grade()] = grades.get(g.grade(), 0) + 1
		elif g.dead:
			died += 1
			death_turns.append(g.turn)
			if g.oil <= 0:
				dry += 1
			if g.turn <= 20:
				early += 1
			var c: String = g.cause.substr(0, 28)
			causes[c] = causes.get(c, 0) + 1
		else:
			lost += 1
	death_turns.sort()
	print("FIRST-TIMER nights=%d won=%d (%d%%) died=%d (%d%%) lost/out of time=%d" % [count, won, 100 * won / count, died, 100 * died / count, lost])
	print("won: avg oil at bell %.1f, avg turns %.1f, grades %s" % [float(oil_sum) / maxi(1, won), float(turns_sum) / maxi(1, won), str(grades)])
	print("deaths by turn 20: %d (%d%% of nights)  median death turn: %s" % [early, 100 * early / count, str(death_turns[death_turns.size() / 2]) if not death_turns.is_empty() else "-"])
	print("causes: ", causes, "  died with no oil left: %d of %d" % [dry, died])
	quit()
