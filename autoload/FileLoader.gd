## Helper singleton for externalizing non critical file loads such as images and json.
## This allows for easy end user modability support when building the game rather than packing all
## human configurable or static assets into the standalone executable as is Godot's standard.
## Use load_xxx() for external files, and Godot's standard load() for internal ones

## CRITICAL: When exporting the game, copy the project's "external" folder(s) from your source directory
## into the exported .exe's directory
## and add "exported" to the export tags

## This singleton can also be used for other file related routines such as saving and loading the game
extends Node

###### Directories and cached assets
## The file path where anything externally loaded is found. This will automatically change depending on whether
## you are running from editor (directory of project) or have built the game (full path of exe).
var _EXTERNAL_FILE_PREFIX: String = "res://"

const EXTERNAL_DIR_PATH: String = "external/"
const EXTERNAL_DIR_DATA_PATH: String = EXTERNAL_DIR_PATH + "data/"
const MOD_LIST_FILE_NAME: String = "mod_list.json" # name of file containing info on how to load all mods
const MOD_INFO_FILE_NAME: String = "mod_info.json" # name of file for info on loading a single mod

const SAVE_DIR_PATH: String = EXTERNAL_DIR_PATH + "saves/" # file path of the save directory
const SAVE_FILE_NAME: String = "save.json" # filename of the current run's save

var USER_SETTINGS_DIR_PATH: String = EXTERNAL_DIR_PATH # you may wish to change this to OS.get_user_data_dir()
const USER_SETTINGS_FILE_NAME: String = "user_settings.json"

var PROFILE_DIR_PATH: String = EXTERNAL_DIR_PATH # you may wish to change this to OS.get_user_data_dir()
const PROFILE_FILE_NAME: String = "profile.json"

const AUTOSAVING_ENABLED: bool = true # disabling this makes testing easier

var _cached_textures: Dictionary	= {}	# maps a partial image path to a loaded image
var _cached_animations: Dictionary = {}	# maps unique animation ids to a spriteframe object

## Any time a read only data file is loaded for the first time, its directory and file name is stored here.
## Useful for migrating data via _migrate_read_only_data() and re-saving it
## or debugging a problematic config/mod.
var _read_only_object_to_source_file_path: Dictionary[SerializableData, Array] = {
	# SerializableData: ["partial_path", "filename"]
}

const VALID_IMAGE_EXTENSIONS: Array[String] = [
	".png", ".jpg", ".jpeg", ".svg"
]

func _ready():
	# change the base folder path based on the build type
	DebugLogger.log_line("FileLoader: To enable external file loading in builds, download an export template and add the custom feature tag \"exported\" to the export. See https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html",Color.YELLOW, DebugLogger.Severities.WARNING)
	if !OS.has_feature("exported"):
		# debug build uses project directory
		_EXTERNAL_FILE_PREFIX = "res://"
		DebugLogger.log_line("Debug Base Directory: " + _EXTERNAL_FILE_PREFIX, Color.LIGHT_BLUE)
	else:
		# release build uses exe folder for user ease of access
		_EXTERNAL_FILE_PREFIX = OS.get_executable_path().get_base_dir() + "/"
		DebugLogger.log_line("Build Base Directory: " + _EXTERNAL_FILE_PREFIX, Color.LIGHT_BLUE)
		
	if not AUTOSAVING_ENABLED:
		DebugLogger.log_line("FileLoader: Autosaving disabled", Color.RED)

func _get_modified_filepath(partial_filepath: String) -> String:
	# given a partial filepath, return the full one, which will change based on the build
	return _EXTERNAL_FILE_PREFIX + partial_filepath

func get_files_in_directory(partial_dir_path: String):
	var full_path: String = _get_modified_filepath(partial_dir_path)
	DirAccess.make_dir_absolute(full_path)
	var dir = DirAccess.open(full_path)
	return dir.get_files()

func load_texture(image_partial_path, is_absolute: bool = false) -> ImageTexture:
	# loads and caches a texture from external images
	var full_path: String = image_partial_path
	if not is_absolute:
		full_path = _get_modified_filepath(image_partial_path)
	
	if self._cached_textures.has(full_path):
		return self._cached_textures[full_path]
	else:
		if FileAccess.file_exists(full_path):
			var image := Image.load_from_file(full_path)
			var texture: ImageTexture
			if image == null:
				texture = ImageTexture.new()
			else:
				texture = ImageTexture.create_from_image(image)
			texture.take_over_path(full_path)
			self._cached_textures[full_path] = texture
			return texture
		else:
			push_error("Image failed to load: ", full_path)
			return ImageTexture.new()	# return an empty image
		
