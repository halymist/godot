extends Control

const NEXT_SCENE := "res://Scenes/login.tscn"

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var icon: TextureRect = $Icon

var loading_started := false

func _ready():
	ResourceLoader.load_threaded_request(NEXT_SCENE)
	loading_started = true

func _process(_delta: float):
	if not loading_started:
		return

	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(NEXT_SCENE, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			var scene = ResourceLoader.load_threaded_get(NEXT_SCENE)
			get_tree().change_scene_to_packed(scene)
		ResourceLoader.THREAD_LOAD_FAILED:
			pass
