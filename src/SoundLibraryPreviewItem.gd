@tool
extends VBoxContainer
class_name SoundLibraryPreviewItem

const LOADING_MESSAGE : String = "Loading..."

var playButton : Button
var soundProgress : HSlider
var soundTime : Label
var soundNameLabel : RichTextLabel
var useInProject : CheckBox
var copyResPath : Button
var copyUuid : Button
var playbackContainer : Control
var messageContainer : Control
var messageLabel : Label

var soundFilePath: String = ""
var libraryPath : String = ""
var resourcePath : String = ""
var saveToPath : String = ""
var subDirectory: String = ""

var soundPlayer: AudioStreamPlayer = null
var audioStream : AudioStream = null

var currentPlayTimeInSeconds: float = 0.0

var plugin : EditorPlugin
var dock : SoundLibraryDock

var initialized: bool = false

var taskId : int = -1

func initialize(_plugin : EditorPlugin, _dock : SoundLibraryDock, _soundFilePath : String, _subDirectory : String) -> void:
	plugin = _plugin
	dock = _dock

	soundFilePath = _soundFilePath
	soundPlayer = dock.soundPlayer
	libraryPath = plugin.libraryPath
	saveToPath = plugin.saveToPath
	subDirectory = _subDirectory

	if plugin.useSameDirectoryStructureAsLibrary:
		resourcePath = saveToPath.path_join(subDirectory).path_join(soundFilePath.get_file())
	else:
		resourcePath = saveToPath.path_join(soundFilePath.get_file())

	if soundPlayer == null or _soundFilePath == "":
		return

	playButton = $PlaybackContainer/PlayButton
	soundProgress = $PlaybackContainer/SoundProgressPanel/SoundProgress
	soundTime = $PlaybackContainer/SoundTime
	soundNameLabel = $SoundName

	useInProject = $PlaybackContainer/UseInProject
	copyResPath = $PlaybackContainer/CopyResPath
	copyUuid = $PlaybackContainer/CopyUuid

	playbackContainer = $PlaybackContainer
	messageContainer = $MessageContainer
	messageLabel = $MessageContainer/MessageLabel
	
	UpdateSoundNameLabel()

	SetupSignals()

	ShowMessage("Loading audio stream...")
	# Load the audio stream in a worker thread not block the main thread
	taskId = WorkerThreadPool.add_task(LoadAudioStream, true, str("Loading audio stream from: ", soundFilePath.get_file()))
	
	if EditorInterface.get_edited_scene_root() != self:
		SetPlayButtonIcon("MainPlay")

	initialized = true

func reset()-> void:
	if initialized:
		TeardownSignals()

		soundProgress.set_value_no_signal(0.0)
		currentPlayTimeInSeconds = 0.0
		soundTime.text = str("00:00 / ", LOADING_MESSAGE)
		WorkerThreadPool.wait_for_task_completion(taskId)
	
		initialized = false

	if audioStream != null:
		audioStream = null

	if soundPlayer != null:
		soundPlayer.stop()
		soundPlayer.stream = null

func _process(delta: float) -> void:
	if !initialized:
		return

	if soundPlayer == null || soundTime == null || soundProgress == null || playButton == null:
		return

	if audioStream != null:
		var audioStreamLengthInSeconds := int(audioStream.get_length())
		
		if soundPlayer.playing && soundPlayer.stream == audioStream:
			currentPlayTimeInSeconds = soundPlayer.get_playback_position() + AudioServer.get_time_since_last_mix()
			SetPlayButtonIcon("Pause")
		else:
			SetPlayButtonIcon("MainPlay")
			

		var currentTime := TimeFormat(currentPlayTimeInSeconds)
		var maxAudioTime := TimeFormat(audioStreamLengthInSeconds, 1)
		var progressValue : = currentPlayTimeInSeconds / audioStream.get_length() * 100.0
		if progressValue > 98.0:
			currentTime = TimeFormat(audioStreamLengthInSeconds, 1)
		soundTime.text = str(currentTime, " / ", maxAudioTime)
		soundProgress.set_value_no_signal(progressValue)
		
	else: 
		if WorkerThreadPool.is_task_completed(taskId):
			ShowMessage("ERROR: Audio stream could not be loaded. See console for details.")
		else:
			ShowMessage(LOADING_MESSAGE)
		soundTime.text = "00:00 / 00:00"
		soundProgress.set_value_no_signal(0.0)

func TimeFormat(seconds: int, minimumSeconds : int = -1) -> String:
	var minutes := int(seconds / 60)
	var remainingSeconds := int(seconds % 60)
	if minimumSeconds != -1 and seconds == 0 and minutes < 1:
		remainingSeconds = 1
	return "%02d:%02d" % [minutes, remainingSeconds]

func SetupSignals() -> void:
	playButton.pressed.connect(_on_play_button_pressed)
	soundProgress.value_changed.connect(_on_sound_progress_value_changed)
	useInProject.toggled.connect(_on_use_in_project_toggled)
	copyResPath.pressed.connect(_on_copy_res_path_pressed)
	copyUuid.pressed.connect(_on_copy_uuid_pressed)
	dock.deletion_confirmation_closed.connect(_on_deletion_confirmation_closed)
	dock.deletion_confirmation_confirmed.connect(_on_deletion_confirmation_confirmed)

func TeardownSignals() -> void:
	playButton.pressed.disconnect(_on_play_button_pressed)
	soundProgress.value_changed.disconnect(_on_sound_progress_value_changed)
	useInProject.toggled.disconnect(_on_use_in_project_toggled)
	copyResPath.pressed.disconnect(_on_copy_res_path_pressed)
	copyUuid.pressed.disconnect(_on_copy_uuid_pressed)
	dock.deletion_confirmation_closed.disconnect(_on_deletion_confirmation_closed)
	dock.deletion_confirmation_confirmed.disconnect(_on_deletion_confirmation_confirmed)

