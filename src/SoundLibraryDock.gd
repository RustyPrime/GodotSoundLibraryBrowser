# Copyright © 2025 RustyPrime
# Asset Dock for SoundLibraryViewer
@tool
extends PanelContainer
class_name SoundLibraryDock

signal deletion_confirmation_closed
signal deletion_confirmation_confirmed

const SOUND_PREVIEW_SCENE: String = "res://addons/SoundLibraryBrowser/scenes/SoundLibraryPreviewItem.tscn"

var soundPlayer : AudioStreamPlayer
var volumeSlider : HSlider
var resyncButton : Button
var settingsButton : Button
var searchBar : LineEdit
var searchButton : Button
var previewsContainer : Control
var soundPreviewScene: PackedScene
var previewsScrollContainer : ScrollContainer
var settingsScrollContainer : ScrollContainer
var messageContainer : BoxContainer
var messageLabel: Label
var useLibraryStructureCheckBox: CheckBox
var libraryPathLineEdit: LineEdit
var saveToPathLineEdit: LineEdit
var deleteConfirmationDialog: ConfirmationDialog
var pageination: SoundLibraryPagination
var totalSoundsLabel: Label

var _initialized: bool = false
var plugin: EditorPlugin

var soundDictionary : Dictionary[String, int] = {}
var filteredSoundDictionary : Dictionary[String, int] = {}

var soundPreviews : Array[SoundLibraryPreviewItem] = []

var totalSoundFiles : int = 0

func initialize(_plugin: EditorPlugin) -> void:
	if _plugin:
		plugin = _plugin
	
	soundPreviewScene = load(SOUND_PREVIEW_SCENE)

	soundPlayer = %SoundPlayer
	volumeSlider = %VolumeSlider
	resyncButton = %ResyncButton
	settingsButton = %SettingsButton
	previewsContainer = %PreviewsContainer

	totalSoundsLabel = %TotalSoundsLabel

	previewsScrollContainer = %PreviewsScrollContainer
	settingsScrollContainer = %SettingsScrollContainer

	useLibraryStructureCheckBox = %KeepDirectoryStructure
	libraryPathLineEdit = %LibraryPath
	saveToPathLineEdit = %ProjectPath

	deleteConfirmationDialog = %ConfirmationDialog

	pageination = %Pageination
	
	messageContainer = %MessageContainer
	messageLabel = %MessageLabel

	searchBar = %SearchBar
	searchButton = %SearchButton

	SetSoundPlayerVolume(volumeSlider.value)

	SetupSignals()

	if plugin.HasSetupCompleted():
		HideSettingsMenu()

		libraryPathLineEdit.text = plugin.libraryPath
		saveToPathLineEdit.text = plugin.saveToPath
		useLibraryStructureCheckBox.button_pressed = plugin.useSameDirectoryStructureAsLibrary
		volumeSlider.value = plugin.volumeSlider
		
		SetSoundPlayerVolume(volumeSlider.value)
		
		ShowMessage("Loading sounds from library...")
		# Load the lib from cache or recursively search the library path for sound files
		WorkerThreadPool.add_task(LoadLibrary, true)

		
	else:
		previewsScrollContainer.visible = false
		settingsScrollContainer.visible = true
		settingsButton.text = "Save Settings"

	
	_initialized = true
	UpdateDock()

func _ready() -> void:
	if not _initialized:
		return
	
	set("theme_override_styles/panel", get_theme_stylebox("panel", "Panel"))


## Dock placement
func RemoveDock() -> void:
	plugin.remove_control_from_bottom_panel(self)
	
func UpdateDock() -> void:
	if not _initialized:
		return
		
	RemoveDock()
	var title := "SoundLibrary"
	plugin.add_control_to_bottom_panel(self,  title)
	plugin.make_bottom_panel_item_visible(self)

## Signals
func _on_volume_slider_value_changed(value: float) -> void:
	if soundPlayer:
		SetSoundPlayerVolume(value)
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_VOLUME_SLIDER), value)

func _on_search_button_pressed() -> void:
	# Clear previous search results
	filteredSoundDictionary.clear()

	if searchBar.text == "":
		pageination.SetTotalPages(soundDictionary.size())
		pageination.SetCurrentPage(1)
		ShowContainer(previewsScrollContainer)
		totalSoundsLabel.set_deferred("text", "Total: " + str(soundDictionary.size()))
		return

	else:
		ShowMessage("Searching Library...")
		WorkerThreadPool.add_task(SearchLibrary, true)

