extends Node

@export_file() var gui_scene_path: String

func _ready():
	var args = OS.get_cmdline_args()
	var user_args = OS.get_cmdline_user_args()

	if _is_cli_mode(args):
		Output.push("Run cli mode")
		var adjusted_args = args.slice(1) if OS.has_feature("editor") else args
		CliMain.main(adjusted_args, user_args)
		_exit()
	else:
		Output.push("Run window mode")
		add_child.call_deferred(load(gui_scene_path).instantiate())
	pass

func _is_cli_mode(args: PackedStringArray) -> bool:
	var cli_keywords := ["--ghelp", "-gh", "--recent", "-r", "editor", "exec"]
	for arg in args:
		if cli_keywords.has(arg):
			return true
	return false

func _exit():
	get_tree().quit()