func load_animation(animation_id: String, animation_data: Dictionary) -> SpriteFrames:
	# given an animation id and animation data, will generate and cache a SpriteFrames from external images
	# animation_data is a dictionary of String animation names each mapped to an array of partial image paths
	# eg {"anim_1": ["frame_1", ...], "anim_2": [...]}
	if self._cached_animations.has(animation_id):
		return self._cached_animations[animation_id]
	else:
		var animation: SpriteFrames = SpriteFrames.new()
		for anim_name in animation_data.keys():
			animation.add_animation(anim_name)
			
			var partial_image_paths: Array = animation_data[anim_name]
			for partial_image_path in partial_image_paths:
				var texture: ImageTexture = self.load_texture(partial_image_path)
				animation.add_frame(anim_name, texture)
		
		self._cached_animations[animation_id] = animation
		return animation

func load_json(directory_partial_path: String, filename: String) -> Dictionary:
	# loads an external json file
	var full_path: String = _get_modified_filepath(directory_partial_path + filename)
	if FileAccess.file_exists(full_path):
		var file = FileAccess.open(full_path, FileAccess.READ)
		var file_text: String = file.get_as_text()
		var parsed_json = JSON.parse_string(file_text)
		
		if parsed_json == null:
			push_error("JSON failed to parse: ", full_path)
			return {}
		return parsed_json
	else:
		push_error("JSON failed to load: ", full_path)
		return {}

func save_json(directory_partial_path: String, filename: String, data_dict: Dictionary) -> void:
	# saves an external json file
	var directory_full_path: String = _get_modified_filepath(directory_partial_path)
	var full_path: String = directory_full_path + filename
	if not DirAccess.dir_exists_absolute(directory_full_path):
		DirAccess.make_dir_recursive_absolute(directory_full_path)
	
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	var json_text = JSON.stringify(data_dict, "\t")
	file.store_string(json_text)



#region Mod Pipeline

## Gets the mod list located in a specific file in the game's external directories.
## This is the first step in modloading.
## NOTE: Base game assets are counted as a "mod", so this takes place regardless of if actual
## mods exist.
func _load_mod_list_data() -> ModListData:
	var mod_list_dict_repr: Dictionary = load_json(EXTERNAL_DIR_PATH, MOD_LIST_FILE_NAME)
	var mod_list_data: ModListData = ModListData.new()
	mod_list_data.set_serializable_properties_from_json_patch(mod_list_dict_repr)
	return mod_list_data

## Main function for populating all data on game start from files. Iterates over mod list and generates
## all readonly data before populating them into their respective tables
func load_read_only_data() -> void:
	# get mod list data from config file
	var mod_list_data: ModListData = _load_mod_list_data()
	var sorted_mod_folders: Array[String] = mod_list_data.get_sorted_enabled_mod_folder_list()
	
	# iterate over all mod folders found in mod list
	for mod_base_directory: String in sorted_mod_folders:
		var mod_info: Dictionary = mod_list_data.mod_load_data[mod_base_directory]
		# load mod info from mod info file
		var mod_data: ModData = ModData.new()
		var mod_dict_repr: Dictionary = load_json(mod_base_directory, MOD_INFO_FILE_NAME)
		mod_data.set_serializable_properties_from_json_patch(mod_dict_repr)
		
		# take over script paths
		for mod_script_file_path: String in mod_data.mod_script_file_paths.keys():
			var full_script_path: String = _get_modified_filepath(mod_script_file_path)
			var old_script_path: String = mod_data.mod_script_file_paths[mod_script_file_path]
			
			var new_script: Script = load(full_script_path)
			if old_script_path != "":
				new_script.take_over_path(old_script_path)
		
		# iterate over every subdirectory listed in mod info's folders
		for mod_sub_directory: String in mod_data.mod_folder_to_load_data.keys():
			# get kind of data to load for each folder
			var sub_directory_data: Dictionary = mod_data.mod_folder_to_load_data[mod_sub_directory]
			
			# get type of data to create
			var data_class_name: String = sub_directory_data["class_name"]
			var class_type = Global.CLASS_NAME_TO_CLASS[data_class_name]
			
			# get data table in Global for this data
			var table_name: String = sub_directory_data["table_name"]
			var data_table: Dictionary = Global.get(table_name) 
			
			# load all files from json and populate them into game's stores
			var file_names: PackedStringArray = get_files_in_directory(mod_sub_directory)
			for file_name: String in file_names:
				var file_data: Dictionary = load_json(mod_sub_directory, file_name) # json payload
				# test the payload to see if it has an object id, in which case
				# check if there's an existing object in the table to overwrite with patch
				var object_id: String = SerializableData.get_object_id_from_json_patch(file_data)
				var exists_in_table: bool = false # if there's an existing object with same object_id in the data table
				var has_object_id: bool = object_id != "" # if currently loading object has an object_id
				
				if has_object_id:
					exists_in_table = data_table.has(object_id)
				
				var read_only_data: SerializableData = null
				if exists_in_table:
					# take the existing object to patch over
					read_only_data = data_table[object_id]
				else:
					# not in table, use a new object of the given type and patch that
					read_only_data = class_type.new()
				
				# patch the object
				read_only_data.set_serializable_properties_from_json_patch(file_data)
				# (re)store in corresponding dictionary
				data_table[read_only_data.object_id] = read_only_data
				
				# map the created data to where it was originally loaded from
				if not exists_in_table:
					_read_only_object_to_source_file_path[read_only_data] = [mod_sub_directory,file_name]

