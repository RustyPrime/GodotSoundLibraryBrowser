@tool
extends BoxContainer
class_name SoundLibraryPagination

signal page_changed(new_page: int)

var totalPages : int = 0
var currentPage : int = 1

var itemsPerPage : int = 10

var pageForward : Button
var pageBackward : Button
var pageLabel : Label

func _ready() -> void:
	pageForward = $Forward
	pageBackward = $Backward
	pageLabel = $PageNumber

	pageForward.pressed.connect(_on_page_forward_pressed)
	pageBackward.pressed.connect(_on_page_backward_pressed)


func _on_page_forward_pressed() -> void:
	if currentPage < totalPages:
		currentPage += 1
	else:
		currentPage = 1
	SetCurrentPage(currentPage)

func _on_page_backward_pressed() -> void:
	if currentPage > 1:
		currentPage -= 1
	else:
		currentPage = totalPages
	SetCurrentPage(currentPage)

func SetCurrentPage(page : int) -> void:
	currentPage = page
	pageLabel.text = str(currentPage) + " / " + str(totalPages)
	page_changed.emit(currentPage)

func SetTotalPages(itemCount : int) -> void:
	totalPages = int(itemCount/ itemsPerPage)
	
	EnablePaginationNavigation()
	


func DisablePaginationNavigation() -> void:
	pageForward.disabled = true
	pageBackward.disabled = true
	pageLabel.text = "1 / 1"

func EnablePaginationNavigation() -> void:
	pageForward.disabled = false
	pageBackward.disabled = false
	pageLabel.text = str(currentPage) + " / " + str(totalPages)
	if totalPages <= 1:
		totalPages = 1
		DisablePaginationNavigation()