func _on_search_text_changed(newText : String) -> void:
	if newText == "":
		_on_search_button_pressed()

func _on_search_text_submitted(newText : String) -> void:
	if searchButton.disabled:
		return
	_on_search_button_pressed()

func _on_use_library_structure_toggled(checked: bool) -> void:
	plugin.useSameDirectoryStructureAsLibrary = checked
	if plugin:
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), checked)

func _on_library_path_changed(newText: String) -> void:
	plugin.libraryPath = newText.strip_edges()
	if plugin:
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_LIBRARY_PATH), plugin.libraryPath)

func _on_save_to_path_changed(newText: String) -> void:
	plugin.saveToPath = newText.strip_edges()
	if plugin:
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_SAVE_TO_PATH), plugin.saveToPath)

func _on_settings_button_pressed() -> void:
	if !plugin.HasSetupCompleted():
		ShowSettingsMenu()
	else:
		if previewsScrollContainer.visible:
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
	# get soundfilepaths for the current page
	var selectedDictionary := soundDictionary
	if filteredSoundDictionary.size() > 0 && searchBar.text != "":
		selectedDictionary = filteredSoundDictionary
	var soundPreviewIndex := 0
	for soundFilePath in selectedDictionary.keys():
		var pageNumber := selectedDictionary[soundFilePath]
		if pageNumber == newPage:
			var soundPreview := soundPreviews[soundPreviewIndex]
			var subDirectory : String = soundFilePath.replace(plugin.libraryPath, "").replace(soundFilePath.get_file(), "")
			soundPreview.visible = true
			soundPreview.reset()
			soundPreview.initialize(plugin, self, soundFilePath, subDirectory)
			soundPreview.UpdateSoundNameLabel(searchBar.text.to_lower().split(" "))
			soundPreviewIndex += 1

	if soundPreviewIndex < soundPreviews.size():
		for i in range(soundPreviewIndex, soundPreviews.size()):
			soundPreviews[i].visible = false

func _on_resnyc_button_pressed() -> void:
	# Force load the library from the library path, ignoring the cache
	WorkerThreadPool.add_task(LoadLibrary.bind(true), true)
	
## Dock Methods
func ShowMessage(message: String) -> void:
	ShowContainer(messageContainer)
	messageLabel.text = message
	
func ShowSettingsMenu() -> void:
	ShowContainer(settingsScrollContainer)
	settingsButton.text = "Save Settings"
	pageination.visible = false

func HideSettingsMenu() -> void:
	ShowContainer(previewsScrollContainer)
	settingsButton.text = "Settings"

func ShowContainer(container : Container) -> void:
	pageination.visible = container == previewsScrollContainer
	previewsScrollContainer.visible = previewsScrollContainer == container
	previewsScrollContainer.scroll_vertical = 0
	settingsScrollContainer.visible = settingsScrollContainer == container
	messageContainer.visible = messageContainer == container

func SaveSettings() -> void:
	if plugin:
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), useLibraryStructureCheckBox.button_pressed)
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_LIBRARY_PATH), plugin.libraryPath)
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_SAVE_TO_PATH), plugin.saveToPath)
		plugin.SetSetting(plugin.SETTINGS_PATH.path_join(plugin.SETTINGS_VOLUME_SLIDER), volumeSlider.value)

func SetupSignals() -> void:
	volumeSlider.value_changed.connect(_on_volume_slider_value_changed)
	searchButton.pressed.connect(_on_search_button_pressed)
	settingsButton.pressed.connect(_on_settings_button_pressed)
	searchBar.text_changed.connect(_on_search_text_changed)
	searchBar.text_submitted.connect(_on_search_text_submitted)
	useLibraryStructureCheckBox.toggled.connect(_on_use_library_structure_toggled)
	libraryPathLineEdit.text_changed.connect(_on_library_path_changed)
	saveToPathLineEdit.text_changed.connect(_on_save_to_path_changed)
	deleteConfirmationDialog.canceled.connect(_on_confirmation_closed)
	deleteConfirmationDialog.confirmed.connect(_on_confirmation_confirmed)
	deleteConfirmationDialog.close_requested.connect(_on_confirmation_closed)
	pageination.page_changed.connect(_on_page_changed)
	resyncButton.pressed.connect(_on_resnyc_button_pressed)

