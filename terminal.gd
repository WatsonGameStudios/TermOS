extends Control

@onready var terminal_text: RichTextLabel = $TerminalText

# File system
var current_directory: String = "user://files/"

# Multi-line input mode 
var multiline_mode: bool = false
var multiline_filename: String = ""
var multiline_content: Array = []

var history: String = ""
var current_input: String = ""
var prompt: String = "> "
var cursor_visible: bool = true
var cursor_timer: float = 0.0
var cursor_blink_speed: float = 0.5

# Command history
var command_history: Array = []
var history_index: int = -1

# Display settings
var current_color: Color = Color.GREEN
var current_font: FontFile = null

# Game mode
enum Mode { TERMINAL, SNAKE, TETRIS }
var current_mode: Mode = Mode.TERMINAL

# Snake game variables
var snake_body: Array = []
var snake_direction: Vector2i = Vector2i.RIGHT
var snake_next_direction: Vector2i = Vector2i.RIGHT
var food_position: Vector2i = Vector2i.ZERO
var snake_width: int = 30
var snake_height: int = 20

# Tetris game variables
var tetris_grid: Array = []
var tetris_width: int = 10
var tetris_height: int = 20
var current_piece: Array = []
var current_piece_type: int = 0
var current_piece_rotation: int = 0
var piece_position: Vector2i = Vector2i.ZERO
var next_piece_type: int = 0

# Tetromino definitions [rotation][y][x]
var tetrominoes: Array = [
	# I piece
	[
		[[0,0,0,0], [1,1,1,1], [0,0,0,0], [0,0,0,0]],
		[[0,0,1,0], [0,0,1,0], [0,0,1,0], [0,0,1,0]],
		[[0,0,0,0], [0,0,0,0], [1,1,1,1], [0,0,0,0]],
		[[0,1,0,0], [0,1,0,0], [0,1,0,0], [0,1,0,0]]
	],
	# O piece
	[
		[[1,1], [1,1]],
		[[1,1], [1,1]],
		[[1,1], [1,1]],
		[[1,1], [1,1]]
	],
	# T piece
	[
		[[0,1,0], [1,1,1], [0,0,0]],
		[[0,1,0], [0,1,1], [0,1,0]],
		[[0,0,0], [1,1,1], [0,1,0]],
		[[0,1,0], [1,1,0], [0,1,0]]
	],
	# S piece
	[
		[[0,1,1], [1,1,0], [0,0,0]],
		[[0,1,0], [0,1,1], [0,0,1]],
		[[0,0,0], [0,1,1], [1,1,0]],
		[[1,0,0], [1,1,0], [0,1,0]]
	],
	# Z piece
	[
		[[1,1,0], [0,1,1], [0,0,0]],
		[[0,0,1], [0,1,1], [0,1,0]],
		[[0,0,0], [1,1,0], [0,1,1]],
		[[0,1,0], [1,1,0], [1,0,0]]
	],
	# J piece
	[
		[[1,0,0], [1,1,1], [0,0,0]],
		[[0,1,1], [0,1,0], [0,1,0]],
		[[0,0,0], [1,1,1], [0,0,1]],
		[[0,1,0], [0,1,0], [1,1,0]]
	],
	# L piece
	[
		[[0,0,1], [1,1,1], [0,0,0]],
		[[0,1,0], [0,1,0], [0,1,1]],
		[[0,0,0], [1,1,1], [1,0,0]],
		[[1,1,0], [0,1,0], [0,1,0]]
	]
]

# Shared game variables
var game_timer: float = 0.0
var game_tick_speed: float = 0.15
var game_score: int = 0
var game_over: bool = false

# Available fonts
var fonts: Dictionary = {}

# Predefined colors
var color_presets: Dictionary = {
	"green": Color.GREEN,
	"white": Color.WHITE,
	"red": Color.RED,
	"blue": Color.BLUE,
	"cyan": Color.CYAN,
	"yellow": Color.YELLOW,
	"magenta": Color.MAGENTA,
	"orange": Color.ORANGE,
	"lime": Color(0.5, 1, 0),
	"purple": Color.PURPLE,
	"pink": Color.PINK,
	"gray": Color.GRAY,
	"grey": Color.GRAY,
}

