# Copyright © 2025 RustyPrime
# Asset Dock for SoundLibraryViewer
@tool
class_name SoundLibraryDock
extends PanelContainer

signal deletion_confirmation_closed
signal deletion_confirmation_confirmed

const SOUND_PREVIEW_SCENE: String = "uid://xm0j717pa5t8" #"res://addons/SoundLibraryBrowser/scenes/SoundLibraryPreviewItem.tscn"

## Public Variables
var soundPlayer : AudioStreamPlayer
var deleteConfirmationDialog: ConfirmationDialog

## Private Variables
var _volumeSlider : HSlider
var _resyncButton : Button
var _settingsButton : Button
var _searchButton : Button
var _previewsContainer : Control
var _soundPreviewScene: PackedScene
var _previewsScrollContainer : ScrollContainer
var _settingsScrollContainer : ScrollContainer
var _messageContainer : BoxContainer
var _messageLabel: Label
var _totalSoundsLabel: Label
var _useLibraryStructureCheckBox: CheckBox
var _searchBar : LineEdit
var _libraryPathLineEdit: LineEdit
var _saveToPathLineEdit: LineEdit
var _pageination: SoundLibraryPagination
var _plugin: EditorPlugin

var _soundDictionary : Dictionary[String, int] = {}
var _filteredSoundDictionary : Dictionary[String, int] = {}
var _soundPreviews : Array[SoundLibraryPreviewItem] = []
var _totalSoundFiles : int = 0
var _initialized: bool = false


func Initialize(plugin: EditorPlugin) -> void:
	if plugin:
		_plugin = plugin
	
	_soundPreviewScene = load(SOUND_PREVIEW_SCENE)

	soundPlayer = %SoundPlayer
	_volumeSlider = %VolumeSlider
	_resyncButton = %ResyncButton
	_settingsButton = %SettingsButton
	_previewsContainer = %PreviewsContainer

	_totalSoundsLabel = %TotalSoundsLabel

	_previewsScrollContainer = %PreviewsScrollContainer
	_settingsScrollContainer = %SettingsScrollContainer

	_useLibraryStructureCheckBox = %KeepDirectoryStructure
	_libraryPathLineEdit = %LibraryPath
	_saveToPathLineEdit = %ProjectPath

	deleteConfirmationDialog = %ConfirmationDialog

	_pageination = %Pageination
	
	_messageContainer = %MessageContainer
	_messageLabel = %MessageLabel

	_searchBar = %SearchBar
	_searchButton = %SearchButton

	SetSoundPlayerVolume(_volumeSlider.value)

	SetupSignals()

	if _plugin.HasSetupCompleted():
		HideSettingsMenu()

		_libraryPathLineEdit.text = _plugin.libraryPath
		_saveToPathLineEdit.text = _plugin.saveToPath
		_useLibraryStructureCheckBox.button_pressed = _plugin.useSameDirectoryStructureAsLibrary
		_volumeSlider.value = _plugin.volumeSlider
		
		SetSoundPlayerVolume(_volumeSlider.value)
		
		ShowMessage("Loading sounds from library...")
		# Load the lib from cache or recursively search the library path for sound files
		WorkerThreadPool.add_task(LoadLibrary, true)

		
	else:
		_previewsScrollContainer.visible = false
		_settingsScrollContainer.visible = true
		_settingsButton.text = "Save Settings"

	
	_initialized = true
	UpdateDock()


func _ready() -> void:
	if not _initialized:
		return
	
	set("theme_override_styles/panel", get_theme_stylebox("panel", "Panel"))


func _exit_tree() -> void:
	for soundPreview in _soundPreviews:
		var previewTaskId := soundPreview.taskId
		if previewTaskId == -1:
			continue

		if not WorkerThreadPool.is_task_completed(previewTaskId):
			WorkerThreadPool.wait_for_task_completion(previewTaskId)

## Dock Methods
func RemoveDock() -> void:
	_plugin.remove_control_from_bottom_panel(self)


func UpdateDock() -> void:
	if not _initialized:
		return
		
	RemoveDock()
	var title := "SoundLibrary"
	_plugin.add_control_to_bottom_panel(self,  title)
	_plugin.make_bottom_panel_item_visible(self)


func ShowMessage(message: String) -> void:
	ShowContainer(_messageContainer)
	_messageLabel.text = message


func ShowSettingsMenu() -> void:
	ShowContainer(_settingsScrollContainer)
	_settingsButton.text = "Save Settings"
	_pageination.visible = false


func HideSettingsMenu() -> void:
	ShowContainer(_previewsScrollContainer)
	_settingsButton.text = "Settings"


func ShowContainer(container : Container) -> void:
	_pageination.visible = container == _previewsScrollContainer
	_previewsScrollContainer.visible = _previewsScrollContainer == container
	_previewsScrollContainer.scroll_vertical = 0
	_settingsScrollContainer.visible = _settingsScrollContainer == container
	_messageContainer.visible = _messageContainer == container


