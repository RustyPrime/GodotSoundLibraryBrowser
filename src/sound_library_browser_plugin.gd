# Copyright © 2025 RustyPrime.
# Editor Plugin for SoundLibraryBrowser
@tool
extends EditorPlugin

const DOCK_SCENE: String = "res://addons/SoundLibraryBrowser/scenes/SoundLibraryDock.tscn"
const LIBRARY_CACHE : String = "res://addons/SoundLibraryBrowser/resources/SoundLibraryCache.tres"
const SETTINGS_PATH : String = "sound_library_browser/settings"
const SETTINGS_USE_SAME_DIRECTORY_STRUCTURE : String = "use_same_directory_structure_as_library"
const SETTINGS_SAVE_TO_PATH : String = "save_to_path"
const SETTINGS_LIBRARY_PATH : String = "library_path"
const SETTINGS_VOLUME_SLIDER : String = "volume_slider"

var libraryCache : SoundLibraryCache
var libraryDock : Node
var editorSettings : EditorSettings

var useSameDirectoryStructureAsLibrary: bool = false
var saveToPath: String = ""
var libraryPath: String = ""
var volumeSlider : float = 0.05
var icons: Dictionary[String, Texture2D] = {}

func _init() -> void:
	libraryCache = ResourceLoader.load(LIBRARY_CACHE, "SoundLibraryCache")
	if not libraryCache:
		print("Error: Could not load library cache resource.")
	
	

func _enter_tree() -> void:
	SetupEditorSettings()

	SetupIcons()

	libraryDock = load(DOCK_SCENE).instantiate()
	libraryDock.initialize(self)

func _exit_tree() -> void:
	libraryDock.RemoveDock()
	libraryDock.queue_free()

func HasSetupCompleted() -> bool:
	return libraryPath != "" and saveToPath != ""

func SetupIcons() -> void:
	var godot_theme := EditorInterface.get_editor_theme()
	if not godot_theme:
		print("Error: Theme is not available.")
		return

	var playButtonIcon := godot_theme.get_icon("MainPlay", 'EditorIcons')
	icons.set("MainPlay", playButtonIcon)
	var pauseButtonIcon := godot_theme.get_icon("Pause", 'EditorIcons')
	icons.set("Pause", pauseButtonIcon)

## Editor Settings
func SetupEditorSettings() -> void:
	editorSettings = EditorInterface.get_editor_settings()

	if not editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_USE_SAME_DIRECTORY_STRUCTURE)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), true)
	else:
		useSameDirectoryStructureAsLibrary = GetSetting(SETTINGS_PATH.path_join(SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), true)

	if not editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_SAVE_TO_PATH)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_SAVE_TO_PATH), "")
	else:
		saveToPath = GetSetting(SETTINGS_PATH.path_join(SETTINGS_SAVE_TO_PATH), "")

	if not editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_LIBRARY_PATH)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_LIBRARY_PATH), "")
	else:
		libraryPath = GetSetting(SETTINGS_PATH.path_join(SETTINGS_LIBRARY_PATH), "")

	if not editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_VOLUME_SLIDER)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_VOLUME_SLIDER), 0.05)
	else:
		volumeSlider = GetSetting(SETTINGS_PATH.path_join(SETTINGS_VOLUME_SLIDER), 0.05)
	
func SetSetting(_setting: String, _value: Variant) -> void:
	editorSettings.set_setting(_setting, _value)

func GetSetting(_setting: String, _default: Variant) -> Variant:
	if editorSettings.has_setting(_setting):
		return editorSettings.get_setting(_setting)
	else:
		return _default

func HasSetting(_setting: String) -> bool:
	return editorSettings.has_setting(_setting)

func EraseSetting(_setting: String) -> void:
	editorSettings.erase(_setting)
