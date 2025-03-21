extends HBoxContainer

signal manage_tags_requested(item_tags, all_tags, on_confirm)

@onready var _sidebar: VBoxContainer = %ActionsSidebar
@onready var _projects_list: VBoxContainer = %ProjectsList
@onready var _import_project_dialog: ConfirmationDialog = %ImportProjectDialog
@onready var _new_project_dialog = %NewProjectDialog
@onready var _scan_dialog = %ScanDialog
@onready var _install_project_from_zip_dialog = %InstallProjectSimpleDialog
@onready var _duplicate_project_dialog = %DuplicateProjectDialog
@onready var _clone_project_dialog = %CloneProjectDialog


var _projects: Projects.List
var _load_projects_queue = []
var _remove_missing_action: Action.Self


func init(projects: Projects.List):
	self._projects = projects
	
	var remove_missing_popup = RemoveMissingDialog.new(_remove_missing)
	add_child(remove_missing_popup)
	
	var actions := Action.List.new([
		Action.from_dict({
			"key": "new-project",
			"icon": Action.IconTheme.new(self, "Add", "EditorIcons"),
			"act": _new_project_dialog.raise,
			"label": tr("New"),
		}),
		Action.from_dict({
			"label": tr("Import"),
			"key": "import-project",
			"icon": Action.IconTheme.new(self, "Load", "EditorIcons"),
			"act": func(): import()
		}),
		Action.from_dict({
			"label": tr("Clone"),
			"key": "clone-project",
			"icon": Action.IconTheme.new(self, "VcsBranches", "EditorIcons"),
			"act": func(): _clone_project_dialog.raise()
		}),
		Action.from_dict({
			"label": tr("Scan"),
			"key": "scan-projects",
			"icon": Action.IconTheme.new(self, "Search", "EditorIcons"),
			"act": func():
				_scan_dialog.current_dir = ProjectSettings.globalize_path(
					Config.DEFAULT_PROJECTS_PATH.ret()
				)
				_scan_dialog.popup_centered_ratio(0.5)
				pass\
		}),
		Action.from_dict({
			"label": tr("Remove Missing"),
			"key": "remove-missing",
			"icon": Action.IconTheme.new(self, "Clear", "EditorIcons"),
			"act": func(): remove_missing_popup.popup_centered()
		}),
		Action.from_dict({
			"label": tr("Refresh List"),
			"key": "refresh",
			"icon": Action.IconTheme.new(self, "Reload", "EditorIcons"),
			"act": _refresh
		})
	])
	
	_remove_missing_action = actions.by_key('remove-missing')

	var project_actions = TabActions.Menu.new(
		actions.sub_list([
			'new-project',
			'import-project',
			'clone-project',
			'scan-projects',
		]).all(), 
		TabActions.Settings.new(
			Cache.section_of(self), 
			[
				'new-project',
				'import-project',
				'clone-project',
				'scan-projects'
			]
		)
	)
	project_actions.add_controls_to_node($ProjectsList/HBoxContainer/TabActions)
	project_actions.icon = get_theme_icon("GuiTabMenuHl", "EditorIcons")
	#$ProjectsList/HBoxContainer/TabActions.add_child(project_actions)

	$ProjectsList/HBoxContainer.add_child(_remove_missing_action.to_btn().make_flat(true).show_text(false))
	$ProjectsList/HBoxContainer.add_child(actions.by_key('refresh').to_btn().make_flat(true).show_text(false))
	$ProjectsList/HBoxContainer.add_child(project_actions)

	_import_project_dialog.imported.connect(func(project_path, editor_path, edit, callback):
		var project: Projects.Item
		if projects.has(project_path):
			project = projects.retrieve(project_path)
			project.editor_path = editor_path
			project.emit_internals_changed()
		else:
			project = _projects.add(project_path, editor_path)
			project.load()
			_projects_list.add(project)
		_projects.save()
		
		if edit:
			project.edit()
			AutoClose.close_if_should()
		
		if callback:
			callback.call(project, projects)
		
		_projects_list.sort_items()
	)
	
	_clone_project_dialog.cloned.connect(func(path: String):
		assert(path.get_file() == "project.godot")
		import(path)
	)
	
	_new_project_dialog.created.connect(func(project_path):
		import(project_path)
	)
	
	_scan_dialog.dir_to_scan_selected.connect(func(dir_to_scan: String):
		_scan_projects(dir_to_scan)
	)
	
	_duplicate_project_dialog.duplicated.connect(func(project_path, callback):
		import(project_path, callback)
	)
	
	_projects_list.refresh(_projects.all())
	_load_projects()