func LoadAudioStream() -> void:
	var fileToLoad := soundFilePath
	if FileAccess.file_exists(resourcePath):
		fileToLoad = resourcePath
		useInProject.set_pressed_no_signal(true)
		copyResPath.disabled = false
		copyUuid.disabled = false

	if fileToLoad == "":
		return
	if not FileAccess.file_exists(fileToLoad):
		return

	if fileToLoad.get_extension() == "wav":
		audioStream = AudioStreamWAV.load_from_file(fileToLoad)
	elif fileToLoad.get_extension() == "ogg":
		audioStream = AudioStreamOggVorbis.load_from_file(fileToLoad)
	elif fileToLoad.get_extension() == "mp3":
		audioStream = AudioStreamMP3.load_from_file(fileToLoad)
	else:
		print("ERROR: Unsupported audio format: " + fileToLoad)
		return

	ShowContainer.call_deferred(playbackContainer)

func UpdateSoundNameLabel(wordsToHighlight: Array[String] = []) -> void:
	if soundNameLabel:
		var soundNameText := "Filename: " + soundFilePath.get_file() + "\nDirectories: " + subDirectory
		if wordsToHighlight.is_empty():
			soundNameLabel.text = soundNameText
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

			soundNameLabel.text = soundNameWithHighlights

func ShowMessage(message: String) -> void:
	if messageContainer && messageLabel:
		messageLabel.text = message
		ShowContainer(messageContainer)
		
func ShowContainer(container: Control) -> void:
	playbackContainer.visible = container == playbackContainer
	messageContainer.visible = container == messageContainer

func SetPlayButtonIcon(iconName : String) -> void:
	if EditorInterface.get_edited_scene_root() != self && !plugin.icons.is_empty():
		if !plugin.icons.has(iconName):
			playButton.text = "Play/Pause"
			return

		var iconTexture : Texture2D = plugin.icons.get(iconName)
		if iconTexture:
			playButton.icon = iconTexture
			playButton.text = ""

# Signals
func _on_use_in_project_toggled(pressed: bool) -> void:
	if pressed:
		if FileAccess.file_exists(resourcePath):
			print("File already exists at: " + resourcePath)
			return
		if soundFilePath != "":
			var absolutePathToSave := ProjectSettings.globalize_path(resourcePath)
			if !DirAccess.dir_exists_absolute(absolutePathToSave) && DirAccess.make_dir_recursive_absolute(absolutePathToSave) != OK:
				print("Failed to create directory: " + resourcePath)
				return
			var file := FileAccess.open(resourcePath, FileAccess.WRITE)
			if not file:
				print("Failed to open file for writing: " + resourcePath)
				return
			var bytes := FileAccess.get_file_as_bytes(soundFilePath)
			if bytes.is_empty():
				print("Failed to read file: " + soundFilePath)
				file.close()
				return
			file.store_buffer(bytes)
			file.close()
		
		copyResPath.disabled = false
		copyUuid.disabled = false
	else:
		dock.deleteConfirmationDialog.dialog_text = "Are you sure you want to delete the following resource from the project?\n " + resourcePath
		dock.deleteConfirmationDialog.show()
	
func _on_copy_res_path_pressed() -> void:
	if FileAccess.file_exists(resourcePath):
		DisplayServer.clipboard_set('"'+resourcePath+'"')
	else:
		print("ERROR: Failed to get resource path: " + resourcePath)

func _on_copy_uuid_pressed() -> void:
	
	var uid := ResourceLoader.get_resource_uid(resourcePath)
	if uid != -1:
		var uidText := ResourceUID.id_to_text(uid)
		if uidText == "":
			print("ERROR: Failed to get UID path for resource: " + resourcePath)
			return
		DisplayServer.clipboard_set('"'+str(uidText)+'"')
	else:
		print("Error: Failed to get UUID for resource: " + resourcePath)

func _on_play_button_pressed() -> void:
	if soundPlayer:
		if soundPlayer.playing && soundPlayer.stream == audioStream:
			soundPlayer.stop()
			return

		if audioStream:
			soundPlayer.stream = audioStream
			# If the current play time is at the end of the audio stream, play it from the beginning
			if currentPlayTimeInSeconds >= audioStream.get_length() - 0.02:
				currentPlayTimeInSeconds = 0.0
			
			soundPlayer.play(currentPlayTimeInSeconds)
		else:
			print("ERROR: No audio stream loaded for: " + soundFilePath)
			return
		
func _on_sound_progress_value_changed(value: float) -> void:
	if soundPlayer && audioStream:
		var shouldPlay := soundPlayer.playing
		soundPlayer.stop()
		soundPlayer.stream = audioStream
		currentPlayTimeInSeconds = value / 100.0 * audioStream.get_length()
		soundPlayer.seek(currentPlayTimeInSeconds)
		if shouldPlay:
			soundPlayer.play(currentPlayTimeInSeconds)

func _on_deletion_confirmation_closed() -> void:
	pass

func _on_deletion_confirmation_confirmed() -> void:
	if DirAccess.remove_absolute(resourcePath) == OK:
		useInProject.set_pressed_no_signal(false)
		copyResPath.disabled = true
		copyUuid.disabled = true

		audioStream = null
		ShowMessage.call_deferred(LOADING_MESSAGE)
		WorkerThreadPool.add_task(LoadAudioStream) # Reload the audio stream from the library
		

