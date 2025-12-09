## Helper singleton. Provides deterministic randomization methods. See: PlayerData.get_player_rng()
## for actually getting a RandomNumberGenerator to use for these methods.
extends Node

## General random method. Shuffles an array deterministically using a given rng.
func shuffle_array(rng: RandomNumberGenerator, array) -> Array:
	for i in array.size():
		var rand_idx = rng.randi_range(0,array.size()-1)
		if rand_idx == i:
			pass
		else:
			var temp = array[rand_idx]
			array[rand_idx] = array[i]
			array[i] = temp
	return array

## Wrapper method to shuffle an array then slice it to N first elements
func shuffle_slice_array(rng: RandomNumberGenerator, array: Array, index: int = len(array)) -> Array:
	# shuffle the pack and pick the first N number of them
	var new_array = Random.shuffle_array(rng, array)
	if len(new_array) > 0 and index >= 0:
		# ensure slice can never exceed bounds of array
		# negative slices will simply include entire array
		var slice_width: int = clamp(index, 0, len(new_array))
		new_array = new_array.slice(0, slice_width)
	
	return new_array

## General random method. Randomly selects a variant object from a list of objects given a mapping of the objects to their
## respective weights.
func get_weighted_selection(rng: RandomNumberGenerator, weights: Dictionary[Variant, int]) -> Variant:
	if len(weights.keys()) > 0:
		# generate weighted buckets using the weight of each object
		# a weight of [1,2,1] would produce buckets of [1,3,4]
		var weight_total: int = 0
		var weight_buckets: Dictionary = {}
		var weight_keys: Array = weights.keys()
		for weighted_object: Variant in weight_keys:
			var weight: int = weights[weighted_object]
			weight_total += weight
			weight_buckets[weighted_object] = weight_total
		
		# randomly select a bucket
		var random_weight: int = rng.randi() % max(weight_total, 1)
		var bottom_weight: int = 0
		var first_object: Variant = weight_keys[0]
		for weighted_object: Variant in weight_keys:
			var weight_bucket: int = weight_buckets[weighted_object]
			if bottom_weight <= random_weight and random_weight < weight_bucket:
				return weighted_object
			else:
				bottom_weight = weight_bucket
		
		return first_object
	
	return null
	
func test_weighted_selection(weights: Dictionary[Variant, int]) -> void:
	var rng_enemy_spawning: RandomNumberGenerator = RandomNumberGenerator.new()
	
	var weight_results: Dictionary[Variant, int] = {}
	
	for i in 1000:
		var selected_object: Variant = Random.get_weighted_selection(rng_enemy_spawning, weights)
		var weight: int = weight_results.get(selected_object, 0)
		weight += 1
		weight_results[selected_object] = weight
	
	print(weight_results)

### Drafting Cards

## Randomly gets a number of cards from the player's card pool and returns a list of them.
## This ignores weighting.
func generate_unweighted_card_draft(rng: RandomNumberGenerator, number_of_cards: int) -> Array[CardData]:
	var returned_cards: Array[CardData] = []
	
	# randomize ordered list of all player card pool
	var card_pool_ids: Array = Global.player_data.player_reward_card_filter_cache.convert_to_unique_card_object_ids()
	card_pool_ids = shuffle_slice_array(rng, card_pool_ids, number_of_cards)
	returned_cards = Global.get_card_data_from_prototypes(card_pool_ids)
	return returned_cards


## Given a specific card pack, generates an unweighted draft.
func generate_unweighted_card_draft_from_card_pack_id(rng: RandomNumberGenerator, card_pack_id: String, number_of_cards: int) -> Array[CardData]:
	var returned_cards: Array[CardData] = []
	var cached_card_filter: CardFilter = Global.get_cached_card_filter(card_pack_id)
	var card_ids: Array[String] = cached_card_filter.convert_to_unique_card_object_ids()
	
	card_ids = shuffle_slice_array(rng, card_ids, number_of_cards)
	
	returned_cards = Global.get_card_data_from_prototypes(card_ids)
	return returned_cards

enum CARD_DRAFT_TABLE_TYPES {STANDARD, MINIBOSS, BOSS, SHOP}

