## Prototyped data; maintains mutable data about a run
## See player_character_object_id and CharacterData for read only portion.
extends PrototypeData
class_name PlayerData

## CharacterData object_id. Provides additional read only data about the character this player represents. 
@export var player_character_object_id: String = ""
@export var player_health: int = 50
@export var player_health_max: int = 50

@export var player_money: int = 0

var player_energy: int = 10 # in combat energy. Not saved.
@export var player_energy_max: int = 10

var player_block: int = 0 # in combat block. Not saved.

## A json friendly dictionary containing values that can be embedded onto the player
## for extensibility, custom UI, and general mod support purposes.
## These values appear last in the action value hierarchy.
@export var player_values: Dictionary[String, Variant] = {}

### Acts and Location Data
@export var player_act: int = 1	# the act count the player is currently on
@export var player_act_max: int = 3	# the number of acts before a victory is considered. -1 means endless run
@export var player_act_id: String = "act_1"	# the ActData object_id of the act the player is currently on

## LocationData id corresponding to the location in location_id_to_location_data of where the player
## is currently located in the act.
@export var player_location_id: String = "location_0"
## Stores locations for the current act in the run
@export var location_id_to_location_data: Dictionary[String, LocationData] = {}

## Stores the shop at the player's current location, if one exists. Does not determine if there is
## a shop accessible, that is determined by the location type at player_location_id
@export var player_shop_data: ShopData = null

### RNG
@export var player_run_seed: int = 0

## Maps rng names to a random number generator "track". This allows seperate tracks of RNG to function
## independently. Whenever an rng is requested but does not yet exist, a new one will be instantiated
## using the run seed and then used. A list of "official" hardcoded rngs used or suggested by the
## framework is listed here, though they are generated ad hoc during a run. Additionally, most
## Actions can be supplied an rng_name action value to override the type of rng used.
@export var player_rng: Dictionary = {
	#"rng_general": RandomNumberGenerator.new(), # used for things that are not important if they intersect
	#"rng_world_generation": RandomNumberGenerator.new(), # used for act generation actions
	#"rng_events": RandomNumberGenerator.new(), # Used for events and run start options
	#"rng_event_pool": RandomNumberGenerator.new(), # controls randomization of event pools
	#"rng_targeting": RandomNumberGenerator.new(), # See BaseAction.TARGET_OVERRIDES.RANDOM_ENEMY
	#"rng_attack_damage": RandomNumberGenerator.new(), # See ActionAttackGenerator
	#"rng_card_picking": RandomNumberGenerator.new(), # See ActionBasePickCards
	#"rng_non_reward_card_drafting": RandomNumberGenerator.new(),
	#"rng_card_drafting": RandomNumberGenerator.new(),
	#"rng_shuffle": RandomNumberGenerator.new(), # whenever the player's deck is shuffled or reshuffled
	#"rng_pile_insert": RandomNumberGenerator.new(), # whenever the a card is randomly inserted into a pile
	#"rng_reward_card_drafts": RandomNumberGenerator.new(), # cards rewards at the end of a fight. See: Random.get_location_card_rewards()
	#"rng_reward_money": RandomNumberGenerator.new(), # money rewards at the end of a fight. See: Random.get_location_money_reward()
	#"rng_card_transforming": RandomNumberGenerator.new(), See ActionTransformCards
	#"rng_enemy_spawning": RandomNumberGenerator.new(), # See ActionSummonEnemies
	#"rng_enemy_attack_patterns": RandomNumberGenerator.new(),
	#"rng_shops": RandomNumberGenerator.new(), # used to populate shop items
	#"rng_artifact_rewards": RandomNumberGenerator.new(), # used to populate artifacts on run start, and decide artifact rarity selections
	#"rng_run_start_options": RandomNumberGenerator.new(), # controls which run start options are seen
	#"rng_enemy_spawning": RandomNumberGenerator.new(), # controls spawning weights
}

## Maintains a copy of the event ids from a given EventPoolData, used when going to a new LocationData
## with an undefined event id and defined event pool.
## Like RNG tracks, these are populated when an event from a given event pool id is requested.
## Once a pool is emptied (or no events with passing validators/blacklisted), it is reset, or a fallback event ID defined in the ascociated pool is used. 
@export var player_event_pools: Dictionary = {
	#"event_pool_object_id_1": [],
	#"event_pool_object_id_2": [],
}

