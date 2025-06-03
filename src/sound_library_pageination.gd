@tool
class_name SoundLibraryPagination
extends BoxContainer

signal page_changed(new_page: int)

var _pageForward : Button
var _pageBackward : Button
var _pageLabel : Label

var _totalPages : int = 0
var _currentPage : int = 1
var _itemsPerPage : int = 10


func _ready() -> void:
	_pageForward = $Forward
	_pageBackward = $Backward
	_pageLabel = $PageNumber

	_pageForward.pressed.connect(_on_page_forward_pressed)
	_pageBackward.pressed.connect(_on_page_backward_pressed)


func _on_page_forward_pressed() -> void:
	if _currentPage < _totalPages:
		_currentPage += 1
	else:
		_currentPage = 1
	SetCurrentPage(_currentPage)


func _on_page_backward_pressed() -> void:
	if _currentPage > 1:
		_currentPage -= 1
	else:
		_currentPage = _totalPages
	SetCurrentPage(_currentPage)


func SetCurrentPage(page : int) -> void:
	_currentPage = page
	_pageLabel.text = str(_currentPage) + " / " + str(_totalPages)
	page_changed.emit(_currentPage)


func SetTotalPages(itemCount : int) -> void:
	_totalPages = int(itemCount/ _itemsPerPage)
	
	EnablePaginationNavigation()
	

func DisablePaginationNavigation() -> void:
	_pageForward.disabled = true
	_pageBackward.disabled = true
	_pageLabel.text = "1 / 1"


func EnablePaginationNavigation() -> void:
	_pageForward.disabled = false
	_pageBackward.disabled = false
	_pageLabel.text = str(_currentPage) + " / " + str(_totalPages)
	if _totalPages <= 1:
		_totalPages = 1
		DisablePaginationNavigation()


func GetItemsPerPage() -> int:
	return _itemsPerPage

