# Copyright © 2025 RustyPrime.
# Editor Plugin for SoundLibraryBrowser
@tool
class_name SoundLibraryBrowserPlugin
extends EditorPlugin

const DOCK_SCENE: String =  "uid://dtv6w01hgjreb" #"res://addons/SoundLibraryBrowser/scenes/SoundLibraryDock.tscn"
const LIBRARY_CACHE : String =  "uid://bsp12xq2qfjxe" #"res://addons/SoundLibraryBrowser/resources/SoundLibraryCache.tres"
const SETTINGS_PATH : String = "sound_library_browser/settings"
const SETTINGS_USE_SAME_DIRECTORY_STRUCTURE : String = "use_same_directory_structure_as_library"
const SETTINGS_SAVE_TO_PATH : String = "save_to_path"
const SETTINGS_LIBRARY_PATH : String = "library_path"
const SETTINGS_VOLUME_SLIDER : String = "volume_slider"
const PLAY_ICON : String = "MainPlay"
const PAUSE_ICON : String = "Pause"

## Public variables
var useSameDirectoryStructureAsLibrary: bool = false
var saveToPath: String = ""
var libraryPath: String = ""
var volumeSlider : float = 0.05
var icons: Dictionary[String, Texture2D] = {}

## Private variables
var _libraryCache : SoundLibraryCache
var _libraryDock : SoundLibraryDock
var _editorSettings : EditorSettings


func _init() -> void:
	_libraryCache = ResourceLoader.load(LIBRARY_CACHE, "SoundLibraryCache")
	if not _libraryCache:
		print("Error: Could not load library cache resource.")
	
	
func _enter_tree() -> void:
	SetupEditorSettings()

	SetupIcons()

	_libraryDock = load(DOCK_SCENE).instantiate()
	_libraryDock.Initialize(self)


func _exit_tree() -> void:
	_libraryDock.RemoveDock()
	_libraryDock.queue_free()


func HasSetupCompleted() -> bool:
	return libraryPath != "" and saveToPath != ""


func SetupIcons() -> void:
	var godot_theme := EditorInterface.get_editor_theme()
	if not godot_theme:
		print("Error: Could not get editor theme.")
		return

	var playIconTexture := godot_theme.get_icon(PLAY_ICON, 'EditorIcons')
	icons.set(PLAY_ICON, playIconTexture)

	var pauseIconTexture := godot_theme.get_icon(PAUSE_ICON, 'EditorIcons')
	icons.set(PAUSE_ICON, pauseIconTexture)


## Editor Settings
func SetupEditorSettings() -> void:
	_editorSettings = EditorInterface.get_editor_settings()

	if not _editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_USE_SAME_DIRECTORY_STRUCTURE)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), true)
	else:
		useSameDirectoryStructureAsLibrary = GetSetting(SETTINGS_PATH.path_join(SETTINGS_USE_SAME_DIRECTORY_STRUCTURE), true)

	if not _editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_SAVE_TO_PATH)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_SAVE_TO_PATH), "")
	else:
		saveToPath = GetSetting(SETTINGS_PATH.path_join(SETTINGS_SAVE_TO_PATH), "")

	if not _editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_LIBRARY_PATH)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_LIBRARY_PATH), "")
	else:
		libraryPath = GetSetting(SETTINGS_PATH.path_join(SETTINGS_LIBRARY_PATH), "")

	if not _editorSettings.has_setting(SETTINGS_PATH.path_join(SETTINGS_VOLUME_SLIDER)):
		SetSetting(SETTINGS_PATH.path_join(SETTINGS_VOLUME_SLIDER), 0.05)
	else:
		volumeSlider = GetSetting(SETTINGS_PATH.path_join(SETTINGS_VOLUME_SLIDER), 0.05)
	

func SetSetting(_setting: String, _value: Variant) -> void:
	_editorSettings.set_setting(_setting, _value)


func GetSetting(_setting: String, _default: Variant) -> Variant:
	if _editorSettings.has_setting(_setting):
		return _editorSettings.get_setting(_setting)
	else:
		return _default


func HasSetting(_setting: String) -> bool:
	return _editorSettings.has_setting(_setting)


func EraseSetting(_setting: String) -> void:
	_editorSettings.erase(_setting)
