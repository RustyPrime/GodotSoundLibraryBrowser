@tool
extends VBoxContainer
class_name SoundLibraryPreviewItem

const LOADING_MESSAGE : String = "Loading..."

var taskId : int = -1

var _playButton : Button
var _soundProgress : HSlider
var _soundTime : Label
var _soundNameLabel : RichTextLabel
var _useInProject : CheckBox
var _copyResPath : Button
var _copyUuid : Button
var _playbackContainer : Control
var _messageContainer : Control
var _messageLabel : Label

var _plugin : EditorPlugin
var _dock : SoundLibraryDock

var _soundFilePath: String = ""
var _libraryPath : String = ""
var _resourcePath : String = ""
var _saveToPath : String = ""
var _subDirectory: String = ""

var _soundPlayer: AudioStreamPlayer = null
var _audioStream : AudioStream = null

var _currentPlayTimeInSeconds: float = 0.0
var _initialized: bool = false


func Initialize(plugin : EditorPlugin, dock : SoundLibraryDock, soundFilePath : String, subDirectory : String) -> void:
	_plugin = plugin
	_dock = dock

	_soundFilePath = soundFilePath
	_soundPlayer = _dock.soundPlayer
	_libraryPath = _plugin.libraryPath
	_saveToPath = _plugin.saveToPath
	_subDirectory = subDirectory

	if _plugin.useSameDirectoryStructureAsLibrary:
		_resourcePath = _saveToPath.path_join(_subDirectory).path_join(_soundFilePath.get_file())
	else:
		_resourcePath = _saveToPath.path_join(_soundFilePath.get_file())

	if _soundPlayer == null or _soundFilePath == "":
		return

	_playButton = $PlaybackContainer/PlayButton
	_soundProgress = $PlaybackContainer/SoundProgressPanel/SoundProgress
	_soundTime = $PlaybackContainer/SoundTime
	_soundNameLabel = $SoundName

	_useInProject = $PlaybackContainer/UseInProject
	_copyResPath = $PlaybackContainer/CopyResPath
	_copyUuid = $PlaybackContainer/CopyUuid

	_playbackContainer = $PlaybackContainer
	_messageContainer = $MessageContainer
	_messageLabel = $MessageContainer/MessageLabel
	
	UpdateSoundNameLabel()

	SetupSignals()

	ShowMessage("Loading audio stream...")
	# Load the audio stream in a worker thread not block the main thread
	taskId = WorkerThreadPool.add_task(LoadAudioStream, true, str("Loading audio stream from: ", _soundFilePath.get_file()))
	
	if EditorInterface.get_edited_scene_root() != self:
		SetPlayButtonIcon(_plugin.PLAY_ICON)

	_initialized = true


func Reset()-> void:
	if _initialized:
		TeardownSignals()

		_soundProgress.set_value_no_signal(0.0)
		_currentPlayTimeInSeconds = 0.0
		_soundTime.text = str("00:00 / ", LOADING_MESSAGE)
		# TODO: This will block the main thread.
		WorkerThreadPool.wait_for_task_completion(taskId)
	
		taskId = -1
		_initialized = false

	if _audioStream != null:
		_audioStream = null

	if _soundPlayer != null:
		_soundPlayer.stop()
		_soundPlayer.stream = null


func UpdateSoundNameLabel(wordsToHighlight: Array[String] = []) -> void:
	if _soundNameLabel:
		var soundNameText := "Filename: " + _soundFilePath.get_file() + "\nDirectories: " + _subDirectory
		if wordsToHighlight.is_empty():
			_soundNameLabel.text = soundNameText
		else:
			var soundNameWithHighlights := soundNameText
			for wordToHighlight in wordsToHighlight:
				var queryIndex := soundNameWithHighlights.to_lower().find(wordToHighlight.to_lower())
				if queryIndex != -1:
					for c in wordToHighlight.length():
						if soundNameWithHighlights[queryIndex + c] == soundNameWithHighlights[queryIndex + c].to_upper():
							# If the character is uppercase, we will keep it uppercase in the highlighted version
							wordToHighlight[c] = wordToHighlight[c].to_upper()
					soundNameWithHighlights = soundNameWithHighlights.replacen(wordToHighlight, "[b]" + wordToHighlight + "[/b]")

			_soundNameLabel.text = soundNameWithHighlights


