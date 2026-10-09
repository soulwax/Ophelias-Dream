extends Control

const COLUMNS := 10
const ROWS := 20
const SHAPES: Array = [
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
]
const BLOCK_COLORS: Array[Color] = [
	Color("#d6c8a6"), Color("#91a7bd"), Color("#bd9a72"), Color("#aebc9b"),
	Color("#bca6bd"), Color("#bc8f83"), Color("#869e9a"),
]

var _board: Array[PackedInt32Array] = []
var _cells: Array[Vector2i] = []
var _piece_color := 0
var _piece_x := 3
var _piece_y := 0
var _gravity_left := 0.0
var _score := 0
var _lines := 0
var _paused := false
var _over := false
var _close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.tooltip_text = "Close the distraction"
	_close_button.custom_minimum_size = Vector2(42, 42)
	_close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_button.position = Vector2(-62, 20)
	_close_button.pressed.connect(close_game)
	add_child(_close_button)


func open_game() -> void:
	visible = true
	_new_game()
	_close_button.grab_focus.call_deferred()
	queue_redraw()


func close_game() -> void:
	visible = false


func is_open() -> bool:
	return visible


func handle_input(event: InputEvent) -> bool:
	if not visible or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return true
	match key.keycode:
		KEY_ESCAPE:
			close_game()
		KEY_LEFT, KEY_A:
			if not _paused and not _over:
				_try_move(-1, 0)
		KEY_RIGHT, KEY_D:
			if not _paused and not _over:
				_try_move(1, 0)
		KEY_DOWN, KEY_S:
			if not _paused and not _over and _try_move(0, 1):
				_score += 1
		KEY_UP, KEY_X:
			if not _paused and not _over:
				_rotate_piece()
		KEY_SPACE:
			if not _paused and not _over:
				_hard_drop()
		KEY_P:
			if not _over:
				_paused = not _paused
		KEY_R:
			_new_game()
		_:
			return false
	queue_redraw()
	return true


func _process(delta: float) -> void:
	if not visible or _paused or _over:
		return
	_gravity_left -= delta
	if _gravity_left <= 0.0:
		_gravity_left = maxf(0.12, 0.62 - float(_lines) * 0.025)
		if not _try_move(0, 1):
			_lock_piece()
	queue_redraw()


func _new_game() -> void:
	_board.clear()
	for _row in ROWS:
		var row := PackedInt32Array()
		row.resize(COLUMNS)
		_board.append(row)
	_score = 0
	_lines = 0
	_paused = false
	_over = false
	_spawn_piece()
	queue_redraw()


func _spawn_piece() -> void:
	var shape_index := randi_range(0, SHAPES.size() - 1)
	_cells = SHAPES[shape_index].duplicate()
	_piece_color = shape_index
	_piece_x = 3
	_piece_y = 0
	_gravity_left = 0.62
	if _collides(_piece_x, _piece_y, _cells):
		_over = true


