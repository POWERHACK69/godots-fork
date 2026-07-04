extends VBoxList


func _post_add(_item_data: Object, _raw_item_control: Control) -> void:
	pass


func _item_comparator(a: Dictionary, b: Dictionary) -> bool:
	return true


func _fill_sort_options(_btn: OptionButton) -> void:
	pass
