extends "res://scripts/mm_bd_store.gd"
const MandateModel=preload("res://scripts/mm_bd_mandate_model.gd")
func _init(save_path:String="")->void:
	model=MandateModel.new();rules_hash=FileAccess.get_file_as_string(MandateModel.MANDATE_DATA_PATH).sha256_text()
	path=save_path if not save_path.is_empty() else "user://mm_bd_mandates_v2_%s.json"%rules_hash.left(12)