func _load_projects():
	_load_projects_array(_projects.all())


func _load_projects_array(array):
	for project in array:
		project.load()
		await get_tree().process_frame
	_projects_list.sort_items()
	_projects_list.update_filters()
	_update_remove_missing_disabled()


func _refresh():
	_projects.load()
	_projects_list.refresh(_projects.all())
	_load_projects()


func import(project_path="", callback=null):
	if _import_project_dialog.visible:
		return
	_import_project_dialog.init(project_path, _projects.get_editors_to_bind(), callback)
	_import_project_dialog.popup_centered()


func install_zip(zip_reader: ZIPReader, project_name):
	if _install_project_from_zip_dialog.visible:
		zip_reader.close()
		return
	_install_project_from_zip_dialog.title = "Install Project: %s" % project_name
	_install_project_from_zip_dialog.get_ok_button().text = tr("Install")
	_install_project_from_zip_dialog.raise(project_name)
	_install_project_from_zip_dialog.dialog_hide_on_ok = false
	_install_project_from_zip_dialog.about_to_install.connect(func(final_project_name, project_dir):
		var unzip_err = zip.unzip_to_path(zip_reader, project_dir)
		zip_reader.close()
		if unzip_err != OK:
			_install_project_from_zip_dialog.error(tr("Failed to unzip."))
			return
		var project_configs = utils.find_project_godot_files(project_dir)
		if len(project_configs) == 0:
			_install_project_from_zip_dialog.error(tr("No project.godot found."))
			return
		
		var project_file_path = project_configs[0]
		_install_project_from_zip_dialog.hide()
		import(project_file_path.path)
		pass,
		CONNECT_ONE_SHOT
	)


func _scan_projects(dir_path):
	var project_configs = utils.find_project_godot_files(dir_path)
	var added_projects = []
	for project_config in project_configs:
		var project_path = project_config.path
		if _projects.has(project_path):
			continue
		var project = _projects.add(project_path, null)
		_projects_list.add(project)
		added_projects.append(project)
	_projects.save()
	_load_projects_array(added_projects)


func _remove_missing():
	for p in _projects.all().filter(func(x): return x.is_missing):
		_projects.erase(p.path)
	_projects.save()
	_projects_list.refresh(_projects.all())
	_projects_list.sort_items()
	_sidebar.refresh_actions([])
	_update_remove_missing_disabled()


func _update_remove_missing_disabled():
	_remove_missing_action.disable(len(
		_projects.all().filter(func(x): return x.is_missing)
	) == 0)


func _on_projects_list_item_selected(item) -> void:
	_sidebar.refresh_actions(item.get_actions())


func _on_projects_list_item_removed(item_data) -> void:
	if _projects.has(item_data.path):
		_projects.erase(item_data.path)
		_projects.save()
	_sidebar.refresh_actions([])
	_update_remove_missing_disabled()


func _on_projects_list_item_edited(item_data) -> void:
	item_data.emit_internals_changed()
	_projects.save()
	_projects_list.sort_items()


func _on_projects_list_item_manage_tags_requested(item_data) -> void:
	var all_tags = Set.new()
	all_tags.append_array(_projects.get_all_tags())
	all_tags.append_array(Config.DEFAULT_PROJECT_TAGS.ret())
	manage_tags_requested.emit(
		item_data.tags,
		all_tags.values(),
		func(new_tags):
			item_data.tags = new_tags
			_on_projects_list_item_edited(item_data)
	)


func _on_projects_list_item_duplicate_requested(project: Projects.Item) -> void:
	if _duplicate_project_dialog.visible:
		return
	
	_duplicate_project_dialog.raise(project.name, project)