const CARD_DRAFT_RARITY_WEIGHTS: Dictionary = {
	CARD_DRAFT_TABLE_TYPES.STANDARD: 
		{
		CardData.CARD_RARITIES.COMMON: 55,
		CardData.CARD_RARITIES.UNCOMMON: 43,
		CardData.CARD_RARITIES.RARE: 2,
		},
	CARD_DRAFT_TABLE_TYPES.MINIBOSS: 
		{
		CardData.CARD_RARITIES.COMMON: 50,
		CardData.CARD_RARITIES.UNCOMMON: 40,
		CardData.CARD_RARITIES.RARE: 10,
		},
	CARD_DRAFT_TABLE_TYPES.BOSS: 
		{
		CardData.CARD_RARITIES.COMMON: 0,
		CardData.CARD_RARITIES.UNCOMMON: 0,
		CardData.CARD_RARITIES.RARE: 100,
		},
	CARD_DRAFT_TABLE_TYPES.SHOP: 
		{
		CardData.CARD_RARITIES.COMMON: 55,
		CardData.CARD_RARITIES.UNCOMMON: 40,
		CardData.CARD_RARITIES.RARE: 5,
		},
	
}	# affects the chances of a card being seen during a rarity weighted draft

func generate_rarity_weighted_card_draft(rng: RandomNumberGenerator, number_of_cards, card_draft_table_type: int = CARD_DRAFT_TABLE_TYPES.STANDARD, use_pity_system: bool = true) -> Array[CardData]:
	# randomly gets a number of cards from the card pool and returns a list of them
	# factors in card rarity and a pity system
	var returned_cards: Array[CardData] = []
	
	# get the desired loot table weights
	var loot_table: Dictionary[Variant, int] = {}
	loot_table.assign(CARD_DRAFT_RARITY_WEIGHTS[card_draft_table_type].duplicate(true))
	# get cards available to player sorted by rarity, duplicated to allow mutation
	var player_reward_card_rarity_cache: Dictionary[int, Array] = Global.player_data.player_reward_card_rarity_cache.duplicate(true)
	var card_ids_in_draft: Array[String] = []
	
	if use_pity_system:
		# rare cards show up and commons show up less
		var player_rare_card_modifier_current: int = int(floor(Global.player_data.player_rare_card_modifier_current))
		var rare: Variant = CardData.CARD_RARITIES.RARE # typecasting into Variant to get around Dict[Variant,] bug
		var common: Variant = CardData.CARD_RARITIES.COMMON # typecasting into Variant to get around Dict[Variant,] bug
		loot_table[rare] = loot_table[rare] + player_rare_card_modifier_current
		loot_table[common] = loot_table[common] - player_rare_card_modifier_current
	
	
	var rarity_to_card_pool: Dictionary = {} # cached card pools per rarity ensures no duplicates
	var rare_card_found: bool = false
	
	# get all the card ids for this draft, using randomly weighted selection of rarity buckets
	for i in number_of_cards:
		# determine what bucket of rarity the roll falls in
		var selected_card_rarity: int = CardData.CARD_RARITIES.COMMON
		selected_card_rarity = get_weighted_selection(rng, loot_table)
		
		
		if player_reward_card_rarity_cache.has(selected_card_rarity):
			# get the cards in the selected rarity bucket
			var card_id_bucket: Array = player_reward_card_rarity_cache[selected_card_rarity]
			shuffle_array(rng, card_id_bucket)
			var selected_card_id: String = ""
			
			# go through the bucket until emptied or a non duplicate card is found
			while selected_card_id == "" and len(card_id_bucket) > 0:
				selected_card_id = card_id_bucket.pop_back()
				if card_ids_in_draft.has(selected_card_id):
					selected_card_id = ""
			
			if selected_card_id == "":
				DebugLogger.log_warning("Random.generate_rarity_weighted_card_draft(): Insufficient cards IDs in rarity bucket {0} for drafting".format([selected_card_rarity]))
			else:
				card_ids_in_draft.append(selected_card_id)
			
				# pity system
				if use_pity_system:
					if selected_card_rarity == CardData.CARD_RARITIES.RARE:
						rare_card_found = true
					if selected_card_rarity == CardData.CARD_RARITIES.COMMON:
						# finding a common card increases the pity weighting
						Global.player_data.player_rare_card_modifier_current += Global.player_data.player_rare_card_increment_rate
	
	# convert card ids into card prototypes
	returned_cards = Global.get_card_data_from_prototypes(card_ids_in_draft)
	
	return returned_cards


### Artifacts

