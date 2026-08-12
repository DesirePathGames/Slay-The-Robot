## Provides hooks and global interface for managing player's run and combat stats.
## Manages win/loss data across player profile.
extends Node

## Tracks whether it is currently the player's turn in a central location.
var is_player_turn: bool = false

var cards_played_this_turn: Array[CardPlayRequest] = []
var cards_played_this_combat: Array[Array] = []

var turn_count: int = 1

## The current combat. This will be appended to the run stats when combat ends.
var current_combat_stats: CombatStatsData = null

## The current run stats. Same as the one stored in PlayerData just saves some pointers to store locally.
var current_run_stats: RunStatsData = null


# run tracking flags.
# These are organized as a hierarchy with top being more general and bottom more specific
## Set false to completely disable all run tracking. Useful for development.
var TRACK_RUN_HISTORY: bool = true
## Max number of entries that will be saved to profile. Older entries will be removed.
## Negative values for no maximum.
var RUN_HISTORY_ENTRIES_MAX: int = -1
## Disabling this will delete all CombatStats objects at the end of a run.
var TRACK_COMBAT: bool = true
## Tracking of run related STATS. Will track during the run for API purposes,
## but cleared at the end.
var TRACK_RUN_STATS: bool = true
## Tracking of all combat related STATS. Will track during the run for API purposes,
## but cleared at the end.
var TRACK_COMBAT_STATS: bool = true


func _ready() -> void:
	_connect_signals()

#region Signals
func _connect_signals():
	Signals.run_ended.connect(_on_run_ended)
	
	Signals.player_turn_started.connect(_on_player_turn_started)
	Signals.player_turn_ended.connect(_on_player_turn_ended)
	
	Signals.enemy_turn_ended.connect(_on_enemy_turn_ended)
	Signals.card_played.connect(_on_card_played)
	
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	
	# run stats
	Signals.player_money_changed.connect(_on_player_money_changed)
	Signals.rest_action_ended.connect(_on_rest_action_ended)
	Signals.shop_visited_first_time.connect(_on_shop_visited_first_time)
	
	# combat stats
	Signals.combatant_block_broken.connect(_on_combatant_block_broken)
	Signals.combatant_blocked.connect(_on_combatant_blocked)
	Signals.combatant_damaged.connect(_on_combatant_damaged)
	Signals.enemy_killed.connect(_on_enemy_killed)
	
	Signals.card_drawn.connect(_on_card_drawn)
	Signals.card_discarded.connect(_on_card_discarded)
	Signals.card_exhausted.connect(_on_card_exhausted)
	Signals.card_banished.connect(_on_card_banished)
	Signals.card_retained.connect(_on_card_retained)
	Signals.card_upgraded.connect(_on_card_upgraded)
	Signals.card_created.connect(_on_card_created)
	
	Signals.card_deck_shuffled.connect(_on_card_deck_shuffled)
	
	# custom stats
	_connect_custom_signals()

func _connect_custom_signals() -> void:
	# iterate over all custom signals that are stats and connect to them
	for custom_signal_object_id in Global._id_to_custom_signal_data.keys():
		var custom_signal_data: CustomSignalData = Global.get_custom_signal_data(custom_signal_object_id)
		if custom_signal_data.custom_signal_is_stat:
			var custom_signal: CustomSignal = Signals.get_custom_signal(custom_signal_object_id)
			custom_signal.custom_signal.connect(_on_custom_signal)

func _disconnect_signals():
	# disconnect all signals to prevent stats being tracked across multiple combats
	for connection in get_incoming_connections():
		connection.signal.disconnect(connection.callable)
#endregion

## Marks the current run as won and stores it in player run history
func win_run() -> void:
	_complete_run(true)

## Marks the current run as lost and stores it in player run history
func lose_run() -> void:
	_complete_run(false)

