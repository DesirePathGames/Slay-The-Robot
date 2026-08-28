## Summons random enemies in given ememy slots
## NOTE: This only works if the current EventData's event_enemy_placement_is_automatic flag
## is false and positions are defined.
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action()
	
	for action_interceptor_processor in action_interceptor_processors:
		# number of spawns
		var number_of_spawns: int = action_interceptor_processor.get_shadowed_action_values("number_of_spawns", 1)
		# spawn slots that may be filled
		var spawn_slots: Array[int] = []
		spawn_slots.assign(action_interceptor_processor.get_shadowed_action_values("spawn_slots", []))
		# a list of enemy ids that could spawn
		var random_enemy_object_ids: Array = action_interceptor_processor.get_shadowed_action_values("random_enemy_object_ids", []).duplicate()
		if len(random_enemy_object_ids) == 0:
			DebugLogger.log_error("ActionSummonEnemies: No enemy type ids specified")
			return

		# get all enemies and map them to their slot
		var enemies: Array[Enemy] = []
		enemies.assign(Global.get_tree().get_nodes_in_group("enemies_alive_or_dead"))
		var populated_enemy_slots: Dictionary = {}
		for enemy in enemies:
			if populated_enemy_slots.has(enemy.enemy_slot):
				DebugLogger.log_error("ActionSummonEnemies: Multiple enemies in slot {0}".format([enemy.enemy_slot]))
			else:
				populated_enemy_slots[enemy.enemy_slot] = enemy

		# spawn enemies
		var player_location_data: LocationData = Global.get_player_location_data()
		var remaining_spawns: int = number_of_spawns
		
		for slot_id in spawn_slots:
			if remaining_spawns <= 0:
				break
			if populated_enemy_slots.has(slot_id):
				var enemy: Enemy = populated_enemy_slots[slot_id]
				if enemy.is_alive():
					continue # slot already filled, skip
				else:
					enemy.queue_free()	# replace existing dead enemy
			
			# randomize enemy type
			var rng_name: String = get_action_value("rng_name", "rng_enemy_spawning")
			var rng_enemy_spawning: RandomNumberGenerator = Global.player_data.get_player_rng(rng_name)
			
			random_enemy_object_ids = Random.shuffle_array(rng_enemy_spawning, random_enemy_object_ids)
			
			var enemy_object_id: String = random_enemy_object_ids[0]
			# spawn enemy
			Signals.enemy_spawn_requested.emit(enemy_object_id, slot_id)
			remaining_spawns -= 1
		
func _to_string():
	return "Summon Enemy Action"