## Event IDs that are permanently removed from appearing in any event pool for the remainder
## of the run.
@export var player_event_blacklisted_ids: Array[String] = []


### Combat
## Keeps track of everything that happened in a combat instance
@export var player_current_combat_stats: CombatStatsData = null
@export var player_previous_combat_stats: Array[CombatStatsData] = []

### Run modifiers
const DIFFICULTY_RUN_MODIFIER_OBJECT_IDS: Array[String] = [ # maps each difficulty modifier incrementally
	"run_modifier_difficulty_1", "run_modifier_difficulty_2", "run_modifier_difficulty_3",
	"run_modifier_difficulty_4", "run_modifier_difficulty_5",
]

@export var player_run_difficulty_level: int = 0	# current run's difficulty. Starts at 0
@export var player_run_modifier_object_ids: Array[String] = []	# all modifiers, both standard and custom, applied to this run
@export var player_available_rest_action_object_ids: Array[String] = ["rest_action_rest", "rest_action_upgrade_card", "rest_action_remove_cards", "rest_action_add_random_consumable"]	# the types of rest actions populated at rest sites

### Card Rewards

@export var reward_cards_per_draft: int = 3	# number of cards in a combat reward draft
@export var reward_drafts: int = 1 # number of drafts in a combat reward

## A generated and cached CardFilter containing all draftable cards available to the player. This is
## recompiled every time the player is made to have access to different card packs or cards via calling
## regenerate_card_draft_card_filter()
var player_reward_card_filter_cache: CardFilter = null
## All the card object ids available to the player, sorted into rarity buckets and cached. Used for weighted card drafts.
var player_reward_card_rarity_cache: Dictionary[int, Array] = {}
## The card pack ids of cards that can be drafted. Does not take effect until cache regenerated
@export var reward_draft_card_pack_ids: Array[String] = []
## Cards that can never be included in card drafts. Does not take effect until cache regenerated
@export var player_reward_draft_card_id_blacklist: Array[String] = []
## Cards that will always be included in card drafts.  Does not take effect until cache regenerated.
@export var player_reward_draft_card_id_whitelist: Array[String] = []

# pity system for drafting, to improve chances of rare cards over time. Stored as floats for precision, but converted into integers
@export var player_rare_card_modifier_current: float = 0.0	# the current modifier applied to improve rare card chances
@export var player_rare_card_modifier_base: float = 0.0: set = set_player_rare_card_modifier_base	# the value the rarity modifier is reset to after a rare card is seen
@export var player_rare_card_increment_rate: float = 1.5	# every time a card is drafted that isn't rare, increase the modifier by this amount

### Artifacts

## Maps ArtifactData object_uids to prototype instances of ArtifactData owned by the player. 
@export var player_artifact_uid_to_artifact_data: Dictionary[String, ArtifactData] = {}

## Artifact ordering for all artifacts object ids the player can see.
## Each time an artifact is seen it is popped off. Populated in initialize_artifact_pool().
## NOTE: This includes ALL artifacts, even ones from different characters that cannot be
## normally obtained in a run, and different filters will pop some while ignoring others. Doing it
## this way ensures that modifying what artifacts the player can see preserves the ordering.
## NOTE: Shops will search this in reverse order.
@export var player_artifact_pool: Array[String] = []

## A list of ArtifactData object ids that represent what artifacts a player is allowed to see in a run.
## Typically will be their color, and white(non specific) artifacts. This is used to 
## generate player_artifact_available_artifact_id_cache. Whenever this value is modified you
## should regenerate the cache.
@export var player_artifact_pack_ids: Array[String] = []

## A generated cache of all artifact object ids that the player is *capable* of seeing,
## derived from player_artifact_pack_ids. This behaves like a Set, only using the keys for
## efficient .has() checks, with null for values. If player_artifact_pack_ids is modified, call
## regenerate_artifact_available_id_cache().
## NOTE: This differs from player_artifact_pool in that the artifact pool maintains ordering of all possible
## artifacts, while player_artifact_available_artifact_id_cache acts as a filter.
var player_artifact_available_artifact_id_cache: Dictionary[String, Variant] = {
	#"<artifact_object_id>": null
}