func SaveSettings() -> void:
	if _plugin:
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), _useLibraryStructureCheckBox.button_pressed)
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_LIBRARY_PATH), _plugin.libraryPath)
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_SAVE_TO_PATH), _plugin.saveToPath)
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_VOLUME_SLIDER), _volumeSlider.value)


func SetupSignals() -> void:
	_volumeSlider.value_changed.connect(_on_volume_slider_value_changed)
	_searchButton.pressed.connect(_on_search_button_pressed)
	_settingsButton.pressed.connect(_on_settings_button_pressed)
	_searchBar.text_changed.connect(_on_search_text_changed)
	_searchBar.text_submitted.connect(_on_search_text_submitted)
	_useLibraryStructureCheckBox.toggled.connect(_on_use_library_structure_toggled)
	_libraryPathLineEdit.text_changed.connect(_on_library_path_changed)
	_saveToPathLineEdit.text_changed.connect(_on_save_to_path_changed)
	deleteConfirmationDialog.canceled.connect(_on_confirmation_closed)
	deleteConfirmationDialog.confirmed.connect(_on_confirmation_confirmed)
	deleteConfirmationDialog.close_requested.connect(_on_confirmation_closed)
	_pageination.page_changed.connect(_on_page_changed)
	_resyncButton.pressed.connect(_on_resnyc_button_pressed)


func LoadLibrary(forceResync : bool = false) -> void:
	_pageination.DisablePaginationNavigation.call_deferred()
	_settingsButton.set_deferred("disabled", true)
	_resyncButton.set_deferred("disabled", true)
	_searchButton.set_deferred("disabled", true)

	if forceResync:
		if _plugin.libraryCache:
			_plugin.libraryCache.soundLibrary.clear()
			ResourceSaver.save(_plugin.libraryCache)

	var files: Array[String] = []
	if not forceResync and _plugin.libraryCache and _plugin.libraryCache.soundLibrary.size() > 0:
		ShowMessage.call_deferred("Loading sounds from cache...")
		files = _plugin.libraryCache.soundLibrary.duplicate()
	if files.size() == 0 or forceResync:
		ShowMessage.call_deferred("No sounds found in cache. Searching library path...")
		set_deferred("_totalSoundFiles", 0)
		files = RecursiveDirectorySearch(_plugin.libraryPath)
	
	var pageNumber := 1
	var itemsOnPage := 0
	_soundDictionary.clear()
	for soundFilePath in files:
		if not IsValidFileType(soundFilePath):
			continue
		
		var fileIndex := files.find(soundFilePath)
		if fileIndex == -1:
			continue
		
		_soundDictionary[soundFilePath] = pageNumber

		itemsOnPage += 1
		if itemsOnPage >= _pageination.GetItemsPerPage():
			pageNumber += 1
			itemsOnPage = 0

	if _plugin.libraryCache:
		_plugin.libraryCache.soundLibrary = files.duplicate()
		ResourceSaver.save(_plugin.libraryCache)
	
	_totalSoundsLabel.set_deferred("text", "Total: " + str(files.size()))

	if _soundPreviews.size() == 0:
		ShowMessage.call_deferred("Found " + str(files.size()) + " sound files in library. Setting up preview containers...")
		# Instantiate the previews based on the number of items per page
		var taskId := WorkerThreadPool.add_task(LoadPreviews)
		WorkerThreadPool.wait_for_task_completion(taskId)
	
	_pageination.SetTotalPages.call_deferred(_soundDictionary.size())
	_pageination.SetCurrentPage.call_deferred(1)

	ShowContainer.call_deferred(_previewsScrollContainer)
	_pageination.EnablePaginationNavigation.call_deferred()
	
	_settingsButton.set_deferred("disabled", false)
	_resyncButton.set_deferred("disabled", false)
	_searchButton.set_deferred("disabled", false)


func LoadPreviews() -> void:
	for i in _pageination.GetItemsPerPage():
		var soundPreview := _soundPreviewScene.instantiate()
		_soundPreviews.append.call_deferred(soundPreview)
		_previewsContainer.add_child.call_deferred(soundPreview)


func SetSoundPlayerVolume(volume: float) -> void:
	if soundPlayer:
		soundPlayer.volume_linear = 0.2 * volume / 100.0


func RecursiveDirectorySearch(directory: String) -> Array[String]:
	var files: Array[String] = []
	var dirAccess := DirAccess.open(directory)
	if not dirAccess:
		return files
	
	dirAccess.list_dir_begin()
	var fileName := dirAccess.get_next()
	while fileName:
		if dirAccess.current_is_dir():
			files += RecursiveDirectorySearch(directory.path_join(fileName))
		elif IsValidFileType(fileName):
			_totalSoundFiles += 1
			ShowMessage.call_deferred("Loading sounds from library... (" + str(_totalSoundFiles) + " sounds found)")
			_totalSoundsLabel.set_deferred("text", "Total: " + str(_totalSoundFiles))
			files.append(directory.path_join(fileName))
		fileName = dirAccess.get_next()
	
	dirAccess.list_dir_end()
	return files


