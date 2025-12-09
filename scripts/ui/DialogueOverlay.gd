## Maintains UI and state machine logic for a dialogue event
extends Control

@onready var dialogue_prompt_label: RichTextLabel = $DialoguePromptLabel
@onready var dialogue_texture_rect: TextureRect = $DialogueTextureRect
@onready var dialogue_option_container: VBoxContainer = $DialogueOptionContainer

## This will only appear if no other options are found, and will end the dialogue when clicked
@onready var DEFAULT_DIALOGUE_OPTION_BBCODE: String = "[color=red]Error:[/color] No Valid Dialogue Options"

var current_dialogue_data: DialogueData = null # the current DialogueData object
var current_dialogue_state: DialogueStateData = null # the current DialogueStateData object

func _ready():
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	Signals.dialogue_ended.connect(_on_dialogue_ended)
	Signals.map_location_selected.connect(_on_map_location_selected)
	Signals.player_killed.connect(_on_player_killed)

## Initializes a dialogue given the player's current location/event
func start_dialogue() -> void:
	reset_dialogue()
	visible = true
	
	var event_data: EventData = Global.get_player_event_data()
	if event_data == null:
		DebugLogger.log_error("No Dialogue Event found")
		end_dialogue()
		return
	
	if event_data.event_dialogue_object_id == "":
		DebugLogger.log_error("No DialogueData specified for " + str(event_data.object_id))
		end_dialogue()
		return
	
	current_dialogue_data = Global.get_dialogue_data(event_data.event_dialogue_object_id)
	if current_dialogue_data == null:
		DebugLogger.log_error("No DialogueData specified for " + str())
		end_dialogue()
		return
	
	current_dialogue_state = current_dialogue_data.get_dialogue_state(current_dialogue_data.dialogue_initial_dialogue_state_object_id)
	populate_dialogue_options()
	
	Signals.dialogue_started.emit()

func end_dialogue() -> void:
	Signals.dialogue_ended.emit()

## Populates dialogue options for the current dialogue and current dialogue state
func populate_dialogue_options() -> void:
	clear_dialogue_options()
	
	# set prompt
	dialogue_prompt_label.parse_bbcode(current_dialogue_state.dialogue_state_prompt_bbcode)
	
	# set prompt image
	if current_dialogue_state.dialogue_state_dialogue_texture_path != "":
		dialogue_texture_rect.texture = FileLoader.load_texture(current_dialogue_state.dialogue_state_dialogue_texture_path)
	
	# create and validate dialogue option buttons
	# keep track of how many are actually clickable
	var valid_dialogue_option_counter: int = 0
	for dialogue_option_id: String in current_dialogue_state.dialogue_state_dialogue_option_object_ids:
		var dialogue_option_data: DialogueOptionData = current_dialogue_data.get_dialogue_option(dialogue_option_id)
		
		if dialogue_option_data != null:
			# create and initialize dialogue button
			var dialogue_option_button: DialogueOption = Scenes.DIALOGUE_OPTION.instantiate()
			dialogue_option_container.add_child(dialogue_option_button)
			dialogue_option_button.init(
				dialogue_option_data.object_id,
				dialogue_option_data.dialogue_option_bbcode,
				dialogue_option_data.dialogue_option_failed_validator_bbcode,
				dialogue_option_data.dialogue_option_actions,
				dialogue_option_data.dialogue_option_validators,
				)
			# connect signal
			dialogue_option_button.dialogue_option_clicked.connect(_on_dialogue_option_clicked)
			
			# hide options that aren't validated and not allowed to be visible
			if not dialogue_option_button.option_enabled:
				if not dialogue_option_data.dialogue_option_visible_on_failed_validation:
					dialogue_option_button.visible = false
			else:
				valid_dialogue_option_counter += 1
		
	# Create a dummy dialogue option that always ends the dialogue.
	# This should not appear normally, but makes it so the game doesn't
	# softlock if there's no possible options.
	if valid_dialogue_option_counter <= 0:
		var dialogue_option_button: DialogueOption = Scenes.DIALOGUE_OPTION.instantiate()
		dialogue_option_container.add_child(dialogue_option_button)
		dialogue_option_button.init(
			"",
			DEFAULT_DIALOGUE_OPTION_BBCODE,
			DEFAULT_DIALOGUE_OPTION_BBCODE,
			[],
			[]
			)
		# connect signal
		dialogue_option_button.dialogue_option_clicked.connect(_on_dialogue_option_clicked)

func _on_dialogue_option_clicked(dialogue_option: DialogueOption) -> void:
	var dialogue_option_object_id: String = dialogue_option.dialogue_option_object_id
	
	# default or undefined option always ends dialogue when selected
	if dialogue_option_object_id == "":
		end_dialogue()
		return
	
	var dialogue_option_data: DialogueOptionData = current_dialogue_data.get_dialogue_option(dialogue_option_object_id)
	
	# perform dialogue option actions
	var player: Player = Global.get_player()
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(player, null, [player], dialogue_option.action_data, null)
	ActionHandler.add_actions(generated_actions)
	
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# check if player dead
	if not player.is_alive():
		end_dialogue()
		return
	
	# if no further dialogue states end dialogue
	var dialogue_option_next_dialogue_state_id: String = dialogue_option_data.dialogue_option_next_dialogue_state_id
	if dialogue_option_next_dialogue_state_id == "":
		end_dialogue()
		return
	
	# set the dialogue state
	current_dialogue_state = current_dialogue_data.get_dialogue_state(dialogue_option_next_dialogue_state_id)
	
	# if invalid dialogue state end dialogue
	if current_dialogue_state == null:
		end_dialogue()
		return
	
	# repopulate with new dialogue state
	populate_dialogue_options()

## Completely resets the Dialogue UI
func reset_dialogue() -> void:
	clear_dialogue_options()
	visible = false
	dialogue_prompt_label.parse_bbcode("")
	dialogue_texture_rect.texture = load("res://icon.svg")
	
	current_dialogue_data = null
	current_dialogue_state = null

func clear_dialogue_options() -> void:
	for child in dialogue_option_container.get_children():
		child.queue_free()

func _on_dialogue_ended():
	reset_dialogue()
	
func _on_run_ended():
	reset_dialogue()

func _on_run_started():
	reset_dialogue()

func _on_player_killed(_player: Player):
	visible = false

func _on_map_location_selected(_location_data: LocationData):
	if _location_data.location_type != LocationData.LOCATION_TYPES.EVENT:
		reset_dialogue()
	else:
		start_dialogue()