### Cards

## The player's permanent deck, persisting between combat. Changes to cards here will be
## permanent.
@export var player_deck: Array[CardData] = []

# in combat
## How many cards player naturally draws at start of turn. See: ActionGenerator.generate_start_of_turn_draw_actions().
const PLAYER_CARD_DRAW_PER_TURN: int = 5
## The default max number of cards available in player's hand. Exceeding this will discard the cards.
## Intercept ActionAddCardsToHand and ActionDraw's hand_card_count_max to adjust the max hand size.
const PLAYER_DEFAULT_HAND_CARD_COUNT_MAX: int = 10

# comat related card piles. These are reset before and after combat and not saved.
var player_discard: Array[CardData] = []
var player_exhaust: Array[CardData] = []
var player_draw: Array[CardData] = []
var player_hand: Array[CardData] = []

### Statuses

## Maps status effect id to Array[BaseStatusEffect], allowing for potential duplicate status types.
var player_status_effects: Dictionary[String, Array] = {}

### Consumables
@export var player_consumable_slot_count: int = 3	# max number of slots available
@export var player_consumable_slot_to_consumable_object_id: Dictionary[String, String] = {}	# maps a numerical slot index to a consumable id. 0 indexed

## Used as a general post-processing instantiation method after creating a
## new PlayerData instance or loading the game.
## Not the same as _init()
func init():
	_connect_signals()
	generate_cache()

func _connect_signals() -> void:
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)

## Forces a regeneration of all internal cached data structures.
func generate_cache() -> void:
	regenerate_card_draft_card_filter()
	regenerate_artifact_available_id_cache()

func _on_combat_started(event_id: String) -> void:
	player_current_combat_stats = CombatStatsData.new(event_id)

func _on_combat_ended() -> void:
	if player_current_combat_stats != null:
		player_previous_combat_stats.append(player_current_combat_stats)
	player_current_combat_stats = null

func add_money(amount: int) -> void:
	player_money = max(player_money + amount, 0)
	Signals.player_money_changed.emit()

## Gets an rng track for the run. If it does not exist create one.
func get_player_rng(rng_name: String) -> RandomNumberGenerator:
	if player_rng.has(rng_name):
		return player_rng[rng_name]
	
	# create and store new track
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = player_run_seed
	player_rng[rng_name] = rng
	return rng

### Rest actions

func enable_rest_action(rest_action_object_id: String) -> void:
	# enables a rest action to populate at future rest sites
	if not player_available_rest_action_object_ids.has(rest_action_object_id):
		player_available_rest_action_object_ids.append(rest_action_object_id)

func disable_rest_action(rest_action_object_id: String) -> void:
	# disables a rest action from being populated at future rest sites
	player_available_rest_action_object_ids.erase(rest_action_object_id)

### Event Pools

