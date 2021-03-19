extends Node

var level_dirs = [
	"res://resources/levels/"
]


func getLevels() -> Array:
	var levels = []
	for i in level_dirs:
		levels += Utility.scanDir(i, 'd')
	print("ReadLevels::Found %d levels" % [levels.size()])
	return levels


func getLevelModes(level_name : String) -> Dictionary:
	for i in level_dirs:
		if Utility.dirExists(i + level_name):
			var level_info = Utility.loadDictionary(i + level_name + "/level_info.json")
			return level_info.modes.keys()
	return {}


func getMinimap(level_name : String) -> Texture:
	for i in level_dirs:
		if Utility.dirExists(i + level_name):
			var texture : Texture = load(i + level_name + "/" + level_name + ".png")
			return texture
	return null