func _process(delta: float) -> void:
	if not _initialized:
		return

	if _soundPlayer == null or _soundTime == null or _soundProgress == null or _playButton == null:
		return

	if _audioStream != null:
		var audioStreamLengthInSeconds := int(_audioStream.get_length())
		
		if _soundPlayer.playing and _soundPlayer.stream == _audioStream:
			_currentPlayTimeInSeconds = _soundPlayer.get_playback_position() + AudioServer.get_time_since_last_mix()
			SetPlayButtonIcon(_plugin.PAUSE_ICON)
		else:
			SetPlayButtonIcon(_plugin.PLAY_ICON)
			

		var currentTime := TimeFormat(_currentPlayTimeInSeconds)
		var maxAudioTime := TimeFormat(audioStreamLengthInSeconds, 1)
		var progressValue : = _currentPlayTimeInSeconds / _audioStream.get_length() * 100.0
		if progressValue > 98.0:
			currentTime = TimeFormat(audioStreamLengthInSeconds, 1)
		_soundTime.text = str(currentTime, " / ", maxAudioTime)
		_soundProgress.set_value_no_signal(progressValue)
		
	else: 
		if WorkerThreadPool.is_task_completed(taskId):
			ShowMessage("ERROR: Audio stream could not be loaded. See console for details.")
		else:
			ShowMessage(LOADING_MESSAGE)
		_soundTime.text = "00:00 / 00:00"
		_soundProgress.set_value_no_signal(0.0)


func TimeFormat(seconds: int, minimumSeconds : int = -1) -> String:
	var minutes := int(seconds / 60)
	var remainingSeconds := int(seconds % 60)
	if minimumSeconds != -1 and seconds == 0 and minutes < 1:
		remainingSeconds = 1
	return "%02d:%02d" % [minutes, remainingSeconds]


func SetupSignals() -> void:
	_playButton.pressed.connect(_on_play_button_pressed)
	_soundProgress.value_changed.connect(_on_sound_progress_value_changed)
	_useInProject.toggled.connect(_on_use_in_project_toggled)
	_copyResPath.pressed.connect(_on_copy_res_path_pressed)
	_copyUuid.pressed.connect(_on_copy_uuid_pressed)
	_dock.deletion_confirmation_closed.connect(_on_deletion_confirmation_closed)
	_dock.deletion_confirmation_confirmed.connect(_on_deletion_confirmation_confirmed)


func TeardownSignals() -> void:
	_playButton.pressed.disconnect(_on_play_button_pressed)
	_soundProgress.value_changed.disconnect(_on_sound_progress_value_changed)
	_useInProject.toggled.disconnect(_on_use_in_project_toggled)
	_copyResPath.pressed.disconnect(_on_copy_res_path_pressed)
	_copyUuid.pressed.disconnect(_on_copy_uuid_pressed)
	_dock.deletion_confirmation_closed.disconnect(_on_deletion_confirmation_closed)
	_dock.deletion_confirmation_confirmed.disconnect(_on_deletion_confirmation_confirmed)


func LoadAudioStream() -> void:
	var fileToLoad := _soundFilePath
	if FileAccess.file_exists(_resourcePath):
		fileToLoad = _resourcePath
		_useInProject.set_pressed_no_signal(true)
		_copyResPath.disabled = false
		_copyUuid.disabled = false

	if fileToLoad == "":
		return
	if not FileAccess.file_exists(fileToLoad):
		return

	if fileToLoad.get_extension() == "wav":
		_audioStream = AudioStreamWAV.load_from_file(fileToLoad)
	elif fileToLoad.get_extension() == "ogg":
		_audioStream = AudioStreamOggVorbis.load_from_file(fileToLoad)
	elif fileToLoad.get_extension() == "mp3":
		_audioStream = AudioStreamMP3.load_from_file(fileToLoad)
	else:
		print("ERROR: Unsupported audio format: " + fileToLoad)
		return

	ShowContainer.call_deferred(_playbackContainer)