## Marks the run as finished and stores it in player run history
func _complete_run(is_victory: bool) -> void:
	# no tracking, ignore this run
	if not TRACK_RUN_HISTORY:
		current_combat_stats = null
		current_run_stats = null
		return 
	
	# cannot be called twice in a row
	if current_run_stats == null:
		breakpoint
		return
	
	# store win/loss in profile and run history
	current_run_stats.run_victory = is_victory
	
	var profile_data: ProfileData = Global.profile_data
	var character_id: String = Global.player_data.player_character_object_id
	
	# total run time
	var run_time: float = Global.player_data.player_run_time
	profile_data.profile_total_run_time += run_time
	
	# character run time
	var character_run_time: float = profile_data.profile_character_id_to_total_run_time.get(character_id, 0.0)
	character_run_time += run_time
	profile_data.profile_character_id_to_total_run_time[character_id] = character_run_time
	
	if is_victory:
		# highest character difficulty win
		var profile_character_highest_difficulty: int = profile_data.profile_character_id_to_highest_difficulty.get(character_id, 0)
		var current_difficulty_level: int = Global.player_data.player_run_difficulty_level
		profile_character_highest_difficulty = max(current_difficulty_level, profile_character_highest_difficulty)
		profile_data.profile_character_id_to_highest_difficulty[character_id] = profile_character_highest_difficulty
		# fastest profile win
		if profile_data.profile_fastest_win_run_time > 0.0:
			# take min of existing run time
			profile_data.profile_fastest_win_run_time = min(run_time, profile_data.profile_fastest_win_run_time)
		else:
			# no existing fastest, assign to current
			profile_data.profile_fastest_win_run_time = run_time
		# fastest character win
		if profile_data.profile_character_id_to_fastest_run_time.has(character_id):
			# take min of existing run time
			var fastest_character_run_time: float = profile_data.profile_character_id_to_fastest_run_time.get(character_id, 0.0)
			fastest_character_run_time = min(run_time, fastest_character_run_time)
			profile_data.profile_character_id_to_fastest_run_time[character_id] = fastest_character_run_time
		else:
			# no existing fastest, assign to current
			profile_data.profile_character_id_to_fastest_run_time[character_id] = run_time
		
		# profile and character wins
		profile_data.profile_total_wins += 1
		var character_wins: int = profile_data.profile_character_id_to_wins.get(character_id, 0)
		character_wins += 1
		profile_data.profile_character_id_to_wins[character_id] = character_wins
		# profile win streaks
		profile_data.profile_current_win_streak += 1
		profile_data.profile_highest_win_streak = max(profile_data.profile_current_win_streak, profile_data.profile_highest_win_streak)
		# profile loss streaks
		profile_data.profile_current_loss_streak = 0
		# character win streaks
		var character_current_win_streak: int = profile_data.profile_character_id_to_current_win_streak.get(character_id, 0)
		var character_highest_win_streak: int = profile_data.profile_character_id_to_highest_loss_streak.get(character_id, 0)
		character_current_win_streak += 1
		profile_data.profile_character_id_to_current_win_streak[character_id] = character_current_win_streak
		profile_data.profile_character_id_to_highest_win_streak[character_id] = max(character_current_win_streak, character_highest_win_streak)
		# character loss streaks
		profile_data.profile_character_id_to_current_loss_streak[character_id] = 0
	else:
		# profile and character losses
		profile_data.profile_total_losses += 1
		var character_losses: int = profile_data.profile_character_id_to_losses.get(character_id, 0)
		character_losses += 1
		profile_data.profile_character_id_to_losses[character_id] = character_losses
		# profile loss streaks
		profile_data.profile_current_loss_streak += 1
		profile_data.profile_highest_loss_streak = max(profile_data.profile_current_loss_streak, profile_data.profile_highest_loss_streak)
		# profile win streaks
		profile_data.profile_current_win_streak = 0
		# character loss streaks
		var character_current_loss_streak: int = profile_data.profile_character_id_to_current_loss_streak.get(character_id, 0)
		var character_highest_loss_streak: int = profile_data.profile_character_id_to_highest_win_streak.get(character_id, 0)
		character_current_loss_streak += 1
		profile_data.profile_character_id_to_current_loss_streak[character_id] = character_current_loss_streak
		profile_data.profile_character_id_to_highest_loss_streak[character_id] = max(character_current_loss_streak, character_highest_loss_streak)
		# character win streaks
		profile_data.profile_character_id_to_current_win_streak[character_id] = 0
	
	# store run stats from player data in history
	current_run_stats.run_seed = Global.player_data.player_run_seed
	current_run_stats.run_character_id = character_id
	current_run_stats.run_difficulty_level = Global.player_data.player_run_difficulty_level
	current_run_stats.run_player_health = Global.player_data.player_health
	current_run_stats.run_player_health_max = Global.player_data.player_health_max
	current_run_stats.run_player_money = Global.player_data.player_money
	# completion time/date
	current_run_stats.run_completion_timestamp = int(Time.get_unix_time_from_system())
	current_run_stats.run_completion_time = Global.player_data.player_run_time
	# store deck as tuples of [card, upgrades]
	for card_data: CardData in Global.player_data.player_deck:
		var card_entry: Array = [card_data.object_id, card_data.card_upgrade_amount]
		current_run_stats.run_deck.append(card_entry)
	# store artifact ids
	for artifact_data: ArtifactData in Global.player_data.player_artifact_uid_to_artifact_data.values():
		current_run_stats.run_artifact_ids.append(artifact_data.object_id)
	# store consumables
	current_run_stats.run_consumable_ids = Global.player_data.get_available_consumable_ids()
	current_run_stats.run_consumable_slot_count = Global.player_data.player_consumable_slot_count
	# store floor
	var current_floor: int = Global.get_player_current_floor()
	current_run_stats.run_floor = current_floor
	
	# defeat specific stats
	if not is_victory:
		# store floor and event
		var current_event_data: EventData = Global.get_player_event_data()
		if current_event_data != null: # can be null if not an event
			current_run_stats.run_defeat_event_id = current_event_data.object_id
	
	# reset values and store current RunStatsData in ProfileData run history
	_on_combat_ended() # treats combat as finished and adds last combat to run stats
	
	if not TRACK_COMBAT:
		# no tracking; delete combat stats entirely
		current_run_stats.run_combat_stats.clear()
	elif not TRACK_COMBAT_STATS:
		# delete stats from combat and run
		for combat_stats: CombatStatsData in current_run_stats.run_combat_stats:
			combat_stats.turn_stats.clear()
			combat_stats.total_stats.clear()
	if not TRACK_RUN_STATS:
		current_run_stats.run_total_stats.clear()
		
	# add run to profile
	Global.profile_data.profile_run_history.append(current_run_stats)
	# remove oldest entries if over max tracking
	if len(Global.profile_data.profile_run_history) > RUN_HISTORY_ENTRIES_MAX and RUN_HISTORY_ENTRIES_MAX > 0:
		Global.profile_data.profile_run_history.pop_front()
	
	current_run_stats = null # null out for next run

