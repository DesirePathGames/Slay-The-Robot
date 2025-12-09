## Read only data for a dialogue used in an event. Provides a state machine through
## DialogueOptionData and DialogueStateData which is used by DialogueOverlay.
extends SerializableData
class_name DialogueData

## The initial embedded DialogueStateData object_id used when starting this dialogue. This is used to
## populate the initial prompt and dialogue choices. 
@export var dialogue_initial_dialogue_state_object_id: String = ""
## Maps object_ids to embedded dialogue state machine objects.
@export var dialogue_state_id_to_dialogue_states: Dictionary[String, DialogueStateData] = {}
@export var dialogue_option_id_to_dialogue_options: Dictionary[String, DialogueOptionData] = {}

## Gets embedded DialogueOption belonging to this Dialogue.
func get_dialogue_option(dialogue_option_object_id: String) -> DialogueOptionData:
	if not dialogue_option_id_to_dialogue_options.has(dialogue_option_object_id):
		DebugLogger.log_error("No DialogueOptionData with ID {0} found in Dialogue {1}".format([dialogue_option_object_id, object_id]))
		return null
	else:
		return dialogue_option_id_to_dialogue_options[dialogue_option_object_id]

## Gets embedded DialogueState belonging to this Dialogue.
func get_dialogue_state(dialogue_state_object_id: String) -> DialogueStateData:
	if not dialogue_state_id_to_dialogue_states.has(dialogue_state_object_id):
		DebugLogger.log_error("No DialogueStateData with ID {0} found in Dialogue {1}".format([dialogue_state_object_id, object_id]))
		return null
	else:
		return dialogue_state_id_to_dialogue_states[dialogue_state_object_id]


## Helper method for test data generation. Improves code readability and prevents bugs
func _assign_option(dialogue_option_data: DialogueOptionData) -> void:
	if dialogue_option_id_to_dialogue_options.has(dialogue_option_data.object_id):
		breakpoint # duplicate found
	dialogue_option_id_to_dialogue_options[dialogue_option_data.object_id] = dialogue_option_data
## Helper method for test data generation. Improves code readability and prevents bugs
func _assign_state(dialogue_state_data: DialogueStateData) -> void:
	if dialogue_state_id_to_dialogue_states.has(dialogue_state_data.object_id):
		breakpoint # duplicate found
	dialogue_state_id_to_dialogue_states[dialogue_state_data.object_id] = dialogue_state_data
func _assign_initial_state(dialogue_state_data: DialogueStateData) -> void:
	if dialogue_initial_dialogue_state_object_id != "":
		breakpoint
	dialogue_initial_dialogue_state_object_id = dialogue_state_data.object_id