# Command registry
var commands: Dictionary = {}

func _ready() -> void:
	# Set up the terminal
	terminal_text.clear()

	# Initialize file system
	init_file_system()

	# Load available fonts
	load_fonts()

	# Register built-in commands
	register_commands()

	# Display welcome message
	print_welcome()

	update_display()

	# Make sure we can receive input
	set_process_input(true)

func init_file_system() -> void:
	# Create files directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(current_directory):
		DirAccess.make_dir_recursive_absolute(current_directory)

func print_welcome() -> void:
	print_line("TermOS v0.1")
	print_line("Type 'help' for available commands")
	print_line("")

func load_fonts() -> void:
	fonts["regular"] = load("res://singletons/fonts/JetBrainsMono-Regular.ttf")
	fonts["bold"] = load("res://singletons/fonts/JetBrainsMono-Bold.ttf")
	fonts["extrabold"] = load("res://singletons/fonts/JetBrainsMono-ExtraBold.ttf")
	fonts["italic"] = load("res://singletons/fonts/JetBrainsMono-Italic.ttf")

	# Set default font
	current_font = fonts["regular"]

func register_commands() -> void:
	commands["help"] = cmd_help
	commands["clear"] = cmd_clear
	commands["echo"] = cmd_echo
	commands["about"] = cmd_about
	commands["color"] = cmd_color
	commands["font"] = cmd_font
	commands["launch_game"] = cmd_launch_game
	commands["init"] = cmd_init
	commands["write"] = cmd_write
	commands["read"] = cmd_read
	commands["ls"] = cmd_ls
	commands["rm"] = cmd_rm
	commands["cd"] = cmd_cd
	commands["mkdir"] = cmd_mkdir
	commands["rmdir"] = cmd_rmdir
	commands["pwd"] = cmd_pwd


func _process(delta: float) -> void:
	if current_mode == Mode.TERMINAL:
		# Handle cursor blinking
		cursor_timer += delta
		if cursor_timer >= cursor_blink_speed:
			cursor_timer = 0.0
			cursor_visible = !cursor_visible
			update_display()
	elif current_mode == Mode.SNAKE:
		# Handle snake updates
		if not game_over:
			game_timer += delta
			if game_timer >= game_tick_speed:
				game_timer = 0.0
				update_snake()
				update_display()
	elif current_mode == Mode.TETRIS:
		# Handle tetris updates
		if not game_over:
			game_timer += delta
			if game_timer >= game_tick_speed:
				game_timer = 0.0
				move_piece_down()
				update_display()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Get the physical keycode
		var key = event.keycode

		if current_mode == Mode.SNAKE:
			handle_snake_input(key)
		elif current_mode == Mode.TETRIS:
			handle_tetris_input(key)
		elif current_mode == Mode.TERMINAL:
			if multiline_mode and key == KEY_ENTER and event.shift_held:
				# Add current line to content and start new line
				multiline_content.append(current_input)
				current_input = ""
				print_line("")  # Visual feedback for new line
				update_display()
				return
			# Handle special keys
			if key == KEY_BACKSPACE:
				handle_backspace()
			elif key == KEY_ENTER or key == KEY_KP_ENTER:
				handle_enter()
			elif key == KEY_TAB:
				handle_tab()
			elif key == KEY_UP:
				navigate_history_up()
			elif key == KEY_DOWN:
				navigate_history_down()
			else:
				# Handle regular character input
				var unicode = event.unicode
				if unicode != 0:
					var character = char(unicode)
					# Only accept printable characters
					if character != "" and unicode >= 32:
						current_input += character
						update_display()

func handle_backspace() -> void:
	if current_input.length() > 0:
		current_input = current_input.substr(0, current_input.length() - 1)
		update_display()

func handle_tab() -> void:
	current_input += "    "
	update_display()

func navigate_history_up() -> void:
	if command_history.size() == 0:
		return

	# First time pressing up - start from the end
	if history_index == -1:
		history_index = command_history.size() - 1
	elif history_index > 0:
		history_index -= 1

	current_input = command_history[history_index]
	update_display()