#func generate_artifact_rewards(reward_rng: RandomNumberGenerator, number_of_artifacts: int, allow_duplicate_artifacts: bool = false) -> Array[String]:
	# DEPRECATED; ARTIFACTS USE A POOL TO PULL FROM RATHER THAN LOCATION RNG
	## randomly gets a number of artifact ids from the artifact pool and returns a list of them
	#var returned_artifact_ids: Array[String] = []
	#
	## randomize ordered list of all artifacts using a seed
	#var artifact_pool_ids: Array = Global._id_to_artifact_data.keys().duplicate(true)	# get all possible artifacts
	#artifact_pool_ids.shuffle()
	#
	## pop off a artifact from the list until number of artifacts have been added to draft
	#var counter: int = number_of_artifacts
	#while counter > 0 and len(artifact_pool_ids) > 0:
		#var artifact_id: String = artifact_pool_ids.pop_front()
		#
		#var player_has_artifact: bool = Global.player_data.player_id_to_artifact_data.keys().has(artifact_id)
		## get artifacts player doesn't have
		#if !player_has_artifact or allow_duplicate_artifacts:
			#returned_artifact_ids.append(artifact_id)
			#counter -= 1
	#
	#return returned_artifact_ids

### Consumables

func get_random_consumable_object_id(rng: RandomNumberGenerator, whitelisted_consumable_object_ids: Array[String] = [], blacklisted_consumable_object_ids: Array[String] = []) -> String:
	var potential_consumable_object_ids = whitelisted_consumable_object_ids
	if len(potential_consumable_object_ids) == 0:
		potential_consumable_object_ids = Global._id_to_consumable_data.keys().duplicate()
	
	shuffle_array(rng, potential_consumable_object_ids)
	
	for consumable_object_id in potential_consumable_object_ids:
		if not blacklisted_consumable_object_ids.has(consumable_object_id):
			return consumable_object_id
	return ""
	
### Locations


## Gets the card rewards for the player at the player's current location.
## NOTE: If this is empty either the player's card packs are empty, the card draft cache is not
## (re)generated, or there's not enough cards to draft 
func get_location_card_rewards(location_data: LocationData = Global.get_player_location_data()) -> Array:
	# returns array of array of cards representing multiple drafts
	var card_draft_rewards: Array[Array] = []
	# get the number of drafts and cards per draft from run data
	var number_of_drafts: int = Global.player_data.reward_drafts
	var cards_per_draft: int = Global.player_data.reward_cards_per_draft
	
	# determine the loot table to use for the reward
	var card_draft_table_type: int = CARD_DRAFT_TABLE_TYPES.STANDARD
	if location_data.location_type == LocationData.LOCATION_TYPES.MINIBOSS:
		card_draft_table_type = CARD_DRAFT_TABLE_TYPES.MINIBOSS
	if location_data.location_type == LocationData.LOCATION_TYPES.BOSS:
		card_draft_table_type = CARD_DRAFT_TABLE_TYPES.BOSS
	
	var rng_reward_card_drafts: RandomNumberGenerator = Global.player_data.get_player_rng("rng_reward_card_drafts")
	for i in number_of_drafts:
		var card_draft: Array[CardData] = generate_rarity_weighted_card_draft(rng_reward_card_drafts, cards_per_draft, card_draft_table_type, true)
		card_draft_rewards.append(card_draft)
		
	return card_draft_rewards

func get_location_money_reward(location_data: LocationData = Global.get_player_location_data()) -> int:
	var rng_reward_money: RandomNumberGenerator = Global.player_data.get_player_rng("rng_reward_money")
	return 25 + (rng_reward_money.randi() % 25)

## Maps the chances of receiving a certain type of artifact from opening a chest.
const ARTIFACT_CHEST_RARITY_WEIGHTS: Dictionary[Variant, int] = {
	ArtifactData.ARTIFACT_RARITIES.COMMON: 50,
	ArtifactData.ARTIFACT_RARITIES.UNCOMMON: 35,
	ArtifactData.ARTIFACT_RARITIES.RARE: 15,
}
## Maps the chances of receiving a certain type of artifact from opening a chest.
const ARTIFACT_MINIBOSS_RARITY_WEIGHTS: Dictionary[Variant, int] = {
	ArtifactData.ARTIFACT_RARITIES.COMMON: 25,
	ArtifactData.ARTIFACT_RARITIES.UNCOMMON: 50,
	ArtifactData.ARTIFACT_RARITIES.RARE: 25,
}