## Obtains the next valid event from a given EventPoolData ID. If it does not exist, it will populate
## A copy of the pool into the player's event pools
func get_next_event_object_id_from_pool(event_pool_object_id: String) -> String:
	var next_event_object_id: String = "" # the returned event
	
	var event_pool_data: EventPoolData = Global.get_event_pool_data(event_pool_object_id)
	assert(event_pool_data != null)
	
	# get events in pool if they exist
	var event_pool_event_object_ids: Array[String] = []
	event_pool_event_object_ids.assign(player_event_pools.get(event_pool_object_id, []))
	
	# populate the event pool if it doesn't exist or is empty
	if len(event_pool_event_object_ids) == 0:
		var message: String = "Event Pool Empty; Populating {0}...".format([event_pool_object_id])
		DebugLogger.log_line(message, Color.YELLOW)
		# copy event ids from corresponding event pool
		for event_object_id: String in event_pool_data.event_pool_event_object_ids:
			if not event_pool_event_object_ids.has(event_object_id):
				event_pool_event_object_ids.append(event_object_id)
			
		# randomize the order and assign to the player event pools
		var rng_event_pool: RandomNumberGenerator = get_player_rng("rng_event_pool")
		event_pool_event_object_ids = Random.shuffle_array(rng_event_pool, event_pool_event_object_ids)
		player_event_pools[event_pool_object_id] = event_pool_event_object_ids
		
		message = "Event Pool Repopulated: {0}".format([str(event_pool_event_object_ids)])
		DebugLogger.log_line(message, Color.WEB_GREEN)
	
	# find the first event that passes validators and store events that don't pass
	var failed_event_object_ids: Array[String] = [] # events that fail their validators and must be handled
	for event_object_id: String in event_pool_event_object_ids:
		var event_data: EventData = Global.get_event_data(event_object_id)
		
		var validators_passed: bool = event_data.validate_event()
		if validators_passed:
			next_event_object_id = event_data.object_id
			break # valid event found, no need to keep looking
		
	# handle each failed event according to its strategy for how it should be put back into the
	# event pool.
	for failed_event_object_id: String in failed_event_object_ids:
		var event_data: EventData = Global.get_event_data(failed_event_object_id)
		#TODO
		var validator_failed_strategy = event_data.location_event_pool_validator_failed_strategy
		# if not keeping, remove it
		if not validator_failed_strategy == EventData.FailedEventPoolStrategies.KEEP:
			event_pool_event_object_ids.erase(failed_event_object_id)
		
		match validator_failed_strategy:
			EventData.FailedEventPoolStrategies.APPEND:
				event_pool_event_object_ids.append(failed_event_object_id)
			EventData.FailedEventPoolStrategies.REMOVE:
				pass # do nothing
			EventData.FailedEventPoolStrategies.REINSERT:
				# randomly insert the event somewhere along the pool
				var rng_event_pool: RandomNumberGenerator = get_player_rng("rng_event_pool")
				var random_index: int = rng_event_pool.randi_range(0, len(event_pool_event_object_ids))
				event_pool_event_object_ids.insert(random_index, failed_event_object_id)
			EventData.FailedEventPoolStrategies.BLACKLIST:
				player_event_blacklisted_ids.append(failed_event_object_id)
	
	# attempt fallback of empty/invalid pool
	if next_event_object_id == "":
		next_event_object_id = event_pool_data.event_pool_fallback_event_object_id
		
	assert(next_event_object_id != "")
	
	# remove the event from the pool
	event_pool_event_object_ids.erase(next_event_object_id)
	player_event_pools[event_pool_object_id] = event_pool_event_object_ids
	
	# display the event
	var message: String = "Event Pool: {0} popped from {1}".format([next_event_object_id, event_pool_object_id])
	DebugLogger.log_line(message)
	
	return next_event_object_id


### Consumables

func are_consumable_slots_full() -> bool:
	return len(player_consumable_slot_to_consumable_object_id.keys()) >= player_consumable_slot_count

func get_consumable_in_slot(consumable_slot: int) -> ConsumableData:
	if player_consumable_slot_to_consumable_object_id.has(str(consumable_slot)):
		var consumable_object_id: String = player_consumable_slot_to_consumable_object_id[str(consumable_slot)]
		return Global.get_consumable_data(consumable_object_id)
	return null
	
func get_empty_consumable_slot_count() -> int:
	return player_consumable_slot_count - len(player_consumable_slot_to_consumable_object_id.keys())

### Health

func heal_percentage(percent: float):
	var percentage_health: int = int(ceil(float(Global.player_data.player_health_max) * percent))
	add_health(percentage_health, 0)

func add_health(health_amount: int, health_amount_max: int = 0) -> void:
	# wrapper method
	# adds or removes relative health
	set_health(player_health + health_amount, player_health_max + health_amount_max)

func set_health(health_amount: int, health_amount_max: int = player_health_max) -> void:
	player_health_max = max(1, health_amount_max)
	player_health = clamp(0, health_amount, player_health_max)
	Signals.player_health_changed.emit()

### Deck