func navigate_history_down() -> void:
	if command_history.size() == 0 or history_index == -1:
		return

	# Move forward in history
	if history_index < command_history.size() - 1:
		history_index += 1
		current_input = command_history[history_index]
	else:
		# At the end of history, clear input
		history_index = -1
		current_input = ""

	update_display()



func print_line(text: String) -> void:
	history += text + "\n"
	update_display()

func execute_command(input: String) -> void:
	# Parse command and arguments
	var parts = input.split(" ", false)
	if parts.size() == 0:
		return

	var cmd = parts[0].to_lower()
	var args = parts.slice(1)

	# Execute command if it exists
	if commands.has(cmd):
		commands[cmd].call(args)
	else:
		print_line("Command not found: " + cmd)

# Built-in commands
func cmd_help(_args: Array) -> void:
	print_line("Available commands:")
	for cmd in commands.keys():
		print_line("  " + cmd)
	print_line("")

func cmd_clear(_args: Array) -> void:
	history = ""
	update_display()

func cmd_echo(args: Array) -> void:
	print_line(" ".join(args))

func cmd_about(_args: Array) -> void:
	print_line("TermOS - A text-based terminal operating system")
	print_line("Built with Godot 4.5")
	print_line("By Alex A. Watson")
	print_line("")

func cmd_init(args: Array) -> void:
	cmd_clear(args)
	print_welcome()

func cmd_color(args: Array) -> void:
	if args.size() == 0:
		print_line("Usage: color <name|r g b>")
		print_line("Available colors: " + ", ".join(color_presets.keys()))
		print_line("Or use: color <r> <g> <b> (values 0-255)")
		return

	# Check if it's a named color
	var color_name = args[0].to_lower()
	if color_presets.has(color_name):
		current_color = color_presets[color_name]
		print_line("Color set to " + color_name)
		update_display()
		return

	# Check if it's RGB values
	if args.size() >= 3:
		var r = float(args[0]) / 255.0
		var g = float(args[1]) / 255.0
		var b = float(args[2]) / 255.0
		current_color = Color(r, g, b)
		print_line("Color set to RGB(" + args[0] + ", " + args[1] + ", " + args[2] + ")")
		update_display()
		return

	print_line("Invalid color. Use 'color' without arguments for help.")

func cmd_font(args: Array) -> void:
	if args.size() == 0:
		print_line("Usage: font <name>")
		print_line("Available fonts: " + ", ".join(fonts.keys()))
		return

	var font_name = args[0].to_lower()
	if fonts.has(font_name):
		current_font = fonts[font_name]
		print_line("Font set to " + font_name)
		update_display()
	else:
		print_line("Font not found: " + font_name)
		print_line("Available fonts: " + ", ".join(fonts.keys()))

func cmd_launch_game(args: Array) -> void:
	if args.size() == 0:
		print_line("Usage: launch_game <game>")
		print_line("Available games: snake, tetris")
		return

	var game_name = args[0].to_lower()
	if game_name == "snake":
		print_line("Starting Snake...")
		print_line("Use arrow keys to move. Press ESC to quit.")
		print_line("")
		init_snake_game()
	elif game_name == "tetris":
		print_line("Starting Tetris...")
		print_line("Arrow keys: move/rotate. Down: fast drop. ESC: quit.")
		print_line("")
		init_tetris_game()
	else:
		print_line("Unknown game: " + game_name)
		print_line("Available games: snake, tetris")

# Snake game functions
func init_snake_game() -> void:
	# Initialize snake in the center
	snake_body.clear()
	@warning_ignore("integer_division")
	var start_x = snake_width / 2
	@warning_ignore("integer_division")
	var start_y = snake_height / 2
	snake_body.append(Vector2i(start_x, start_y))
	snake_body.append(Vector2i(start_x - 1, start_y))
	snake_body.append(Vector2i(start_x - 2, start_y))

	snake_direction = Vector2i.RIGHT
	snake_next_direction = Vector2i.RIGHT
	game_score = 0
	game_over = false
	game_timer = 0.0

	spawn_food()

	current_mode = Mode.SNAKE
	update_display()