func _collides(px: int, py: int, cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var x := px + cell.x
		var y := py + cell.y
		if x < 0 or x >= COLUMNS or y >= ROWS:
			return true
		if y >= 0 and _board[y][x] != 0:
			return true
	return false


func _try_move(dx: int, dy: int) -> bool:
	if _collides(_piece_x + dx, _piece_y + dy, _cells):
		return false
	_piece_x += dx
	_piece_y += dy
	return true


func _rotate_piece() -> void:
	var rotated: Array[Vector2i] = []
	for cell in _cells:
		rotated.append(Vector2i(3 - cell.y, cell.x))
	var min_x := COLUMNS
	var min_y := ROWS
	for cell in rotated:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	for i in rotated.size():
		rotated[i] -= Vector2i(min_x, min_y)
	for kick in [0, -1, 1, -2, 2]:
		if not _collides(_piece_x + kick, _piece_y, rotated):
			_piece_x += kick
			_cells = rotated
			return


func _hard_drop() -> void:
	while _try_move(0, 1):
		_score += 2
	_lock_piece()


func _lock_piece() -> void:
	for cell in _cells:
		var x := _piece_x + cell.x
		var y := _piece_y + cell.y
		if y < 0:
			_over = true
			return
		_board[y][x] = _piece_color + 1
	_clear_lines()
	_spawn_piece()


func _clear_lines() -> void:
	var cleared := 0
	var y := ROWS - 1
	while y >= 0:
		var full := true
		for x in COLUMNS:
			if _board[y][x] == 0:
				full = false
				break
		if full:
			_board.remove_at(y)
			var empty := PackedInt32Array()
			empty.resize(COLUMNS)
			_board.push_front(empty)
			cleared += 1
		else:
			y -= 1
	if cleared > 0:
		_lines += cleared
		_score += [0, 100, 300, 500, 800][cleared]


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.017, 0.02, 0.97))
	var cell_size := floorf(minf(28.0, minf((size.y - 170.0) / ROWS, (size.x - 250.0) / COLUMNS)))
	cell_size = maxf(12.0, cell_size)
	var board_size := Vector2(COLUMNS, ROWS) * cell_size
	var panel_size := Vector2(board_size.x + 250.0, board_size.y + 112.0)
	var origin := (size - panel_size) * 0.5
	var board_origin := origin + Vector2(28.0, 58.0)
	draw_rect(Rect2(origin, panel_size), Color(0.035, 0.045, 0.05, 1.0), true)
	draw_rect(Rect2(origin, panel_size), Color(0.44, 0.49, 0.47, 0.72), false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, origin + Vector2(28, 34), "OD-7 // UNSANCTIONED RECREATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d6c8a6"))
	draw_rect(Rect2(board_origin, board_size), Color("#10171b"), true)
	for y in ROWS:
		for x in COLUMNS:
			var value := _board[y][x]
			if value > 0:
				_draw_block(board_origin, cell_size, x, y, BLOCK_COLORS[value - 1])
	for cell in _cells:
		_draw_block(board_origin, cell_size, _piece_x + cell.x, _piece_y + cell.y, BLOCK_COLORS[_piece_color])
	for x in range(COLUMNS + 1):
		var px := board_origin.x + x * cell_size
		draw_line(Vector2(px, board_origin.y), Vector2(px, board_origin.y + board_size.y), Color(0.7, 0.8, 0.85, 0.07), 1.0)
	for y in range(ROWS + 1):
		var py := board_origin.y + y * cell_size
		draw_line(Vector2(board_origin.x, py), Vector2(board_origin.x + board_size.x, py), Color(0.7, 0.8, 0.85, 0.07), 1.0)
	var info_x := board_origin.x + board_size.x + 26.0
	draw_string(font, Vector2(info_x, board_origin.y + 24), "SCORE   %06d" % _score, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d6c8a6"))
	draw_string(font, Vector2(info_x, board_origin.y + 54), "LINES   %03d" % _lines, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9ca9aa"))
	var status := "GAME OVER" if _over else ("PAUSED" if _paused else "STACK CAREFULLY")
	draw_string(font, Vector2(info_x, board_origin.y + 96), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#bc8f83") if _over else Color("#9ca9aa"))
	draw_string(font, Vector2(info_x, board_origin.y + 150), "← →   Move", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9ca9aa"))
	draw_string(font, Vector2(info_x, board_origin.y + 175), "↑ / X   Turn", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9ca9aa"))
	draw_string(font, Vector2(info_x, board_origin.y + 200), "↓   Faster", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9ca9aa"))
	draw_string(font, Vector2(info_x, board_origin.y + 225), "Space   Drop", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9ca9aa"))
	draw_string(font, Vector2(info_x, board_origin.y + 250), "P   Pause  ·  R Restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9ca9aa"))
	draw_string(font, origin + Vector2(28, panel_size.y - 20), "A small diversion. The woods remain exactly where you left them.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.61, 0.6, 0.76))
	if _over or _paused:
		draw_rect(Rect2(board_origin, board_size), Color(0.01, 0.015, 0.02, 0.62), true)
		draw_string(font, board_origin + Vector2(0, board_size.y * 0.52), "GAME OVER  ·  PRESS R" if _over else "PAUSED  ·  PRESS P", HORIZONTAL_ALIGNMENT_CENTER, board_size.x, 19, Color("#e3d8bd"))


func _draw_block(board_origin: Vector2, cell_size: float, x: int, y: int, color: Color) -> void:
	var rect := Rect2(board_origin + Vector2(x, y) * cell_size + Vector2(1, 1), Vector2.ONE * (cell_size - 2.0))
	draw_rect(rect, color, true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Color(1, 1, 1, 0.22), true)
