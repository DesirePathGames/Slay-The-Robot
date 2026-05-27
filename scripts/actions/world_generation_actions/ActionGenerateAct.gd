## Generates the world map for an act. This is called at the start of a run and end of an act.
## See: ActionGenerator.generate_act() and generate_next_act()
## Changing this script and its params should be sufficient for most use cases,
## however you can supply different scripts to an ActData.act_action_script_path if you need multiple
## generation algorithms.
extends BaseAction

func perform_action() -> void:
	# generates all world locations from a seed and stores them in PlayerData
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for action_interceptor_processor in action_interceptor_processors:
		### Set rng seed
		var rng_name: String = action_interceptor_processor.get_shadowed_action_values("rng_name", "rng_world_generation") # allows using different rng
		var rng_world_generation: RandomNumberGenerator = Global.player_data.get_player_rng(rng_name)
		
		### Get the read only act data to determine additional generation
		var act_id: String = get_action_value("act_id", "")
		var act_data: ActData = Global.get_act_data(act_id)
		var act_number: int = get_action_value("act_number", Global.player_data.player_act)
		
		## Set player act to new act
		Global.player_data.player_act_id = act_id
		Global.player_data.player_act = act_number
		
		### parameters of grid
		var floors_per_act: int = action_interceptor_processor.get_shadowed_action_values("floors_per_act", 10)
		var locations_per_floor: int = action_interceptor_processor.get_shadowed_action_values("locations_per_floor", 5)
		var location_obfuscation_rate: float = action_interceptor_processor.get_shadowed_action_values("location_obfuscation_rate", 0.5) # how often locations will be obfuscated
		var location_non_combat_event_rate: float = action_interceptor_processor.get_shadowed_action_values("location_non_combat_event_rate", 0.3) # how often locations will be a non combat event
		
		var generate_start_node: bool = act_number == 1
		const MIDDLE: int = 600
		const GRID_SPACING_X: int = 220
		const GRID_SPACING_Y: int = 100
		var BOTTOM: int = (floors_per_act + 1) * GRID_SPACING_Y
		
		var MIDDLE_INDEX: int = (locations_per_floor - 1) / 2
		var BOTTOM_LEFT: Vector2 = Vector2(MIDDLE - (GRID_SPACING_X * MIDDLE_INDEX), BOTTOM)
		
		### vars used for generation
		var location_position: Vector2 = BOTTOM_LEFT # current position in grid
		var floors: Array[Array] = [] # stores all generated locations in layers
		var location_id_counter: int = 0 # used to generate unique ids
		var floor_counter: int = 0
		
		
		
		### Generate/get starting node
		if generate_start_node:
			# creates a new starting node, mainly useful for the first act
			
			# clear existing locations; This isn't strictly necessary but clears up garbage
			Global.clear_locations()
			
			var starting_floor: Array[LocationData] = []
			var starting_location: LocationData = LocationData.new()
			# get a unique id and assign it
			starting_location.location_id = "location_0"
			Global.player_data.location_id_to_location_data["location_0"] = starting_location	# store as mapping in Global
			Global.player_data.player_location_id = starting_location.location_id
			# positioning and act
			starting_location.location_act = 1
			starting_location.location_index = Vector2(MIDDLE_INDEX, -1)
			starting_location.location_position = Vector2(MIDDLE, BOTTOM + GRID_SPACING_Y)
			starting_location.location_floor = floor_counter
			# assign a type
			starting_location.location_type = LocationData.LOCATION_TYPES.STARTING
			# assign a random event
			starting_location.location_event_object_id = "event_act_1_easy_combat_1"
			# add node to layer
			starting_floor.append(starting_location)
			floors.append(starting_floor)
		else:
			# if no starting node generated, use the location the player is currently on (presumably from last act)
			# and treat it as a "starting" node to connect to the next act
			var current_location_data: LocationData = Global.get_player_location_data()
			
			# clear existing locations; This isn't strictly necessary but clears up garbage
			Global.clear_locations()
			
			# remap the previous boss floor as it still needs to exist
			Global.player_data.location_id_to_location_data[current_location_data.location_id] = current_location_data
			
			var current_floor: Array[LocationData] = [current_location_data]
			floors.append(current_floor) # will be connected to by first floor of this act
		
		### generate each floor
		var location_id: String = ""
		for k in floors_per_act:
			var current_floor: Array[LocationData] = []
			floor_counter += 1
			### generate each node in a floor
			for i in locations_per_floor:
				# make a node
				var location: LocationData = LocationData.new()
				# get a unique id and assign it
				location_id_counter += 1
				location_id = "location_" + str(act_number) + "_" + str(location_id_counter)
				location.location_id = location_id
				Global.player_data.location_id_to_location_data[location_id] = location	# store as mapping in PlayerData
				# positioning and act
				location.location_act = act_number
				location.location_index = Vector2(i, k)
				location_position = BOTTOM_LEFT + Vector2(i * GRID_SPACING_X, -k * GRID_SPACING_Y)
				var random_x_offset = rng_world_generation.randf_range(-60.0, 60.0)
				location_position.x += random_x_offset
				location.location_position = location_position
				location.location_floor = floor_counter
				
				if k == 4:
					location.location_type = LocationData.LOCATION_TYPES.MINIBOSS
					location.location_event_pool_object_id = act_data.act_miniboss_event_pool_object_id
				elif k == 6:
					location.location_type = LocationData.LOCATION_TYPES.REST_SITE
					#location.location_event_object_id = "event_act_1_easy_combat_1"
				elif k == 5:
					location.location_type = LocationData.LOCATION_TYPES.TREASURE
					# location.location_event_object_id = "event_act_1_easy_combat_1"
					location.location_event_pool_object_id = act_data.act_easy_combat_event_pool_object_id
				elif k == 3:
					location.location_type = LocationData.LOCATION_TYPES.SHOP
				elif k < 3:
					# easy pool
					location.location_type = LocationData.LOCATION_TYPES.COMBAT
					location.location_event_pool_object_id = act_data.act_easy_combat_event_pool_object_id
				else:
					# hard pool
					location.location_type = LocationData.LOCATION_TYPES.COMBAT
					location.location_event_pool_object_id = act_data.act_hard_combat_event_pool_object_id
				
				# randomly obfuscate some location types
				if [LocationData.LOCATION_TYPES.TREASURE, LocationData.LOCATION_TYPES.COMBAT].has(location.location_type):
					if rng_world_generation.randf() < location_obfuscation_rate:
						location.location_obfuscated = true
				
				# randomly convert some to dialogue events
				if [LocationData.LOCATION_TYPES.COMBAT].has(location.location_type):
					if rng_world_generation.randf() < location_non_combat_event_rate:
						location.location_obfuscated = true
						location.location_type = LocationData.LOCATION_TYPES.EVENT
						location.location_event_pool_object_id = act_data.act_non_combat_event_pool_object_id
				
				# add node to floor
				current_floor.append(location)
				
				## connect the previous floor's nodes up to this one using adjacency rules
				if k > 0:
					var previous_floor: Array[LocationData] = floors[-1]
					# use adjacency rules for normal floors
					# connect node below this
					var previous_location: LocationData = previous_floor[i]
					previous_location.location_next_location_ids.append(location_id)
					# connect lower left node to this one
					if (i - 1) >= 0:
						previous_location = previous_floor[i - 1]
						previous_location.location_next_location_ids.append(location_id)
					# connect lower right node to this one
					if (i + 1) < locations_per_floor:
						previous_location = previous_floor[i + 1]
						previous_location.location_next_location_ids.append(location_id)
				else:
					# first normal layer of each act connects to previous layer (previous boss and act 1 starting area) regardless of adjacency
					var previous_floor: Array[LocationData] = floors[-1]
					for previous_location in previous_floor:
						previous_location.location_next_location_ids.append(location_id)
						pass

			floors.append(current_floor)
		
		### boss layer at end of act
		var boss_floor: Array[LocationData] = []
		floor_counter += 1
		# make a node
		var boss_location: LocationData = LocationData.new()
		# get a unique id and assign it
		location_id_counter += 1
		location_id = "location_" + str(act_number) + "_" + str(location_id_counter)
		boss_location.location_id = location_id
		Global.player_data.location_id_to_location_data[location_id] = boss_location	# store as mapping in Global
		# positioning and act
		boss_location.location_act = act_number
		boss_location.location_index = Vector2(MIDDLE_INDEX, floors_per_act)
		location_position = Vector2(MIDDLE, BOTTOM - (floors_per_act * GRID_SPACING_Y))
		boss_location.location_position = location_position
		boss_location.location_floor = floor_counter
		# assign a type
		boss_location.location_type = LocationData.LOCATION_TYPES.BOSS
		# assign a boss pool
		boss_location.location_event_pool_object_id = act_data.act_boss_event_pool_object_id
		
		# connect all locations directly below boss to it
		if len(floors):
			var previous_floor: Array[LocationData] = floors[-1]
			for previous_location in previous_floor:
				previous_location.location_next_location_ids.append(location_id)
		
		# add node to layer
		boss_floor.append(boss_location)
		floors.append(boss_floor)