func get_pile(card_pick_type: int) -> Array[CardData]:
	match card_pick_type:
		ActionBasePickCards.CARD_PICK_TYPES.HAND:
			return player_hand
		ActionBasePickCards.CARD_PICK_TYPES.DECK:
			return player_deck
		ActionBasePickCards.CARD_PICK_TYPES.COMBAT_DECK:
			var combat_deck: Array[CardData] = []
			combat_deck += player_draw
			combat_deck += player_discard
			combat_deck += player_hand
			return combat_deck
		ActionBasePickCards.CARD_PICK_TYPES.DRAW:
			return player_draw
		ActionBasePickCards.CARD_PICK_TYPES.DISCARD:
			return player_discard
		ActionBasePickCards.CARD_PICK_TYPES.EXHAUST:
			return player_exhaust
		
		ActionBasePickCards.CARD_PICK_TYPES.PLAYED_THIS_TURN:
			return player_current_combat_stats.get_card_data_played_this_turn(false)
		ActionBasePickCards.CARD_PICK_TYPES.PLAYED_LAST_TURN:
			return player_current_combat_stats.get_card_data_played_last_turn(false)
		
	return player_hand


func add_card_to_deck(card_data: CardData) -> void:
	player_deck.append(card_data)
	
	var card_play_request: CardPlayRequest = CardPlayRequest.new()
	card_play_request.card_data = card_data
	card_play_request.selected_target = null
	var player: Player = Global.get_player()
	var card_add_to_deck_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_add_to_deck_actions, null)
	ActionHandler.add_actions(card_add_to_deck_actions)
	
	Signals.card_added_to_deck.emit(card_data)

func remove_card_from_deck(card_data: CardData) -> void:
	player_deck.erase(card_data)
	
	var card_play_request: CardPlayRequest = CardPlayRequest.new()
	card_play_request.card_data = card_data
	card_play_request.selected_target = null
	var player: Player = Global.get_player()
	var card_remove_from_deck_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_remove_from_deck_actions, null)
	ActionHandler.add_actions(card_remove_from_deck_actions)
	
	Signals.card_removed_from_deck.emit(card_data)

func transform_card_in_deck(card_data: CardData, new_card_object_id: String) -> void:
	# perform transform actions on old card
	var card_play_request: CardPlayRequest = CardPlayRequest.new()
	card_play_request.card_data = card_data
	card_play_request.selected_target = null
	var player: Player = Global.get_player()
	var card_transform_in_deck_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_transform_in_deck_actions, null)
	ActionHandler.add_actions(card_transform_in_deck_actions)
	
	# remove the card, transform it, and re-add it to player's deck, triggering all relevant card actions
	remove_card_from_deck(card_data)
	card_data.transform_card(new_card_object_id)
	add_card_to_deck(card_data)
	
	Signals.card_transformed_in_deck.emit(card_data)

### Run Artifacts

## Generates a list of all artifacts the player can theoretically encounter in a run. Should only be called
## on run start from Global.start_run().
func initialize_artifact_pool() -> void:
	var artifact_ids: Array = Global._id_to_artifact_data.keys().duplicate(true) # get all artifacts
	var artifact_rng: RandomNumberGenerator = get_player_rng("rng_artifact_rewards")
	Random.shuffle_array(artifact_rng, artifact_ids)
	player_artifact_pool.assign(artifact_ids)

## Wrapper method for get_next_artifacts_from_pool() that gets the next standard artifacts for a shop.
## Pulls from the back of the artifact list.
func get_next_shop_standard_artifacts_from_pool(artifact_count: int, mutate_artifact_pool: bool = true) -> Array[String]:
	return get_next_artifacts_from_pool(artifact_count, ArtifactData.STANDARD_ARTIFACT_RARITIES, false, true, mutate_artifact_pool)
## Wrapper method for get_next_artifacts_from_pool() that gets the next artifacts that can ONLY be obtained from the shop.
## Pulls from the back of the list
func get_next_shop_specific_artifacts_from_pool(artifact_count: int, mutate_artifact_pool: bool = true) -> Array[String]:
	return get_next_artifacts_from_pool(artifact_count, [ArtifactData.ARTIFACT_RARITIES.SHOP], false, true, mutate_artifact_pool)
func get_next_boss_artifacts_from_pool(artifact_count: int, mutate_artifact_pool: bool = true) -> Array[String]:
	return get_next_artifacts_from_pool(artifact_count, [ArtifactData.ARTIFACT_RARITIES.BOSS], false, false, mutate_artifact_pool)