#region Turns/Combat

func get_turn_count() -> int:
	if current_combat_stats == null:
		breakpoint
		DebugLogger.log_error("StatsHandler.get_turn_count(): No combat happening")
		return 0
	return current_combat_stats.turn_count

func _on_run_ended() -> void:
	current_run_stats = null

func _on_combat_started(event_id: String) -> void:
	turn_count = 1
	# derive floor from the current location's floor number
	var current_floor: int = Global.get_player_current_floor()
	# generate new combat stats instance
	current_combat_stats = CombatStatsData.new(event_id, current_floor)
	current_combat_stats.initialize_stats()

func _on_combat_ended() -> void:
	if current_combat_stats != null:
		# remove these to save card plays after they're not needed for run history
		current_combat_stats.cards_played_this_combat.clear()
		current_combat_stats.cards_played_this_turn.clear()
		
		current_run_stats.run_combat_stats.append(current_combat_stats)
	
	current_combat_stats = null
	
	# track combat victories in run stats
	if current_run_stats != null:
		var location_data: LocationData = Global.get_player_location_data()
		match location_data.location_type:
			LocationData.LOCATION_TYPES.COMBAT:
				current_run_stats.add_to_enum_stat(RunStatsData.STATS.COMBAT_STANDARD_COUNT, 1)
			LocationData.LOCATION_TYPES.MINIBOSS:
				current_run_stats.add_to_enum_stat(RunStatsData.STATS.COMBAT_MINIBOSS_COUNT, 1)
			LocationData.LOCATION_TYPES.BOSS:
				current_run_stats.add_to_enum_stat(RunStatsData.STATS.COMBAT_BOSS_COUNT, 1)
				

func _on_player_turn_started():
	is_player_turn = true

func _on_player_turn_ended():
	is_player_turn = false

func _on_enemy_turn_ended():
	turn_count += 1
	if current_combat_stats != null:
		current_combat_stats.turn_count += 1
		current_combat_stats.reset_turn_stats()
		# move cards played over and reset it
		cards_played_this_combat.append(cards_played_this_turn)
		cards_played_this_turn = []

