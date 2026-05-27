# Main menu on title screen
extends Control

@onready var title_screen: Control = $%TitleScreen

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var forfeit_run_button: Button = $VBoxContainer/ForfeitRunButton
@onready var new_run_button: Button = $VBoxContainer/NewRunButton
@onready var codex_button: Button = $VBoxContainer/CodexButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton

func _ready():
	var label = get_node_or_null("Label")
	if label:
		label.text = "Slay the Pigeon"

	continue_button.button_up.connect(_on_continue_button_up)
	forfeit_run_button.button_up.connect(_on_forfeit_run_button_up)
	new_run_button.button_up.connect(_on_new_run_button_up)
	codex_button.button_up.connect(_on_codex_button_up)
	exit_button.button_up.connect(_on_exit_button_up)

	Signals.run_ended.connect(_on_run_ended)

	update_continue_button_visibility()

func _on_continue_button_up():
	FileLoader.autoload()

func _on_forfeit_run_button_up():
	FileLoader.delete_save()
	update_continue_button_visibility()

func _on_new_run_button_up():
	title_screen.show_new_run_menu()

func _on_codex_button_up():
	title_screen.show_codex_menu()

func _on_exit_button_up():
	get_tree().quit()

func update_continue_button_visibility() -> void:
	var has_save_file: bool = FileLoader.has_save_file()
	continue_button.visible = has_save_file
	forfeit_run_button.visible = has_save_file
	new_run_button.visible = not has_save_file

func _on_run_ended():
	# go back to tile screen on abandoned run, but not failed run
	var has_save_file: bool = FileLoader.has_save_file()
	visible = has_save_file
	update_continue_button_visibility()
