# Displays run start options
extends Control

var _option_type_to_option_ids: Dictionary = {}
const MIXED_OPTION_COUNT: int = 3	# number of options to populate that have both an upside and downside
const COMPLETE_OPTION_COUNT: int = 1	# number of unique options to populate

@onready var starting_option_container = $StartingOptionContainer
@onready var map = $%Map

func _ready():
	_aggregate_run_start_options()
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	Signals.map_location_selected.connect(_on_map_location_selected)

func _aggregate_run_start_options() -> void:
	# sorts the various options into boxes based on type
	for option_type in RunStartOptionData.RUN_START_OPTION_TYPES.values():
		_option_type_to_option_ids[option_type] = [] as Array[String]
	for run_start_option_data in Global._id_to_run_start_option_data.values() as Array[RunStartOptionData]:
		_option_type_to_option_ids[run_start_option_data.run_start_option_type].append(run_start_option_data.object_id)

func populate_run_start_options() -> void:
	# Presents a list of options to the player
	
	# get options based on type
	var upside_option_ids: Array[String] = _option_type_to_option_ids[RunStartOptionData.RUN_START_OPTION_TYPES.PARTIAL_UPSIDE]
	var complete_option_ids: Array[String] = _option_type_to_option_ids[RunStartOptionData.RUN_START_OPTION_TYPES.COMPLETE]
	var downside_option_ids: Array[String] = _option_type_to_option_ids[RunStartOptionData.RUN_START_OPTION_TYPES.PARTIAL_DOWNSIDE]
	
	# duplicate for later removal of items
	downside_option_ids = downside_option_ids.duplicate()
	upside_option_ids = upside_option_ids.duplicate()
	complete_option_ids = complete_option_ids.duplicate()
	
	# randomize presented options
	var rng_run_start_options: RandomNumberGenerator = Global.player_data.get_player_rng("rng_run_start_options")
	Random.shuffle_array(rng_run_start_options, downside_option_ids)
	Random.shuffle_array(rng_run_start_options, upside_option_ids)
	Random.shuffle_array(rng_run_start_options, downside_option_ids)
	
	# populate mixed options
	var mixed_option_count: int = min(MIXED_OPTION_COUNT, len(upside_option_ids), len(downside_option_ids))
	for i in mixed_option_count:
		var upside_option_id: String = upside_option_ids.pop_back()
		var downside_option_id: String = downside_option_ids.pop_back()
		
		DebugLogger.log_line("Run options: " + upside_option_id + " " + downside_option_id)
		
		var upside_run_start_option_data: RunStartOptionData = Global.get_run_start_option_data(upside_option_id)
		var downside_run_start_option_data: RunStartOptionData = Global.get_run_start_option_data(downside_option_id)
		
		var upside_actions: Array[Dictionary] = upside_run_start_option_data.run_start_option_actions.duplicate()
		var downside_actions: Array[Dictionary] = downside_run_start_option_data.run_start_option_actions.duplicate()

		# concatenate partial text and actions
		var option_bbcode: String = upside_run_start_option_data.run_start_option_bb_code + ", " + downside_run_start_option_data.run_start_option_bb_code
		var option_actions: Array[Dictionary] = downside_run_start_option_data.run_start_option_actions + upside_run_start_option_data.run_start_option_actions
		
		# create a dialogue button for the option
		var run_start_option_button: DialogueOption = Scenes.DIALOGUE_OPTION.instantiate()
		starting_option_container.add_child(run_start_option_button)
		run_start_option_button.init("", option_bbcode, option_bbcode, option_actions, [])
		
		run_start_option_button.dialogue_option_clicked.connect(_on_dialogue_option_clicked)
	
	# populate complete options
	for i in min(COMPLETE_OPTION_COUNT, len(complete_option_ids)):
		# get option
		var complete_option_id: String = complete_option_ids.pop_back()
		var complete_run_start_option_data: RunStartOptionData = Global.get_run_start_option_data(complete_option_id)
		
		# get actions and bbcode
		var option_bbcode: String = complete_run_start_option_data.run_start_option_bb_code
		var option_actions: Array[Dictionary] = complete_run_start_option_data.run_start_option_actions
		
		# create a dialogue button for the option
		var run_start_option_button: DialogueOption = Scenes.DIALOGUE_OPTION.instantiate()
		starting_option_container.add_child(run_start_option_button)
		run_start_option_button.init("", option_bbcode, option_bbcode, option_actions, [])
		
		run_start_option_button.dialogue_option_clicked.connect(_on_dialogue_option_clicked)
	
func clear_run_start_options() -> void:
	for child in starting_option_container.get_children():
		child.queue_free()
	
func _on_dialogue_option_clicked(dialogue_option: DialogueOption):
	var player: Player = Global.get_player()
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(player, null, [player], dialogue_option.action_data, null)
	ActionHandler.add_actions(generated_actions)
	clear_run_start_options()
	visible = false
	
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	map.can_travel = true
	map.show_map()
	
func _on_run_started():
	visible = false
	
func _on_run_ended():
	visible = false

func _on_map_location_selected(location_data: LocationData):
	# determine what to do when the player visits a new location
	var location_type: int = location_data.location_type

	visible = false
	match location_type:
		LocationData.LOCATION_TYPES.STARTING:
			populate_run_start_options()
			visible = true