## Utility function. Used to modify and overwrite read only files that have been stored,
## using temporary code for migration logic.
func _migrate_read_only_data() -> void:
	####### Write Temporary Migration Code Here To Mutate Test Data
	
	######
	
	# resave the data after migrations have been made
	for serializeable_data: SerializableData in _read_only_object_to_source_file_path.keys():
		var file_data: Array = _read_only_object_to_source_file_path[serializeable_data]
		var directory: String = file_data[0]
		var file_name: String = file_data[1]
		
		var dict_repr: Dictionary = serializeable_data.get_serializable_properties_to_json_patch()
		save_json(directory, file_name, dict_repr)

## Utility function. Used to export test data that doesn't have an existing source file to external directories,
## essentially exposing the base game's data pipeline for modification
## Only outputs files that were not loaded from anywhere, preserving existing external files.
func export_test_data() -> void:
	####### Write Temporary Migration Code Here To Mutate Test Data
	
	######
	
	# get mappings of data types to mappings
	var base_game_mod_data: ModData = _generate_base_mod_data(false)
	
	# Set-like dict used to prevent the same object getting exported multiple times
	# if multiple source folders are used for the same data type. Will output the files to the first
	# available source folder of that type.
	var data_object_was_exported: Dictionary[SerializableData, Variant] = {}
	
	for folder_path: String in base_game_mod_data.mod_folder_to_load_data.keys():
		var folder_data: Dictionary = base_game_mod_data.mod_folder_to_load_data[folder_path]
		var data_class_name: String = folder_data["class_name"]
		var table_name: String = folder_data["table_name"]
		
		# get global data table
		var data_dict: Dictionary = Global.get(table_name)
		
		# iterate over all objects in data table
		for object_id: String in data_dict.keys():
			var serializeable_data: SerializableData = data_dict[object_id]
			
			# only write to non existing files
			if not _read_only_object_to_source_file_path.has(serializeable_data):
				# avoid duplicate exports
				if not data_object_was_exported.has(serializeable_data):
					var file_name: String = object_id + ".json"
		
					var dict_repr: Dictionary = serializeable_data.get_serializable_properties_to_json_patch()
					save_json(folder_path, file_name, dict_repr)
					data_object_was_exported[serializeable_data] = true

## Returns a list of all error messages generated by a given sorted list of mods.
## An empty array indicates no errors.
func validate_enabled_mod_dependencies(mod_list: Array[String]) -> Array[String]:
	# TODO
	var error_messages: Array[String] = []
	return error_messages

## Helper method. Generates and saves "mod_list.json" manifest data for the base game.
## You generally only need to call this once.
func _generate_mod_list_data(save_to_file: bool = true) -> ModListData:
	var mod_list_data: ModListData = ModListData.new("mod_list")
	mod_list_data.mod_load_data = {
		EXTERNAL_DIR_DATA_PATH: {
			"enabled": true,
			"load_priority": 0
		}	
	}
	
	if save_to_file:
		save_json(EXTERNAL_DIR_PATH, MOD_LIST_FILE_NAME, mod_list_data.get_serializable_properties_to_json_patch())
	return mod_list_data

## Helper method. Generates and saves "mod_info.json" data for the base game to
## load it through the same data pipeline as mods
## You generally only need to call this to update your file schema
## save_to_file exports it which you'll typically want to do.
func _generate_base_mod_data(save_to_file: bool = true) -> ModData:
	var mod_data: ModData = ModData.new("mod_data_base_game")
	
	var mod_folder_to_load_data: Dictionary = {}
	for schema_row: Array in Global.SCHEMA:
		var data_script_string: String = schema_row[0]
		var data_script: Script = schema_row[1]
		var data_lookup_table_property_name: String = schema_row[2]
		var read_only_data_folder_paths: Array[String] = []
		read_only_data_folder_paths.assign(schema_row[3])
		
		for read_only_data_folder_path: String in read_only_data_folder_paths:
			var folder_path: String = EXTERNAL_DIR_DATA_PATH + read_only_data_folder_path
			mod_folder_to_load_data[folder_path] = {
				"class_name": data_script_string,
				"table_name": data_lookup_table_property_name,
			}
	
	mod_data.mod_folder_to_load_data = mod_folder_to_load_data
	
	if save_to_file:
		save_json(EXTERNAL_DIR_DATA_PATH, MOD_INFO_FILE_NAME, mod_data.get_serializable_properties_to_json_patch())
	
	return mod_data