#endregion

#region Custom Signals

func _on_custom_signal(custom_signal_id: String, values: Dictionary[String, Variant]) -> void:
	var custom_signal_data: CustomSignalData = Global.get_custom_signal_data(custom_signal_id)
	var stat_amount: int = values["value_amount"]
	add_to_stat(custom_signal_data.custom_signal_stat_name, stat_amount)

#region Card Plays

func _on_card_played(card_play_request: CardPlayRequest) -> void:
	cards_played_this_turn.append(card_play_request)
	_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_PLAYED, 1)

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

## Gets a total stat over the entire run. Includes both RunStatsData and CombatStatsData STATS.
func get_run_total_stat(stat_name: String) -> int:
	if current_run_stats == null:
		breakpoint
		DebugLogger.log_error("StatsHandler.get_run_total_stat(): No current run happening")
		return 0
	else:
		return current_run_stats.get_run_total_stat(stat_name)

## Gets a total stat for the current instance of combat
func get_combat_total_stat(stat_name: String) -> int:
	if current_combat_stats == null:
		breakpoint
		DebugLogger.log_error("StatsHandler.get_combat_total_stat(): No current combat happening")
		return 0
	else:
		return current_combat_stats.get_total_stat(stat_name)

func get_combat_turn_stat(stat_name: String) -> int:
	return current_run_stats.get_run_turn_stat(stat_name)

func _reset_turn_stats() -> void:
	if current_combat_stats != null:
		current_combat_stats.reset_turn_stats()

## Helper method to convert stat enum to string representation.
## This is important to do for tracking both in run stats and combat stats, as they become combined.
func _get_combat_stat_name(stat_enum: int) -> String:
	if stat_enum < len(CombatStatsData.STATS.keys()):
		return CombatStatsData.STATS.keys()[stat_enum]
	else:
		breakpoint
		DebugLogger.log_error("StatHander._get_combat_stat_name(): stat_enum {0} exceeds CombatStatsData.STATS size and cannot be valid".format([stat_enum]))
	return ""

func _get_run_stat_name(stat_enum: int) -> String:
	if stat_enum < len(RunStatsData.STATS.keys()):
		return RunStatsData.STATS.keys()[stat_enum]
	else:
		breakpoint
		DebugLogger.log_error("StatHander._get_run_stat_name(): stat_enum {0} exceeds RunStatsData.STATS size and cannot be valid".format([stat_enum]))
	return ""

## Adds a value to this turn's stats for a given hard coded CombatStatsData.STATS
## NOTE: This is only used for combat event hooks internally.
func _add_to_combat_enum_stat(stat_enum: int, stat_amount: int) -> void:
	if current_combat_stats != null:
		# convert the combat enum stat to a stat name and then apply to both
		var stat_name: String = current_combat_stats._get_stat_name(stat_enum)
		add_to_stat(stat_name, stat_amount)

## Adds a value to a given custom stat. Can accept custom stats.
## If combat is happening will add to that as well.
func add_to_stat(stat_name: String, stat_amount: int) -> void:
	current_run_stats.add_to_stat(stat_name, stat_amount) # add to run stat
	if current_combat_stats != null:
		current_combat_stats.add_to_turn_stat(stat_name, stat_amount)

## Gets an enum stat for this turn if combat is happening.
func get_turn_enum_stat(stat_enum: int) -> int:
	if current_combat_stats != null:
		return current_combat_stats.get_turn_enum_stat(stat_enum)
	return 0

## Gets an enum stat for this combat if combat is happening.
func get_total_enum_stat(stat_enum: int) -> int:
	if current_combat_stats != null:
		return current_combat_stats.get_total_enum_stat(stat_enum)
	return 0

#endregion

#region Run Stat Tracking Hooks

func _on_player_money_changed(money_delta: int) -> void:
	if current_run_stats == null:
		return
	# gained money
	if money_delta > 0:
		current_run_stats.add_to_enum_stat(RunStatsData.STATS.MONEY_GAINED_AMOUNT, money_delta)
	# lost money
	if money_delta < 0:
		var abs_money_delta: int = abs(money_delta)
		current_run_stats.add_to_enum_stat(RunStatsData.STATS.MONEY_SPENT_AMOUNT, abs_money_delta)

