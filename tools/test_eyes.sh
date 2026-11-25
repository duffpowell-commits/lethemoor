#!/usr/bin/env bash
# Self-test for tools/eyes: the smoke run must pass, and two broken runs must fail.
# A tool that can't fail proves nothing (eval E4). Prints EYES TEST PASS at the end.
set -uo pipefail
cd "$(dirname "$0")/.."
run() { timeout 280 xvfb-run -a -s "-screen 0 1080x1920x24" node tools/eyes/eyes.mjs "$1" 2>&1; }
fail() { echo "EYES TEST FAIL: $1"; exit 1; }

rm -f docs/renders/eyes/game.png
out=$(run tools/eyes/smoke.json); echo "$out" | tail -3
echo "$out" | grep -q "^EYES PASS" || fail "smoke run did not pass"
[ -s docs/renders/eyes/game.png ] || fail "smoke run wrote no game.png"

out=$(run '[{"click": "NO SUCH BUTTON"}]'); echo "$out" | tail -1
echo "$out" | grep -q "^EYES FAIL no visible button" || fail "missing button was not caught"

out=$(run '[{"gd": "return scene_tree.no_such_property.name"}]'); echo "$out" | tail -1
echo "$out" | grep -qE "^EYES FAIL run_script" || fail "broken GDScript was not caught"

out=$(run '[{"gd": "var n = null\nscene_tree.root.add_child(Node.new())\nscene_tree.create_timer(0.1).timeout.connect(func(): n.foo())\nreturn 1"}, {"wait": 800}]'); echo "$out" | tail -1
echo "$out" | grep -q "^EYES FAIL game errors" || fail "a game runtime error was not caught"

out=$(run '[{"gd": "return 42", "allowErrors": true}]'); echo "$out" | tail -1
echo "$out" | grep -q "^gd 42" || fail "a step carrying allowErrors was skipped"

out=$(run '[{"gd": "push_warning(\"eyes test warning\")\nreturn 7"}, {"wait": 300}]'); echo "$out" | tail -2
echo "$out" | grep -q "^EYES PASS" || fail "a game warning failed the run (only errors should)"
echo "$out" | grep -q "^game warnings" || fail "a game warning was not listed"

out=$(run '[{"gd": "push_warning(\"line one\\nline two of the same warning\")\nreturn 1"}, {"wait": 300}]'); echo "$out" | tail -1
echo "$out" | grep -q "^EYES PASS" || fail "the second line of a two-line warning was counted as an error"

out=$(run '[{"gd": "printerr(\"plain stderr error\")\nreturn 1"}, {"wait": 300}]'); echo "$out" | tail -1
echo "$out" | grep -q "^EYES FAIL game errors" || fail "a bare printerr was not caught"

out=$(run '[{"gd": "push_warning(\"w1\")\nprinterr(\"error after a warning\")\nreturn 1"}, {"wait": 300}]'); echo "$out" | tail -1
echo "$out" | grep -q "^EYES FAIL game errors" || fail "a printerr after a warning was hidden as a warning"

out=$(run '[{"gd": "scene_tree.create_timer(0.05).timeout.connect(func(): OS.crash(\"eyes crash test\"))\nreturn 1"}]'); echo "$out" | tail -1
echo "$out" | grep -q "^EYES FAIL" || fail "a crash right after the last step passed"

out=$(run '[{"gd": "push_warning(\"w\")\nprinterr(\"[0] looks like a backtrace line\")\nreturn 1"}, {"wait": 300}]'); echo "$out" | tail -1
echo "$out" | grep -q "^EYES FAIL game errors" || fail "a fake [n] stderr line hid under a warning"

echo "EYES TEST PASS"
