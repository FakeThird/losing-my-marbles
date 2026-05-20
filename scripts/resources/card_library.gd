class_name CardLibrary
extends RefCounted

const CARDS_DIR := "res://resources/cards/"
const CHARACTERS_DIR := "res://resources/characters/"

var cards: Array[CardData] = []
var characters: Array[CharacterData] = []


func load_cards() -> void:
	cards.clear()
	for res: Resource in _load_tres_files(CARDS_DIR):
		if res is CardData:
			cards.append(res)


func load_characters() -> void:
	characters.clear()
	for res: Resource in _load_tres_files(CHARACTERS_DIR):
		if res is CharacterData:
			characters.append(res)


func _load_tres_files(dir_path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	
	if dir == null:
		push_error("CardLibrary: Cannot open directory: ", dir_path)
		return result
		
	# Modern GDScript 2.0 avoids while loops in favor of get_files()
	for file_name: String in dir.get_files():
		# CRITICAL EXPORT FIX: Strip the .remap extension if it exists
		var clean_file_name: String = file_name.trim_suffix(".remap")
		
		# Allow both text (.tres) and binary (.res) resource files
		if clean_file_name.ends_with(".tres") or clean_file_name.ends_with(".res"):
			var resource_path: String = dir_path + clean_file_name
			var resource: Resource = load(resource_path)
			
			if resource:
				result.append(resource)
			else:
				push_error("CardLibrary: Failed to load resource at ", resource_path)
				
	return result