## General use method for returning the next artifacts available to the player, from the list of
## all artifacts.
## use_rarity_ordering = true means that the method will exhaustively search all available artifacts
## to ensure that rarity is used up. Failing to find any remaining artifacts of that rarity, it will
## fall back to other rarities. If false, it will use the first artifact that matches any of the
## given rarities provided.
## mutate_artifact_pool = false will ensure the artifacts are not removed from the list, allowing you to simply
## get the next results without modifying it.
func get_next_artifacts_from_pool(artifact_count: int, artifact_rarities: Array[int], use_rarity_ordering: bool = false, from_back: bool = false, mutate_artifact_pool: bool = true) -> Array[String]:
	# pops standard artifacts from the artifact pool and returns them
	var returned_artifact_ids: Array[String] = []
	if len(artifact_rarities) == 0:
		DebugLogger.log_warning("PlayerData.get_next_artifacts_from_pool() called with empty rarities")
		return []
	
	var artifact_pool: Array[String] = player_artifact_pool.duplicate()
	if from_back:
		artifact_pool.reverse()
	
	var rarity_to_artifact_ids: Dictionary[int, Array] = {}
	
	for artifact_id: String in artifact_pool:
		if not player_artifact_available_artifact_id_cache.has(artifact_id):
			continue # must be something the player can get
		if returned_artifact_ids.has(artifact_id):
			continue # must not already be drafted
		var artifact_data: ArtifactData = Global.get_artifact_data(artifact_id)
		if artifact_data == null:
			continue # must exist
		if not artifact_rarities.has(artifact_data.artifact_rarity):
			continue # must be of matching rarity

		if not use_rarity_ordering:
			# greedily get artifacts as they appear
			returned_artifact_ids.append(artifact_id)
			if len(returned_artifact_ids) >= artifact_count:
				break
		else:
			# assign the artifact to a buckets for processing later
			var rarity_bucket: Array = rarity_to_artifact_ids.get(artifact_data.artifact_rarity, [])
			rarity_bucket.append(artifact_id)
			rarity_to_artifact_ids[artifact_data.artifact_rarity] = rarity_bucket
	
	if use_rarity_ordering:
		# convert rarity buckets to a single list, in order of rarity priority
		var rarity_ordered_artifact_ids: Array = []
		for artifact_rarity: int in artifact_rarities:
			var rarity_bucket: Array = rarity_to_artifact_ids.get(artifact_rarity, [])
			rarity_ordered_artifact_ids.append_array(rarity_bucket)
		
		for artifact_id: String in rarity_ordered_artifact_ids:
			returned_artifact_ids.append(artifact_id)
			if len(returned_artifact_ids) >= artifact_count:
				break
		
	# remove entries from pool
	if mutate_artifact_pool:
		for artifact_id: String in returned_artifact_ids:
			remove_artifact_from_pool(artifact_id)
	
	return returned_artifact_ids


func remove_artifact_from_pool(artifact_object_id: String) -> void:
	player_artifact_pool.erase(artifact_object_id)

### Player Artifacts

func add_artifact(artifact_id: String) -> void:
	# adds an artifact to the player as if they obtained it
	if not player_artifact_uid_to_artifact_data.has(artifact_id):
		var artifact_data: ArtifactData = Global.get_artifact_data_from_prototype(artifact_id)
		
		if artifact_data == null:
			push_error("No artifact of id ", artifact_id)
		else:
			player_artifact_uid_to_artifact_data[artifact_data.object_uid] = artifact_data
		
			# use a temp artifact script to perform any logic if the artifact has effect when added
			var artifact_script_asset: Resource = load(artifact_data.artifact_script_path)
			var artifact_script: BaseArtifact = artifact_script_asset.new(artifact_data)
			artifact_script.add_artifact()
			Signals.player_artifacts_changed.emit()
			
			# remove artifact from spawn pool in case it wasn't already
			remove_artifact_from_pool(artifact_data.object_id)

## Removes an artifact of a given type from player. If remove_multiples = true all instances of
## a given type will be removed.
func remove_artifact(artifact_id: String, remove_multiples: bool = true) -> void:
	
	var artifacts: Array[ArtifactData] = get_player_artifacts_with_artifact_id(artifact_id)
	for artifact_data: ArtifactData in artifacts:
		# use a temp artifact script to perform any logic if the artifact has effect when removed
		var artifact_script_asset: Resource = load(artifact_data.artifact_script_path)
		var artifact_script: BaseArtifact = artifact_script_asset.new(artifact_data)
		artifact_script.remove_artifact()
		
		player_artifact_uid_to_artifact_data.erase(artifact_data.object_uid)
		Signals.player_artifacts_changed.emit()
		
		# prevents multiple of an artifact from being removed
		if not remove_multiples:
			return