func spawn_food() -> void:
	# Generate random food position
	while true:
		food_position = Vector2i(randi() % snake_width, randi() % snake_height)

		# Make sure food doesn't spawn on snake
		var valid = true
		for segment in snake_body:
			if segment == food_position:
				valid = false
				break

		if valid:
			break

func update_snake() -> void:
	# Update direction
	snake_direction = snake_next_direction

	# Calculate new head position
	var head = snake_body[0]
	var new_head = head + snake_direction

	# Check wall collision
	if new_head.x < 0 or new_head.x >= snake_width or new_head.y < 0 or new_head.y >= snake_height:
		game_over = true
		return

	# Check self collision
	for segment in snake_body:
		if segment == new_head:
			game_over = true
			return

	# Add new head
	snake_body.insert(0, new_head)

	# Check if food eaten
	if new_head == food_position:
		game_score += 10
		spawn_food()
	else:
		# Remove tail if no food eaten
		snake_body.pop_back()

func handle_snake_input(key: int) -> void:
	# Arrow key controls
	if key == KEY_UP and snake_direction != Vector2i.DOWN:
		snake_next_direction = Vector2i.UP
	elif key == KEY_DOWN and snake_direction != Vector2i.UP:
		snake_next_direction = Vector2i.DOWN
	elif key == KEY_LEFT and snake_direction != Vector2i.RIGHT:
		snake_next_direction = Vector2i.LEFT
	elif key == KEY_RIGHT and snake_direction != Vector2i.LEFT:
		snake_next_direction = Vector2i.RIGHT
	elif key == KEY_ESCAPE:
		# Exit game mode
		current_mode = Mode.TERMINAL
		print_line("Game Over! Final Score: " + str(game_score))
		print_line("")
		update_display()

func render_snake_game() -> void:
	var output = ""

	# Title and score
	output += "SNAKE - Score: " + str(game_score) + "\n"
	output += "Press ESC to quit\n\n"

	# Top border
	output += "┌"
	for i in range(snake_width):
		output += "─"
	output += "┐\n"

	# Game field
	for y in range(snake_height):
		output += "│"
		for x in range(snake_width):
			var pos = Vector2i(x, y)

			if pos == snake_body[0]:
				# Snake head
				output += "●"
			elif pos in snake_body:
				# Snake body
				output += "○"
			elif pos == food_position:
				# Food
				output += "◆"
			else:
				# Empty space
				output += " "

		output += "│\n"

	# Bottom border
	output += "└"
	for i in range(snake_width):
		output += "─"
	output += "┘\n"

	if game_over:
		output += "\nGAME OVER! Press ESC to return to terminal.\n"

	terminal_text.append_text(output)

# Tetris game functions
func init_tetris_game() -> void:
	# Initialize empty grid
	tetris_grid.clear()
	for y in range(tetris_height):
		var row = []
		for x in range(tetris_width):
			row.append(0)
		tetris_grid.append(row)

	game_score = 0
	game_over = false
	game_timer = 0.0
	game_tick_speed = 0.5

	# Spawn first pieces
	next_piece_type = randi() % tetrominoes.size()
	spawn_new_piece()

	current_mode = Mode.TETRIS
	update_display()

func spawn_new_piece() -> void:
	current_piece_type = next_piece_type
	next_piece_type = randi() % tetrominoes.size()
	current_piece_rotation = 0
	current_piece = tetrominoes[current_piece_type][current_piece_rotation]

	# Spawn at top center
	@warning_ignore("integer_division")
	piece_position = Vector2i(tetris_width / 2 - 1, 0)

	# Check if spawn position is blocked (game over)
	if not can_place_piece(piece_position, current_piece):
		game_over = true

func can_place_piece(pos: Vector2i, piece: Array) -> bool:
	for y in range(piece.size()):
		for x in range(piece[y].size()):
			if piece[y][x] == 1:
				var grid_x = pos.x + x
				var grid_y = pos.y + y

				# Check bounds
				if grid_x < 0 or grid_x >= tetris_width or grid_y >= tetris_height:
					return false

				# Check collision with placed pieces (but allow above grid)
				if grid_y >= 0 and tetris_grid[grid_y][grid_x] != 0:
					return false

	return true

