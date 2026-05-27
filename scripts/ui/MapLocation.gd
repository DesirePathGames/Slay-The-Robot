extends TextureButton
class_name MapLocation

var location_data: LocationData = null
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var map_label: Label = $MapLabel

signal map_location_button_up(map_location: MapLocation)

func _ready():
	button_up.connect(_on_button_up)

func init(_location_data: LocationData):
	location_data = _location_data
	position = location_data.location_position
	
	# display the type of location
	if location_data.location_obfuscated and not location_data.location_visited:
		map_label.text = "???" # unvisited obfuscated locations are marked hidden
	else:
		map_label.text = LocationData.LOCATION_TYPES.keys()[location_data.location_type]

	if location_data.location_type == LocationData.LOCATION_TYPES.COMBAT:
		var tex = FileLoader.load_texture("external/mods/my_map_mod/sprites/star.png")
		if tex:
			texture_normal = tex
			ignore_texture_size = true
			stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			custom_minimum_size = Vector2(64, 64)
			size = Vector2(64, 64)

func flash_location() -> void:
	animation_player.play("flash_map_location")

func _on_button_up():
	location_data.location_visited = true
	map_location_button_up.emit(self)