#endregion

## Tests the serialization methods of SerializableData across player's current run.
## For best results, run it when the game data is completely populated, such as during or after start_run()
func test_serialization() -> void:
	# create a temp player object for testing
	var player_data_2: PlayerData = PlayerData.new()
	
	# get dict repr of current player data
	var dict_repr_1: Dictionary = Global.player_data.get_serializable_properties(true)
	var dict_string_1: String = JSON.stringify(dict_repr_1)
	
	# override empty player data with real player data
	player_data_2.set_serializable_properties(dict_repr_1)
	var dict_repr_2: Dictionary = player_data_2.get_serializable_properties(true)
	var dict_string_2: String = JSON.stringify(dict_repr_2)
	
	var len1: int = len(dict_string_1)
	var len2: int = len(dict_string_2)
	
	# write to test files to check diffs in external tools
	#FileLoader.save_json("", "test_json_1.json", dict_repr_1)
	#FileLoader.save_json("", "test_json_2.json", dict_repr_2)
	
	assert(dict_string_1 == dict_string_2) # these should be the same at the end
	breakpoint # for checking in debug


## Gets all data on the player and converts it into a json safe format
func save_game(file_dir: String = SAVE_DIR_PATH, file_name: String = SAVE_FILE_NAME) -> void:
	var player_dict: Dictionary = Global.player_data.get_serializable_properties_to_json_patch()
	save_json(file_dir, file_name, player_dict)

## Takes json file and converts is back into player data
func load_game(file_dir: String = SAVE_DIR_PATH, file_name: String = SAVE_FILE_NAME) -> void:
	if not has_save_file():
		DebugLogger.log_error("No save file found")
	else:
		# load from json
		var player_data: PlayerData = PlayerData.new()
		var player_dict: Dictionary = load_json(file_dir, file_name)
		player_data.set_serializable_properties_from_json_patch(player_dict)
		
		# hook everything back up and regenerate caches
		Global.player_data = player_data
		Global.is_run = true
		player_data.init()
		
		# simulate the run starting and visiting the player's location
		Signals.run_started.emit()
		Signals.map_location_selected.emit(Global.get_player_location_data())

## Wrapper for saving the game. It automatically determines the file name
## TODO: Profile implementation
func autosave() -> void:
	if AUTOSAVING_ENABLED:
		save_game()

## Wrapper for loading the game automatically.
## TODO: Profile implementation
func autoload() -> void:
	load_game()

## Determines if a save file exists for the player
func has_save_file() -> bool:
	return get_files_in_directory(SAVE_DIR_PATH).has(SAVE_FILE_NAME)

func delete_save() -> void:
	if has_save_file():
		var save_dir_full_path: String = _get_modified_filepath(SAVE_DIR_PATH)
		var dir = DirAccess.open(save_dir_full_path)
		dir.remove(SAVE_FILE_NAME)

### Settings

func has_user_settings_file() -> bool:
	return get_files_in_directory(USER_SETTINGS_DIR_PATH).has(USER_SETTINGS_FILE_NAME)
	
func load_user_settings() -> void:
	if has_user_settings_file():
		var dict_repr: Dictionary = load_json(USER_SETTINGS_DIR_PATH, USER_SETTINGS_FILE_NAME)
		Global.user_settings_data.set_serializable_properties(dict_repr, true)
	else:
		save_user_settings()

func save_user_settings() -> void:
	var dict_repr: Dictionary = Global.user_settings_data.get_serializable_properties(true)
	save_json(USER_SETTINGS_DIR_PATH, USER_SETTINGS_FILE_NAME, dict_repr)

### Profile

func has_profile_file() -> bool:
	return get_files_in_directory(PROFILE_DIR_PATH).has(PROFILE_FILE_NAME)
	
func load_profile() -> void:
	if has_profile_file():
		var dict_repr: Dictionary = load_json(PROFILE_DIR_PATH, PROFILE_FILE_NAME)
		Global.profile_data.set_serializable_properties(dict_repr, true)
	else:
		save_profile()

func save_profile() -> void:
	var dict_repr: Dictionary = Global.profile_data.get_serializable_properties(true)
	save_json(PROFILE_DIR_PATH, PROFILE_FILE_NAME, dict_repr)