func move_piece_down() -> void:
	var new_pos = piece_position + Vector2i(0, 1)

	if can_place_piece(new_pos, current_piece):
		piece_position = new_pos
	else:
		# Lock piece in place
		lock_piece()
		clear_lines()
		spawn_new_piece()

func lock_piece() -> void:
	for y in range(current_piece.size()):
		for x in range(current_piece[y].size()):
			if current_piece[y][x] == 1:
				var grid_x = piece_position.x + x
				var grid_y = piece_position.y + y
				if grid_y >= 0 and grid_y < tetris_height:
					tetris_grid[grid_y][grid_x] = current_piece_type + 1

func clear_lines() -> void:
	var lines_cleared = 0

	for y in range(tetris_height - 1, -1, -1):
		var is_full = true
		for x in range(tetris_width):
			if tetris_grid[y][x] == 0:
				is_full = false
				break

		if is_full:
			lines_cleared += 1
			# Remove the line
			tetris_grid.remove_at(y)
			# Add empty line at top
			var new_row = []
			for x in range(tetris_width):
				new_row.append(0)
			tetris_grid.insert(0, new_row)
			# Check this line again
			y += 1

	# Score: 100 per line, bonus for multiple lines
	if lines_cleared > 0:
		game_score += lines_cleared * lines_cleared * 100

func rotate_piece() -> void:
	var new_rotation = (current_piece_rotation + 1) % 4
	var new_piece = tetrominoes[current_piece_type][new_rotation]

	if can_place_piece(piece_position, new_piece):
		current_piece_rotation = new_rotation
		current_piece = new_piece
		update_display()

func move_piece_horizontal(direction: int) -> void:
	var new_pos = piece_position + Vector2i(direction, 0)

	if can_place_piece(new_pos, current_piece):
		piece_position = new_pos
		update_display()

func handle_tetris_input(key: int) -> void:
	if key == KEY_LEFT:
		move_piece_horizontal(-1)
	elif key == KEY_RIGHT:
		move_piece_horizontal(1)
	elif key == KEY_DOWN:
		move_piece_down()
		update_display()
	elif key == KEY_UP:
		rotate_piece()
	elif key == KEY_ESCAPE:
		# Exit game mode
		current_mode = Mode.TERMINAL
		print_line("Game Over! Final Score: " + str(game_score))
		print_line("")
		update_display()

func render_tetris_game() -> void:
	var output = ""

	# Title and score
	output += "TETRIS - Score: " + str(game_score) + "\n"
	output += "↑:Rotate ←→:Move ↓:Drop ESC:Quit\n\n"

	# Top border
	output += "┌"
	for i in range(tetris_width):
		output += "─"
	output += "┐\n"

	# Game field with current piece
	for y in range(tetris_height):
		output += "│"
		for x in range(tetris_width):
			var rendered = false

			# Check if current piece occupies this position
			for py in range(current_piece.size()):
				for px in range(current_piece[py].size()):
					if current_piece[py][px] == 1:
						var piece_x = piece_position.x + px
						var piece_y = piece_position.y + py
						if piece_x == x and piece_y == y:
							output += "■"
							rendered = true
							break
				if rendered:
					break

			# Otherwise show grid content
			if not rendered:
				if tetris_grid[y][x] == 0:
					output += " "
				else:
					output += "▪"

		output += "│\n"

	# Bottom border
	output += "└"
	for i in range(tetris_width):
		output += "─"
	output += "┘\n"

	if game_over:
		output += "\nGAME OVER! Press ESC to return to terminal.\n"

	terminal_text.append_text(output)