func get_player_artifacts() -> Array:
	return player_artifact_uid_to_artifact_data.values()

## Gets all artifact data prototypes, if any, with the given artifact id in player's possession
func get_player_artifacts_with_artifact_id(artifact_object_id: String) -> Array[ArtifactData]:
	var returned_artifacts: Array[ArtifactData] = []
	for artifact_data: ArtifactData in player_artifact_uid_to_artifact_data.values():
		if artifact_data.object_id == artifact_object_id:
			returned_artifacts.append(artifact_data)
	
	return returned_artifacts

### Combat

func generate_combat_deck() -> Array[CardData]:
	# iterates over each card in the player's deck, making a copy of it and assigning the parent to the copied card
	var combat_deck: Array[CardData] = []
	for card_data in player_deck:
		var copied_card = card_data.duplicate(true)
		copied_card.parent_card = card_data
		combat_deck.append(copied_card)
	return combat_deck

### Misc

func set_player_rare_card_modifier_base(value: float) -> void:
	# adjusting the base also adjusts the current rarity value
	player_rare_card_modifier_base = value
	player_rare_card_modifier_current = max(player_rare_card_modifier_current, value)

## Forces PlayerData to regenerate the card filter used to determine card drafts by combining a list
## of card packs and other lists/flags. This should be called after mutating anything that should
## affect the pool of cards available to the player.
## NOTE: This implementation may not be the most efficienct, consider revision.
func regenerate_card_draft_card_filter() -> void:
	# merge all the card pack card ids together
	var card_unique_object_ids: Dictionary[String, Variant] = {}
	for reward_draft_card_pack_id: String in reward_draft_card_pack_ids:
		var card_pack_card_filter: CardFilter = Global.get_cached_card_filter(reward_draft_card_pack_id) # cache uses same id as card packs
		card_unique_object_ids.merge(card_pack_card_filter.filtered_card_unique_object_ids)
	
	# whitelisted and blacklisted card ids
	for card_object_id: String in player_reward_draft_card_id_blacklist:
		card_unique_object_ids.erase(card_object_id)
	for card_object_id: String in player_reward_draft_card_id_whitelist:
			card_unique_object_ids[card_object_id] = null
	
	# create a new filter using the read only card object ids provided
	var card_filter: CardFilter = CardFilter.new([], card_unique_object_ids.keys())
	
	# cache results
	player_reward_card_filter_cache = card_filter
	
	# sort cards into buckets by rarity
	var reward_card_rarity_buckets: Dictionary[int, Array] = {}
	for card_data: CardData in card_filter.filtered_cards:
		var bucket: Array = reward_card_rarity_buckets.get(card_data.card_rarity, [])
		bucket.append(card_data.object_id)
		reward_card_rarity_buckets[card_data.card_rarity] = bucket
	
	# cache results
	player_reward_card_rarity_cache = reward_card_rarity_buckets

## Forces PlayerData to regenerate the artifact filter used to determine artifact drafts by combining a list
## of artifact packs and other lists/flags. This should be called after mutating anything that should
## affect the pool of artifacts available to the player.
## NOTE: This implementation may not be the most efficienct, consider revision.
func regenerate_artifact_available_id_cache() -> void:
	# merge all the artifact pack artifact ids together
	var artifact_unique_object_ids: Dictionary[String, Variant] = {}
	for player_artifact_pack_id: String in player_artifact_pack_ids:
		var artifact_pack_artifact_filter: ArtifactFilter = Global.get_cached_artifact_filter(player_artifact_pack_id) # cache uses same id as artifact packs
		artifact_unique_object_ids.merge(artifact_pack_artifact_filter.filtered_artifact_unique_object_ids)
	
	# cache results
	player_artifact_available_artifact_id_cache = artifact_unique_object_ids

func _get_native_properties() -> Dictionary:
	return {
		"player_rng": RandomNumberGenerator.new(),
	}
