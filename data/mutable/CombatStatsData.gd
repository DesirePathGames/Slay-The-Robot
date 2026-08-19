## Maintains data about things happening in combat, such as cards played, damage taken etc.
## This can be queried on a current turn or per combat basis.
## Only stores stats for a single instance of combat.
## See RunStatsData for tracking the entire run.
extends SerializableData
class_name CombatStatsData

## The EventData object id used in this combat.
@export var event_object_id: String = ""
## The floor this combat took place on.
@export var combat_floor: int = 1

var cards_played_this_turn: Array[CardPlayRequest] = []
var cards_played_this_combat: Array[Array] = []

## The current turn of combat for this instance of combat.
@export var turn_count: int = 1

# stat types tracked on per turn and per combat
# each stat listed in enum will automatically be used to generate stat tracking keys in init()
enum STATS {
	ENEMY_BLOCK_BROKEN_COUNT,		# number of times enemy's block has been broken through
	ENEMY_BLOCKED_COUNT,			# number of times an enemy blocked an attack
	ENEMY_BLOCKED_AMOUNT,			# total amount of blocked damage by enemy
	ENEMY_DAMAGED_COUNT,			# number of times enemy has taken non zero health damage
	ENEMY_DAMAGED_AMOUNT,			# total health damage by enemies
	ENEMY_DAMAGED_CAPPED_AMOUNT,	# total health damage capped (excludes overkill damage)
	ENEMY_DAMAGED_OVERKILL_AMOUNT,	# total health damage against enemies that exceeds 0
	ENEMIES_KILLED,					# number of enemies killed
	
	PLAYER_BLOCK_BROKEN_COUNT,		# number of times player's block has been broken through
	PLAYER_BLOCKED_COUNT,			# total amount of blocked damage by player
	PLAYER_BLOCKED_AMOUNT,			# total amount of blocked damage by player
	PLAYER_DAMAGED_COUNT,			# number of times player has taken non zero health damage
	PLAYER_DAMAGED_AMOUNT,			# total health damage to player
	
	CARDS_PLAYED,					# number of cards played
	CARDS_DRAWN,					# number of cards drawn
	CARDS_DISCARDED,				# number of cards discarded explicitly by player
	CARDS_DISCARDED_NATURAL,		# number of cards discarded naturally (hand overflow, end of turn discard)
	CARDS_EXHAUSTED,				# number of cards exhausted
	CARDS_BANISHED,					# number of cards banished
	CARDS_RETAINED,					# number of cards retained
	CARDS_UPGRADED,					# number of cards upgraded mid combat
	CARDS_CREATED,					# number of cards created mid combat
	DECK_RESHUFFLED					# number of times deck was reshuffled (initial shuffling not counted)
}

@export var turn_stats: Dictionary = {}	# maintains numberical stats on all trackable things done this turn 
@export var total_stats: Dictionary = {} # maintains numberical stats on all trackable things done this combat

func _init(_event_object_id: String = "", _combat_floor: int = 0):
	event_object_id = _event_object_id
	
	combat_floor = _combat_floor
	
func initialize_stats() -> void:
	# assign zero stats
	for key: String in STATS.keys():
		turn_stats[key] = 0
		total_stats[key] = 0
	for custom_signal_object_id in Global._id_to_custom_signal_data.keys():
		var custom_signal_data: CustomSignalData = Global.get_custom_signal_data(custom_signal_object_id)
		if custom_signal_data.custom_signal_is_stat:
			turn_stats[custom_signal_data.custom_signal_stat_name] = 0
			total_stats[custom_signal_data.custom_signal_stat_name] = 0


#region Card Plays

func get_turn_last_card_play() -> CardPlayRequest:
	# gets the card last played, if one exists
	if len(cards_played_this_turn) > 0:
		return cards_played_this_turn[-1]
	return null

func get_card_data_played_this_turn(include_duplicates: bool = false) -> Array[CardData]:
	# gets all cards played this turn, with option to cull duplicate cards
	var cards_played: Array[CardData] = []
	for card_play_request in cards_played_this_turn:
		if include_duplicates:
			cards_played.append(card_play_request.card_data)
		else:
			if not cards_played.has(card_play_request.card_data):
				cards_played.append(card_play_request.card_data)
	return cards_played

func get_card_data_played_last_turn(include_duplicates: bool = false) -> Array[CardData]:
	# gets all cards played last turn, with option to cull duplicate cards
	var cards_played: Array[CardData] = []
	if turn_count <= 1:
		return []	# 1st turn, no previous turn
	
	for card_play_request in cards_played_this_combat[turn_count - 2]:
		if include_duplicates:
			cards_played.append(card_play_request.card_data)
		else:
			if not cards_played.has(card_play_request.card_data):
				cards_played.append(card_play_request.card_data)
	return cards_played
#endregion

#region Stat Tracking
func reset_turn_stats() -> void:
	for stat_name in turn_stats:
		turn_stats[stat_name] = 0

func _get_stat_name(stat_enum: int) -> String:
	# helper method to convert stat enum to string representation
	if stat_enum < len(STATS.keys()):
		return STATS.keys()[stat_enum]
	else:
		breakpoint
		DebugLogger.log_error("CombatStatsData._get_stat_name(): Given stat enum {0} exceeds bounds of STATS".format([stat_enum]))
	return ""

## Adds a value to this turn's stats for a given hard coded CombatStatsData.STATS
func add_to_turn_enum_stat(stat_enum: int, stat_amount: int) -> void:
	var stat_name: String = _get_stat_name(stat_enum)
	turn_stats[stat_name] = turn_stats[stat_name] + stat_amount
	total_stats[stat_name] = total_stats[stat_name] + stat_amount
	Signals.combat_stat_changed.emit(stat_enum)

## Adds a value to a given custom stat. Can include custom stats.
func add_to_turn_stat(stat_name: String, stat_amount: int) -> void:
	# adds a value to this turn's stats
	turn_stats[stat_name] = turn_stats[stat_name] + stat_amount
	total_stats[stat_name] = total_stats[stat_name] + stat_amount

## Gets a given stat across the entire combat. Can include custom stats.
func get_total_stat(stat_name: String) -> int:
	return total_stats.get(stat_name, 0)

## Gets a given stat across the current turn. Can include custom stats.
func get_turn_stat(stat_name: String) -> int:
	return turn_stats.get(stat_name, 0)

## Gets a turn combat stat from a hardcoded STATS enum value.
func get_turn_enum_stat(stat_enum: int) -> int:
	var stat_name: String = _get_stat_name(stat_enum)
	return get_turn_stat(stat_name)

## Gets a total combat stat from a hardcoded STATS enum value.
func get_total_enum_stat(stat_enum: int) -> int:
	var stat_name: String = _get_stat_name(stat_enum)
	return get_total_stat(stat_name)
#endregion