# File system commands
func cmd_write(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: write <filename> [content]")
		print_line("Example: write hello.txt Hello World!")
		print_line("Or: write hello.txt (then enter multi-line mode)")
		print_line("In multi-line mode: Shift+Enter for new line, Enter to finish")
		return

	var filename = args[0]

	# Add .txt extension if not present
	if not filename.ends_with(".txt"):
		filename += ".txt"

	# Check if content was provided
	if args.size() < 2:
		# Enter multi-line mode
		multiline_mode = true
		multiline_filename = filename
		multiline_content.clear()
		print_line("Multi-line mode activated for: " + filename)
		print_line("Press Shift+Enter for new line, Enter to finish and save")
		print_line("")
		return
	
	# Single-line mode: write immediately
	var content = " ".join(args.slice(1))
	var file_path = current_directory + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		file.store_string(content)
		file.close()
		print_line("File written: " + filename)
	else:
		print_line("Error: Could not write to file " + filename)
		
func write_multiline_file(filename: String, content: String) -> void:
	var file_path = current_directory + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if file:
		file.store_string(content)
		file.close()
		print_line("")
		print_line("File saved: " + filename + " (" + str(multiline_content.size()) + " lines)")
	else:
		print_line("")
		print_line("Error: Could not write to file " + filename)


func cmd_read(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: read <filename>")
		print_line("Example: read hello.txt")
		return

	var filename = args[0]

	# Add .txt extension if not present
	if not filename.ends_with(".txt"):
		filename += ".txt"

	var file_path = current_directory + filename

	if not FileAccess.file_exists(file_path):
		print_line("Error: File not found: " + filename)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)

	if file:
		var content = file.get_as_text()
		file.close()
		print_line("--- " + filename + " ---")
		print_line(content)
		print_line("--- End of file ---")
	else:
		print_line("Error: Could not read file " + filename)


func cmd_rm(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: rm <filename>")
		print_line("Example: rm hello.txt")
		return

	var filename = args[0]

	# Add .txt extension if not present
	if not filename.ends_with(".txt"):
		filename += ".txt"

	var file_path = current_directory + filename

	if not FileAccess.file_exists(file_path):
		print_line("Error: File not found: " + filename)
		return

	var error = DirAccess.remove_absolute(file_path)

	if error == OK:
		print_line("File deleted: " + filename)
	else:
		print_line("Error: Could not delete file " + filename)
		
# Directory navigation command
func cmd_cd(args: Array) -> void:
	if args.size() == 0:
		# Go to root directory
		current_directory = "user://files/"
		print_line("Changed to: " + current_directory)
		return
	
	var target = args[0]
	
	# Handle special cases
	if target == "..":
		# Go up one directory
		go_up_directory()
		return
	elif target == ".":
		# Stay in current directory
		print_line("Current directory: " + current_directory)
		return
	
	# Construct the new path
	var new_path: String
	
	if target.begins_with("user://"):
		# Absolute path
		new_path = target
	else:
		# Relative path
		new_path = current_directory + target
	
	# Ensure it ends with a slash
	if not new_path.ends_with("/"):
		new_path += "/"
	
	# Check if directory exists
	if DirAccess.dir_exists_absolute(new_path):
		current_directory = new_path
		print_line("Changed to: " + current_directory)
	else:
		print_line("Error: Directory not found: " + target)

# Helper function to go up one directory
func go_up_directory() -> void:
	# Don't go above user://files/
	if current_directory == "user://files/":
		print_line("Already at root directory")
		return
	
	# Remove trailing slash
	var path = current_directory.trim_suffix("/")
	
	# Find the last slash
	var last_slash = path.rfind("/")
	
	if last_slash != -1:
		# Get parent directory
		var parent = path.substr(0, last_slash + 1)
		
		# Make sure we don't go above user://files/
		if parent.length() >= "user://files/".length():
			current_directory = parent
			print_line("Changed to: " + current_directory)
		else:
			current_directory = "user://files/"
			print_line("Changed to: " + current_directory)
	else:
		current_directory = "user://files/"
		print_line("Changed to: " + current_directory)

# Print working directory command
func cmd_pwd(_args: Array) -> void:
	print_line(current_directory)

# Make directory command
func cmd_mkdir(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: mkdir <directory_name>")
		print_line("Example: mkdir projects")
		return
	
	var dirname = args[0]
	var new_path = current_directory + dirname + "/"
	
	# Check if directory already exists
	if DirAccess.dir_exists_absolute(new_path):
		print_line("Error: Directory already exists: " + dirname)
		return
	
	# Create the directory
	var error = DirAccess.make_dir_recursive_absolute(new_path)
	
	if error == OK:
		print_line("Directory created: " + dirname)
	else:
		print_line("Error: Could not create directory " + dirname)

# Remove directory command
func cmd_rmdir(args: Array) -> void:
	if args.size() < 1:
		print_line("Usage: rmdir <directory_name>")
		print_line("Example: rmdir old_projects")
		return
	
	var dirname = args[0]
	var dir_path = current_directory + dirname + "/"
	
	# Check if directory exists
	if not DirAccess.dir_exists_absolute(dir_path):
		print_line("Error: Directory not found: " + dirname)
		return
	
	# Check if directory is empty
	var dir = DirAccess.open(dir_path)
	if not dir:
		print_line("Error: Could not access directory")
		return
	
	dir.list_dir_begin()
	var has_contents = dir.get_next() != ""
	dir.list_dir_end()
	
	if has_contents:
		print_line("Error: Directory not empty. Delete contents first.")
		return
	
	# Remove the directory
	var error = DirAccess.remove_absolute(dir_path)
	
	if error == OK:
		print_line("Directory removed: " + dirname)
	else:
		print_line("Error: Could not remove directory " + dirname)

# Enhanced ls command to show directories
func cmd_ls(_args: Array) -> void:
	var dir = DirAccess.open(current_directory)
	
	if not dir:
		print_line("Error: Could not access directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var files: Array = []
	var directories: Array = []
	
	while file_name != "":
		if dir.current_is_dir():
			directories.append(file_name)
		else:
			files.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Display current directory
	print_line("Directory: " + current_directory)
	print_line("")
	
	# Display directories first
	if directories.size() > 0:
		print_line("Directories (" + str(directories.size()) + "):")
		for d in directories:
			print_line("  [DIR]  " + d)
		print_line("")
	
	# Then display files
	if files.size() > 0:
		print_line("Files (" + str(files.size()) + "):")
		for file in files:
			print_line("  [FILE] " + file)
		print_line("")
	
	if directories.size() == 0 and files.size() == 0:
		print_line("Empty directory")
		print_line("")

# Update the prompt to show current directory
func update_display() -> void:
	terminal_text.clear()
	
	# Apply current color and font
	terminal_text.add_theme_color_override("default_color", current_color)
	if current_font:
		terminal_text.add_theme_font_override("normal_font", current_font)
	
	if current_mode == Mode.TERMINAL:
		# Get shortened directory path for prompt
		var short_dir = get_short_directory()
		var custom_prompt = short_dir + " " + prompt
		
		# Display history + current prompt + current input + cursor
		var display_text = history + custom_prompt + current_input
		
		# Add cursor
		if cursor_visible:
			display_text += "█"
		else:
			display_text += " "
		
		terminal_text.append_text(display_text)
	elif current_mode == Mode.SNAKE:
		render_snake_game()
	elif current_mode == Mode.TETRIS:
		render_tetris_game()

# Helper function to get shortened directory path
func get_short_directory() -> String:
	if current_directory == "user://files/":
		return "~"
	
	# Remove the base path and show relative path
	var base = "user://files/"
	if current_directory.begins_with(base):
		var relative = current_directory.substr(base.length())
		# Remove trailing slash
		relative = relative.trim_suffix("/")
		return "~/" + relative
	
	return current_directory

# Update handle_enter to use custom prompt
func handle_enter() -> void:
	# Check if we're in multi-line mode FIRST
	if multiline_mode:
		# Add the final line
		multiline_content.append(current_input)
		
		# Join all lines with newlines
		var full_content = "\n".join(multiline_content)
		
		# Write the file
		write_multiline_file(multiline_filename, full_content)
		
		# Exit multi-line mode
		multiline_mode = false
		multiline_filename = ""
		multiline_content.clear()
		
		current_input = ""
		history_index = -1
		update_display()
		return
	
	# Get custom prompt for history (only for normal mode)
	var short_dir = get_short_directory()
	var custom_prompt = short_dir + " " + prompt
	
	# Add the input to history
	history += custom_prompt + current_input + "\n"
	
	# Save command to history array (if not empty)
	if current_input.strip_edges() != "":
		command_history.append(current_input.strip_edges())
		execute_command(current_input.strip_edges())
	
	# Clear current input and reset history navigation
	current_input = ""
	history_index = -1
	update_display()