func ShowMessage(message: String) -> void:
	if _messageContainer and _messageLabel:
		_messageLabel.text = message
		ShowContainer(_messageContainer)


func ShowContainer(container: Control) -> void:
	_playbackContainer.visible = container == _playbackContainer
	_messageContainer.visible = container == _messageContainer


func SetPlayButtonIcon(iconName : String) -> void:
	if EditorInterface.get_edited_scene_root() != self and not _plugin.icons.is_empty():
		if not _plugin.icons.has(iconName):
			_playButton.text = "Play/Pause"
			return

		var iconTexture : Texture2D = _plugin.icons.get(iconName)
		if iconTexture:
			_playButton.icon = iconTexture
			_playButton.text = ""


## Signals
func _on_use_in_project_toggled(pressed: bool) -> void:
	if pressed:
		if FileAccess.file_exists(_resourcePath):
			print("File already exists at: " + _resourcePath)
			return
		if _soundFilePath != "":
			var absolutePathToSave := ProjectSettings.globalize_path(_resourcePath)
			if not DirAccess.dir_exists_absolute(absolutePathToSave) and DirAccess.make_dir_recursive_absolute(absolutePathToSave) != OK:
				print("Failed to create directory: " + _resourcePath)
				return
			var file := FileAccess.open(_resourcePath, FileAccess.WRITE)
			if not file:
				print("Failed to open file for writing: " + _resourcePath)
				return
			var bytes := FileAccess.get_file_as_bytes(_soundFilePath)
			if bytes.is_empty():
				print("Failed to read file: " + _soundFilePath)
				file.close()
				return
			file.store_buffer(bytes)
			file.close()
		
		_copyResPath.disabled = false
		_copyUuid.disabled = false
	else:
		_dock.deleteConfirmationDialog.dialog_text = "Are you sure you want to delete the following resource from the project?\n " + _resourcePath
		_dock.deleteConfirmationDialog.show()


func _on_copy_res_path_pressed() -> void:
	if FileAccess.file_exists(_resourcePath):
		DisplayServer.clipboard_set('"'+_resourcePath+'"')
	else:
		print("ERROR: Failed to get resource path: " + _resourcePath)


func _on_copy_uuid_pressed() -> void:
	
	var uid := ResourceLoader.get_resource_uid(_resourcePath)
	if uid != -1:
		var uidText := ResourceUID.id_to_text(uid)
		if uidText == "":
			print("ERROR: Failed to get UID path for resource: " + _resourcePath)
			return
		DisplayServer.clipboard_set('"'+str(uidText)+'"')
	else:
		print("Error: Failed to get UUID for resource: " + _resourcePath)


func _on_play_button_pressed() -> void:
	if _soundPlayer:
		if _soundPlayer.playing and _soundPlayer.stream == _audioStream:
			_soundPlayer.stop()
			return

		if _audioStream:
			_soundPlayer.stream = _audioStream
			# If the current play time is at the end of the audio stream, play it from the beginning
			if _currentPlayTimeInSeconds >= _audioStream.get_length() - 0.02:
				_currentPlayTimeInSeconds = 0.0
			
			_soundPlayer.play(_currentPlayTimeInSeconds)
		else:
			print("ERROR: No audio stream loaded for: " + _soundFilePath)
			return

	
func _on_sound_progress_value_changed(value: float) -> void:
	if _soundPlayer and _audioStream:
		var shouldPlay := _soundPlayer.playing
		_soundPlayer.stop()
		_soundPlayer.stream = _audioStream
		_currentPlayTimeInSeconds = value / 100.0 * _audioStream.get_length()
		_soundPlayer.seek(_currentPlayTimeInSeconds)
		if shouldPlay:
			_soundPlayer.play(_currentPlayTimeInSeconds)


func _on_deletion_confirmation_closed() -> void:
	pass


func _on_deletion_confirmation_confirmed() -> void:
	if DirAccess.remove_absolute(_resourcePath) == OK:
		_useInProject.set_pressed_no_signal(false)
		_copyResPath.disabled = true
		_copyUuid.disabled = true

		_audioStream = null
		ShowMessage.call_deferred(LOADING_MESSAGE)
		WorkerThreadPool.add_task(LoadAudioStream) # Reload the audio stream from the library
		