func IsValidFileType(filePath: String) -> bool:
	var validExtensions : Array[String] = ["wav", "ogg", "mp3"]
	var fileExtension := filePath.get_extension().to_lower()
	return fileExtension in validExtensions


func SearchLibrary() -> void:
	var searchQuery : = _searchBar.text.to_lower().split(" ")

	var pageNumber := 1
	var itemsOnPage := 0

	for soundFilePath : String in _soundDictionary.keys():
		var soundNameAndDirectory := soundFilePath.replace(_plugin.libraryPath, "")
		var loweredSoundName := soundNameAndDirectory.to_lower()
		
		var foundMatches := 0
		for query in searchQuery:
			if loweredSoundName.find(query) != -1:
				foundMatches += 1
		
		if foundMatches == searchQuery.size():
			
			_filteredSoundDictionary[soundFilePath] = pageNumber
			itemsOnPage += 1
			if itemsOnPage >= _pageination.GetItemsPerPage():
				pageNumber += 1
				itemsOnPage = 0

	_totalSoundsLabel.set_deferred("text", str("Total: " , _filteredSoundDictionary.size(), " / ", _soundDictionary.size()))
	_pageination.SetTotalPages.call_deferred(_filteredSoundDictionary.size())
	_pageination.SetCurrentPage.call_deferred(1)

	if _filteredSoundDictionary.size() == 0:
		ShowMessage.call_deferred("No results...")
	else:
		ShowContainer.call_deferred(_previewsScrollContainer)


## Signals
func _on_volume_slider_value_changed(value: float) -> void:
	if soundPlayer:
		SetSoundPlayerVolume(value)
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_VOLUME_SLIDER), value)


func _on_search_button_pressed() -> void:
	# Clear previous search results
	_filteredSoundDictionary.clear()

	if _searchBar.text == "":
		_pageination.SetTotalPages(_soundDictionary.size())
		_pageination.SetCurrentPage(1)
		ShowContainer(_previewsScrollContainer)
		_totalSoundsLabel.set_deferred("text", "Total: " + str(_soundDictionary.size()))
		return

	else:
		ShowMessage("Searching Library...")
		WorkerThreadPool.add_task(SearchLibrary, true)


func _on_search_text_changed(newText : String) -> void:
	if newText == "":
		_on_search_button_pressed()


func _on_search_text_submitted(newText : String) -> void:
	if _searchButton.disabled:
		return
	_on_search_button_pressed()


func _on_use_library_structure_toggled(checked: bool) -> void:
	_plugin.useSameDirectoryStructureAsLibrary = checked
	if _plugin:
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), checked)


func _on_library_path_changed(newText: String) -> void:
	_plugin.libraryPath = newText.strip_edges()
	if _plugin:
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_LIBRARY_PATH), _plugin.libraryPath)


func _on_save_to_path_changed(newText: String) -> void:
	_plugin.saveToPath = newText.strip_edges()
	if _plugin:
		_plugin.SetSetting(_plugin.SETTINGS_PATH.path_join(_plugin.SETTINGS_SAVE_TO_PATH), _plugin.saveToPath)


func _on_settings_button_pressed() -> void:
	if not _plugin.HasSetupCompleted():
		ShowSettingsMenu()
	else:
		if _previewsScrollContainer.visible:
			ShowSettingsMenu()
		else:
			SaveSettings()
			HideSettingsMenu()


func _on_confirmation_closed() -> void:
	deletion_confirmation_closed.emit()


func _on_confirmation_confirmed() -> void:
	deletion_confirmation_confirmed.emit()


func _on_page_changed(newPage: int) -> void:
	if newPage < 1:
		newPage = 1

	# Decide wether to display all sounds or the filtered ones	
	var selectedDictionary := _soundDictionary
	if _filteredSoundDictionary.size() > 0 and _searchBar.text != "":
		selectedDictionary = _filteredSoundDictionary

	# Get soundfilepaths for the current page and update the previews
	var soundPreviewIndex := 0
	for soundFilePath in selectedDictionary.keys():
		var pageNumber := selectedDictionary[soundFilePath]
		if pageNumber == newPage:
			var soundPreview := _soundPreviews[soundPreviewIndex]
			var subDirectory : String = soundFilePath.replace(_plugin.libraryPath, "").replace(soundFilePath.get_file(), "")
			soundPreview.visible = true
			soundPreview.Reset()
			soundPreview.Initialize(_plugin, self, soundFilePath, subDirectory)
			soundPreview.UpdateSoundNameLabel(_searchBar.text.to_lower().split(" "))
			soundPreviewIndex += 1

	# When there is not enough items on a page, hide the unused previews
	if soundPreviewIndex < _soundPreviews.size():
		for i in range(soundPreviewIndex, _soundPreviews.size()):
			_soundPreviews[i].visible = false


func _on_resnyc_button_pressed() -> void:
	# Force load the library from the library path, ignoring the cache
	WorkerThreadPool.add_task(LoadLibrary.bind(true), true)