func get_location_artifact_rewards(location_data: LocationData = Global.get_player_location_data(), artifact_count: int = 1) -> Array[String]:
	var location_type: int = location_data.location_type
	var returned_artifact_ids: Array[String] = []
	var rng_artifact_rewards: RandomNumberGenerator = Global.player_data.get_player_rng("rng_artifact_rewards")
	match location_type:
		LocationData.LOCATION_TYPES.TREASURE:
			var weights: Dictionary[Variant, int] = ARTIFACT_CHEST_RARITY_WEIGHTS
			for _i: int in artifact_count:
				var random_artifact_rarity: int = Random.get_weighted_selection(rng_artifact_rewards, weights)
				var artifact_ids: Array[String] = Global.player_data.get_next_artifacts_from_pool(artifact_count, [random_artifact_rarity], false, false, true)
				returned_artifact_ids.append_array(artifact_ids)
		LocationData.LOCATION_TYPES.MINIBOSS:
			var weights: Dictionary[Variant, int] = ARTIFACT_MINIBOSS_RARITY_WEIGHTS
			for _i: int in artifact_count:
				var random_artifact_rarity: int = Random.get_weighted_selection(rng_artifact_rewards, weights)
				var artifact_ids: Array[String] = Global.player_data.get_next_artifacts_from_pool(artifact_count, [random_artifact_rarity], false, false, true)
				returned_artifact_ids.append_array(artifact_ids)
		LocationData.LOCATION_TYPES.BOSS:
			return Global.player_data.get_next_boss_artifacts_from_pool(artifact_count, true)
	
	return returned_artifact_ids

### Shops

## Generates initial prices for given cards in a shop. This will be used in parallel to the cards.
func get_shop_card_prices(cards: Array[CardData], rng: RandomNumberGenerator = Global.player_data.get_player_rng("rng_shop")) -> Array[int]:
	var returned_prices: Array[int] = []
	for card_data: CardData in cards:
		var card_price_range_values: Array = ShopData.CARD_RARITY_TO_PRICE_RANGE.get(card_data.card_rarity, [0,1])
		var item_price_range: int = card_price_range_values[1] - card_price_range_values[0]
		var card_price: int = card_price_range_values[0] + (rng.randi() % item_price_range)
		returned_prices.append(card_price)
	return returned_prices

## Generates initial prices for given artifacts in a shop. This will be used in parallel to the artifacts.
func get_shop_artifact_prices(artifact_object_ids: Array[String], rng: RandomNumberGenerator = Global.player_data.get_player_rng("rng_shop")) -> Array[int]:
	var returned_prices: Array[int] = []
	for artifact_object_id: String in artifact_object_ids:
		var artifact_data: ArtifactData = Global.get_artifact_data(artifact_object_id)
		if artifact_data == null:
			DebugLogger.log_error("No ArtifactData of ID {0} found".format([artifact_object_id]))
			breakpoint
		else:
			var artifact_price_range_values: Array = ShopData.ARTIFACT_RARITY_TO_PRICE_RANGE.get(artifact_data.artifact_rarity, [0,1])
			var item_price_range: int = artifact_price_range_values[1] - artifact_price_range_values[0]
			var artifact_price: int = artifact_price_range_values[0] + (rng.randi() % item_price_range)
			returned_prices.append(artifact_price)
	return returned_prices

## Generates initial prices for given consumables in a shop. This will be used in parallel to the consumables.
func get_shop_consumable_prices(consumable_object_ids: Array[String], rng: RandomNumberGenerator = Global.player_data.get_player_rng("rng_shop")) -> Array[int]:
	var returned_prices: Array[int] = []
	for consumable_object_id: String in consumable_object_ids:
		var consumable_data: ConsumableData = Global.get_consumable_data(consumable_object_id)
		if consumable_data == null:
			DebugLogger.log_error("No consumableData of ID {0} found".format([consumable_object_id]))
			breakpoint
		else:
			var consumable_price_range_values: Array = ShopData.CONSUMABLE_RARITY_TO_PRICE_RANGE.get(consumable_data.consumable_rarity, [0,1])
			var item_price_range: int = consumable_price_range_values[1] - consumable_price_range_values[0]
			var consumable_price: int = consumable_price_range_values[0] + (rng.randi() % item_price_range)
			returned_prices.append(consumable_price)
	return returned_prices