func LoadLibrary(forceResync : bool = false) -> void:
	pageination.DisablePaginationNavigation.call_deferred()
	settingsButton.set_deferred("disabled", true)
	resyncButton.set_deferred("disabled", true)
	searchButton.set_deferred("disabled", true)

	if forceResync:
		if plugin.libraryCache:
			plugin.libraryCache.soundLibrary.clear()
			ResourceSaver.save(plugin.libraryCache)

	var files: Array[String] = []
	if !forceResync &&plugin.libraryCache && plugin.libraryCache.soundLibrary.size() > 0:
		ShowMessage.call_deferred("Loading sounds from cache...")
		files = plugin.libraryCache.soundLibrary.duplicate()
	if files.size() == 0 || forceResync:
		ShowMessage.call_deferred("No sounds found in cache. Searching library path...")
		files = RecursiveDirectorySearch(plugin.libraryPath)
	
	var pageNumber := 1
	var itemsOnPage := 0
	for soundFilePath in files:
		if !IsValidFileType(soundFilePath):
			continue
		var fileIndex := files.find(soundFilePath)
		if fileIndex == -1:
			continue
		
		soundDictionary[soundFilePath] = pageNumber

		itemsOnPage += 1
		if itemsOnPage >= pageination.itemsPerPage:
			pageNumber += 1
			itemsOnPage = 0

	if plugin.libraryCache:
		plugin.libraryCache.soundLibrary = files.duplicate()
		ResourceSaver.save(plugin.libraryCache)
	
	totalSoundsLabel.set_deferred("text", "Total: " + str(files.size()))

	if soundPreviews.size() == 0:
		ShowMessage.call_deferred("Found " + str(files.size()) + " sound files in library. Setting up preview containers...")
		# Instantiate the previews based on the number of items per page
		var taskId := WorkerThreadPool.add_task(LoadPreviews)
		WorkerThreadPool.wait_for_task_completion(taskId)
	
	pageination.SetTotalPages.call_deferred(soundDictionary.size())
	pageination.SetCurrentPage.call_deferred(1)

	ShowContainer.call_deferred(previewsScrollContainer)
	pageination.EnablePaginationNavigation.call_deferred()
	
	settingsButton.set_deferred("disabled", false)
	resyncButton.set_deferred("disabled", false)
	searchButton.set_deferred("disabled", false)

func LoadPreviews() -> void:
	for i in pageination.itemsPerPage:
		var soundPreview := soundPreviewScene.instantiate()
		soundPreviews.append.call_deferred(soundPreview)
		previewsContainer.add_child.call_deferred(soundPreview)
	
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
			totalSoundFiles += 1
			ShowMessage.call_deferred("Loading sounds from library... (" + str(totalSoundFiles) + " sounds found)")
			totalSoundsLabel.set_deferred("text", "Total: " + str(totalSoundFiles))
			files.append(directory.path_join(fileName))
		fileName = dirAccess.get_next()
	
	dirAccess.list_dir_end()
	return files

func IsValidFileType(filePath: String) -> bool:
	var validExtensions : Array[String] = ["wav", "ogg", "mp3"]
	var fileExtension := filePath.get_extension().to_lower()
	return fileExtension in validExtensions

func SearchLibrary() -> void:
	var searchQuery : = searchBar.text.to_lower().split(" ")

	var pageNumber := 1
	var itemsOnPage := 0

	for soundFilePath : String in soundDictionary.keys():
		var soundNameAndDirectory := soundFilePath.replace(plugin.libraryPath, "")
		var loweredSoundName := soundNameAndDirectory.to_lower()
		
		var foundMatches := 0
		for query in searchQuery:
			if loweredSoundName.find(query) != -1:
				foundMatches += 1
		
		if foundMatches == searchQuery.size():
			
			filteredSoundDictionary[soundFilePath] = pageNumber
			itemsOnPage += 1
			if itemsOnPage >= pageination.itemsPerPage:
				pageNumber += 1
				itemsOnPage = 0

	totalSoundsLabel.set_deferred("text", str("Total: " , filteredSoundDictionary.size(), " / ", soundDictionary.size()))
	pageination.SetTotalPages.call_deferred(filteredSoundDictionary.size())
	pageination.SetCurrentPage.call_deferred(1)

	if filteredSoundDictionary.size() == 0:
		ShowMessage.call_deferred("No results...")
	else:
		ShowContainer.call_deferred(previewsScrollContainer)