func _on_rest_action_ended(rest_action_id: String) -> void:
	if current_run_stats == null:
		return
	if rest_action_id == "":
		return
	var rest_action_data: RestActionData = Global.get_rest_action_data(rest_action_id)
	if rest_action_data == null:
		DebugLogger.log_error("StatsHandler: No RestActionData with id of \"{0}\"".format([rest_action_id]))
		breakpoint
		return
	if rest_action_data.rest_action_stat_name == "":
		return
	
	current_run_stats.add_to_stat(rest_action_data.rest_action_stat_name, 1)

func _on_shop_visited_first_time() -> void:
	if current_run_stats == null:
		return
	current_run_stats.add_to_enum_stat(RunStatsData.STATS.SHOPS_VISITED_AMOUNT, 1)

#endregion
#region Combat Stat Tracking Hooks

func _on_combatant_block_broken(base_combatant: BaseCombatant):
	if base_combatant.is_in_group("enemies"):
		_add_to_combat_enum_stat(CombatStatsData.STATS.ENEMY_BLOCK_BROKEN_COUNT, 1)
	if base_combatant.is_in_group("players"):
		_add_to_combat_enum_stat(CombatStatsData.STATS.PLAYER_BLOCK_BROKEN_COUNT, 1)
func _on_combatant_blocked(base_combatant: BaseCombatant, amount_blocked: int):
	if base_combatant.is_in_group("enemies"):
		_add_to_combat_enum_stat(CombatStatsData.STATS.ENEMY_BLOCKED_AMOUNT, amount_blocked)
		_add_to_combat_enum_stat(CombatStatsData.STATS.ENEMY_BLOCKED_COUNT, 1)
	if base_combatant.is_in_group("players"):
		_add_to_combat_enum_stat(CombatStatsData.STATS.PLAYER_BLOCKED_AMOUNT, amount_blocked)
		_add_to_combat_enum_stat(CombatStatsData.STATS.PLAYER_BLOCKED_AMOUNT, 1)
func _on_combatant_damaged(base_combatant: BaseCombatant, unblocked_damage: int, zero_capped_damage: int, overkill_damage: int):
	if base_combatant.is_in_group("enemies"):
		_add_to_combat_enum_stat(CombatStatsData.STATS.ENEMY_DAMAGED_AMOUNT, unblocked_damage)
		_add_to_combat_enum_stat(CombatStatsData.STATS.ENEMY_DAMAGED_CAPPED_AMOUNT, zero_capped_damage)
		_add_to_combat_enum_stat(CombatStatsData.STATS.ENEMY_DAMAGED_OVERKILL_AMOUNT, overkill_damage)
	if base_combatant.is_in_group("players"):
		# no need to track capped and overkill damage for player
		_add_to_combat_enum_stat(CombatStatsData.STATS.PLAYER_DAMAGED_AMOUNT, unblocked_damage)
		_add_to_combat_enum_stat(CombatStatsData.STATS.PLAYER_DAMAGED_COUNT, 1)

func _on_enemy_killed(_enemy: Enemy):
	_add_to_combat_enum_stat(CombatStatsData.STATS.ENEMIES_KILLED, 1)

func _on_card_drawn(_card_data: CardData) -> void:
	_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_DRAWN, 1)
func _on_card_discarded(_card_data: CardData, is_manual_discard: bool) -> void:
	if is_manual_discard:
		_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_DISCARDED, 1)
	else:
		_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_DISCARDED_NATURAL, 1)
func _on_card_exhausted(_card_data: CardData) -> void:
	_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_EXHAUSTED, 1)
func _on_card_banished(_card_data: CardData, in_limbo: bool) -> void:
	if not in_limbo:
		_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_EXHAUSTED, 1)
func _on_card_retained(_card_data: CardData) -> void:
	_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_RETAINED, 1)
func _on_card_upgraded(_card_data: CardData) -> void:
	_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_UPGRADED, 1)
func _on_card_created(_card_data: CardData) -> void:
	_add_to_combat_enum_stat(CombatStatsData.STATS.CARDS_CREATED, 1)
	
func _on_card_deck_shuffled(is_reshuffle: bool) -> void:
	if is_reshuffle:
		_add_to_combat_enum_stat(CombatStatsData.STATS.DECK_RESHUFFLED, 1)

#endregion
