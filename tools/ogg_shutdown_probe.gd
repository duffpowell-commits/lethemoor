extends SceneTree
## Reproduce active OGG playback cleanup separately from the harbor or renderer.
## godot --headless --audio-driver Dummy --verbose --path . --script tools/ogg_shutdown_probe.gd
## Add -- --stop to stop playback and allow the mixer to release its reference before exit.

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var player := AudioStreamPlayer.new()
	var clip: AudioStreamOggVorbis = load("res://assets/audio/amb_moor.ogg")
	clip.loop = true
	root.add_child(player)
	player.stream = clip
	player.play()
	await create_timer(0.35).timeout
	if "--stop" in OS.get_cmdline_user_args():
		player.stop()
		await create_timer(0.25).timeout
		player.stream = null
		player.queue_free()
		await process_frame
	quit()
