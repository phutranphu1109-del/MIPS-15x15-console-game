# Registers used:
# a0-a2: Arguments for functions and syscalls
# v0: Return values and syscall numbers
# s0: Grid size
# s1: Board address
# s2: Current player (1 or 2)
# s3: Temporary storage for row in main
# s4: Temporary storage for column in main
# t0-t9: Temporary registers for counters and indices
# sp: Stack pointer
# ra: Return address
.data
	# Horizontal board lines
	hor_start: .asciiz "+"					# Start of horizontal line
	hor_seg:   .asciiz "---+"				# Segment of horizontal line
	nl:        .asciiz "\n"					# Newline character
	# Prompt messages for players
	prompt_p1: .asciiz "Player 1, please input your coordinates: "
	prompt_p2: .asciiz "Player 2, please input your coordinates: "
	# Error and game outcome messages
	error_msg:   .asciiz "Invalid input! Please input again: "
	p1_win_msg:  .asciiz "Player 1 wins\n"
	p2_win_msg:  .asciiz "Player 2 wins\n"
	tie_msg:     .asciiz "Tie\n"
	# Buffer for input and game board
	input_buf: .space 20					# Buffer for user input strings
	board:     .space 225					# Space for a 15x15 grid (225 bytes)
	# Added for file writing
	result_file: .asciiz "D:/School/CA/BTL/result.txt"	# Filename for output
	vert_bar_str: .asciiz "|"				# String for vertical bar
	space_str: .asciiz " "					# String for space character
.text
.globl main
# Main entry point of the program
main:
	li $s0, 15						# Set grid size to 15 (s0)
	la $s1, board						# Load board address into s1
	# Initialize board with spaces (ASCII 32)
	la $t0, board						# t0 = board address
	li $t1, 225						# t1 = total cells (15x15)
	li $t2, 32						# t2 = ASCII for space
init_board_loop:						# Loop to initialize each cell
	beq $t1, $zero, init_board_done				# If counter is zero, end loop
	sb $t2, 0($t0)						# Store space in current cell
	addi $t0, $t0, 1					# Increment address
	addi $t1, $t1, -1					# Decrement counter
	j init_board_loop
init_board_done:
	# Print the initial board
	jal print_board
	# Set starting player to Player 1
	li $s2, 1						# s2 = current player (1)
	# Main game loop: Alternate turns until win or tie
game_loop:
	# Print prompt based on current player
	beq $s2, 1, print_p1_prompt				# If player 1, print their prompt
	la $a0, prompt_p2					# Load Player 2 prompt
	j prompt_set
print_p1_prompt:
	la $a0, prompt_p1					# Load Player 1 prompt
prompt_set:
	li $v0, 4						# Syscall for print string
	syscall
	# Input loop: Read and validate user input
input_loop:
	# Read input string from user
	li $v0, 8						# Syscall for read string
	la $a0, input_buf					# Address of input buffer
	li $a1, 20						# Maximum length of input
	syscall
	# Trim newline character from input
	la $t0, input_buf					# t0 = start of input buffer
trim_nl_loop:
	lb $t1, 0($t0)						# Load byte at current address
	beq $t1, '\n', replace_nl				# If newline, replace it
	beq $t1, 0, trim_leading_start				# If null terminator, skip to leading trim
	addi $t0, $t0, 1					# Increment address
	j trim_nl_loop
replace_nl:
	sb $zero, 0($t0)					# Store null byte at newline position
	# Trim leading spaces
trim_leading_start:
	la $t9, input_buf					# Reset t9 to start of buffer
find_non_space:
	lb $t1, 0($t9)						# Load byte at t9
	beq $t1, ' ', trim_leading_skip				# If space, increment and check next
	beq $t1, 0, invalid_input				# If null, empty string, invalid input
	j leading_done
trim_leading_skip:
	addi $t9, $t9, 1					# Increment address
	j find_non_space
leading_done:
	move $a0, $t9						# a0 = address of first non-space character
	# Find comma in input string
	li $t0, 0						# t0 = index counter
find_comma:
	add $t5, $a0, $t0					# t5 = address of character at index
	lb $t6, 0($t5)						# Load byte at t5
	beq $t6, ',', comma_found				# If comma found, proceed
	beq $t6, 0, invalid_input				# If end of string, no comma, invalid
	addi $t0, $t0, 1					# Increment index
	j find_comma
comma_found:
	beq $t0, 0, invalid_input				# If no characters before comma, invalid
	# Validate left part (before comma) is digits
	li $t2, 0						# t2 = index for left part check
left_check_loop:
	bge $t2, $t0, left_check_done				# If index >= length, done
	add $t3, $a0, $t2					# t3 = address of character
	lb $t4, 0($t3)						# Load byte
	blt $t4, '0', invalid_input				# If not digit, invalid
	bgt $t4, '9', invalid_input				# If not digit, invalid
	addi $t2, $t2, 1					# Increment index
	j left_check_loop
left_check_done:
	# Skip leading spaces in right part (after comma)
	add $t7, $a0, $t0					# t7 = address after comma
	addi $t7, $t7, 1					# Move to character after comma
	li $t8, 0						# t8 = index for right part
find_right_non_space:
	add $t3, $t7, $t8					# t3 = address of character
	lb $t4, 0($t3)						# Load byte
	beq $t4, ' ', right_skip_space				# If space, increment and check next
	beq $t4, 0, invalid_input				# If null, no right part, invalid
	j right_digit_check
right_skip_space:
	addi $t8, $t8, 1					# Increment index
	j find_right_non_space
right_digit_check:
	move $t7, $t3						# t7 = address of first non-space in right part
	# Validate right part (after comma) is digits
	li $t2, 0						# t2 = length counter for right part
right_check_loop:
	add $t3, $t7, $t2					# t3 = address of character
	lb $t4, 0($t3)						# Load byte
	beq $t4, 0, right_end_check				# If end of string, check length
	blt $t4, '0', invalid_input				# If not digit, invalid
	bgt $t4, '9', invalid_input				# If not digit, invalid
	addi $t2, $t2, 1					# Increment length counter
	j right_check_loop
right_end_check:
	beq $t2, 0, invalid_input				# If no digits, invalid
	# Convert string parts to integers (row and column)
	# Save t2 and t7 on stack before function calls
	addi $sp, $sp, -8					# Allocate stack space for two words
	sw $t7, 4($sp)						# Save t7 (right part address)
	sw $t2, 0($sp)						# Save t2 (right part length)
	# Convert left part (row) to integer
	move $a1, $a0						# a1 = address of left part
	move $a2, $t0						# a2 = length of left part
	jal str_to_int						# Call string-to-int function
	move $s3, $v0						# s3 = row value
	# Restore saved registers
	lw $t2, 0($sp)						# Restore t2 (right length)
	lw $t7, 4($sp)						# Restore t7 (right address)
	addi $sp, $sp, 8					# Deallocate stack space
	# Convert right part (column) to integer
	move $a1, $t7						# a1 = address of right part
	move $a2, $t2						# a2 = length of right part
	jal str_to_int						# Call string-to-int function
	move $s4, $v0						# s4 = column value
	# Validate row and column are within range (0 to 14)
	blt $s3, 0, invalid_input				# If row < 0, invalid
	bgt $s3, 14, invalid_input				# If row > 14, invalid
	blt $s4, 0, invalid_input				# If column < 0, invalid
	bgt $s4, 14, invalid_input				# If column > 14, invalid
	# Check if cell is empty (ASCII 32 for space)
	mul $t1, $s3, $s0					# t1 = row * grid size
	add $t1, $t1, $s4					# t1 += column (index)
	add $t1, $s1, $t1					# t1 += board address
	lb $t2, 0($t1)						# Load byte at board[index]
	bne $t2, 32, invalid_input				# If not space, cell occupied, invalid
	# Input is valid; update board and check for win/tie
input_valid:
	# Set piece based on current player ('X' for P1, 'O' for P2)
	beq $s2, 1, player1_set
	li $t3, 'O'						# t3 = 'O' for Player 2
	j update_board_cell
player1_set:
	li $t3, 'X'						# t3 = 'X' for Player 1
update_board_cell:
	sb $t3, 0($t1)						# Store piece in board cell
	# Check for win condition
	move $a0, $s3						# a0 = row
	move $a1, $s4						# a1 = column
	move $a2, $t3						# a2 = player character
	jal check_win						# Call win check function
	bne $v0, $zero, handle_win				# If win, handle win condition
	# Check for tie (board full)
	jal is_board_full					# Call board full check
	bne $v0, $zero, handle_tie				# If full, handle tie
	# No win or tie; print board and switch player
	jal print_board						# Print updated board
	beq $s2, 1, switch_to_p2_player				# If current player is 1, switch to 2
	li $s2, 1						# Switch to Player 1
	j game_loop
switch_to_p2_player:
	li $s2, 2						# Switch to Player 2
	j game_loop
	# Handle win condition
handle_win:
	jal print_board						# Print the winning board to console
	# Now handle file writing for win condition
	# Open file for writing
	li $v0, 13						# Syscall for open file
	la $a0, result_file					# Filename
	li $a1, 1						# Open for writing
	li $a2, 0						# Mode ignored
	syscall
	# Save fd on stack (v0 has fd)
	addi $sp, $sp, -4
	sw $v0, 0($sp)
	# Write board to file
	lw $a0, 0($sp)						# Load fd into a0
	jal write_board_to_fd
	# Write win message to file
	lw $t0, 0($sp)						# Load fd into t0
	beq $s2, 1, write_p1_win_file
	# Write Player 2 win message to file
	li $v0, 15						# Syscall for write
	move $a0, $t0						# File descriptor
	la $a1, p2_win_msg					# Address of message
	li $a2, 13						# Length of "Player 2 wins\n"
	syscall
	j write_win_msg_done
write_p1_win_file:
	# Write Player 1 win message to file
	li $v0, 15						# Syscall for write
	move $a0, $t0						# File descriptor
	la $a1, p1_win_msg					# Address of message
	li $a2, 13						# Length of "Player 1 wins\n"
	syscall
write_win_msg_done:
	# Close the file
	li $v0, 16						# Syscall for close file
	move $a0, $t0						# File descriptor
	syscall
	# Deallocate stack space
	addi $sp, $sp, 4
	# Now print win message to console
	beq $s2, 1, print_p1_win
	la $a0, p2_win_msg					# Load Player 2 win message
	li $v0, 4						# Syscall for print string
	syscall
	j end_game
print_p1_win:
	la $a0, p1_win_msg					# Load Player 1 win message
	li $v0, 4						# Syscall for print string
	syscall
	j end_game
	# Handle tie condition
handle_tie:
	jal print_board						# Print the full board
	la $a0, tie_msg						# Load tie message
	li $v0, 4						# Syscall for print string
	syscall
	j end_game
	# Invalid input handler
invalid_input:
	la $a0, error_msg					# Load error message
	li $v0, 4						# Syscall for print string
	syscall
	j input_loop						# Loop back to input loop
	# End the program
end_game:
	li $v0, 10						# Syscall for exit program
	syscall
# Function: Convert string to integer
# Arguments: a1 = string address, a2 = string length
# Returns: v0 = integer value
str_to_int:
	li $v0, 0						# v0 = result (initialize to 0)
	li $t0, 0						# t0 = index counter
str_to_int_loop:						# Loop through each character
	beq $t0, $a2, str_to_int_end				# If index == length, end
	add $t1, $a1, $t0					# t1 = address of current character
	lb $t2, 0($t1)						# Load byte (character)
	sub $t2, $t2, 48					# Convert ASCII to integer (subtract '0')
	mul $v0, $v0, 10					# Multiply result by 10 for next digit
	add $v0, $v0, $t2					# Add current digit to result
	addi $t0, $t0, 1					# Increment index
	j str_to_int_loop
str_to_int_end:
	jr $ra							# Return to caller
# Function: Print the game board to console
# No arguments; uses s0 (grid size) and s1 (board address)
print_board:
	li $t0, 0						# t0 = line counter
	mul $t1, $s0, 2						# t1 = 2 * grid size
	addi $t1, $t1, 1					# t1 = total lines (2*size + 1 for borders)
print_board_loop:						# Loop through each line
	bge $t0, $t1, print_board_end				# If line counter >= total lines, end
	andi $t3, $t0, 1					# t3 = t0 & 1 (check if line is even)
	beq $t3, $zero, print_horizontal			# If even, print horizontal line
	j print_vertical					# If odd, print vertical line (cells)
print_horizontal:						# Print horizontal border
	li $v0, 4						# Syscall for print string
	la $a0, hor_start					# Print "+"
	syscall
	li $t4, 0						# t4 = column counter
hor_seg_loop:							# Loop through columns for segments
	bge $t4, $s0, hor_seg_end				# If column counter >= size, end
	li $v0, 4						# Syscall for print string
	la $a0, hor_seg						# Print "---+"
	syscall
	addi $t4, $t4, 1					# Increment column counter
	j hor_seg_loop
hor_seg_end:
	li $v0, 4						# Syscall for print string
	la $a0, nl						# Print newline
	syscall
	j after_print_line
print_vertical:							# Print vertical cells
	sub $t5, $t0, 1						# t5 = row index (line - 1)
	li $t6, 2						# t6 = 2 (for division)
	div $t5, $t6						# Divide t5 by 2
	mflo $t7						# t7 = floor division result (row index)
	li $v0, 11						# Syscall for print character
	li $a0, '|'						# Print "|"
	syscall
	li $t4, 0						# t4 = column counter
ver_col_loop:							# Loop through columns for cells
	bge $t4, $s0, ver_col_end				# If column counter >= size, end
	li $a0, ' '						# Print leading space
	syscall
	mul $t8, $t7, $s0					# t8 = row * size (index offset)
	add $t8, $t8, $t4					# t8 += column
	add $t8, $s1, $t8					# t8 += board address
	lb $a0, 0($t8)						# Load byte from board cell
	syscall							# Print the cell character
	li $a0, ' '						# Print trailing space
	syscall
	li $a0, '|'						# Print "|"
	syscall
	addi $t4, $t4, 1					# Increment column counter
	j ver_col_loop
ver_col_end:
	li $v0, 4						# Syscall for print string
	la $a0, nl						# Print newline
	syscall
after_print_line:
	addi $t0, $t0, 1					# Increment line counter
	j print_board_loop
print_board_end:
	jr $ra							# Return to caller
# Function: Write the game board to a file
# Argument: a0 = file descriptor
# Uses s0 (grid size) and s1 (board address)
write_board_to_fd:
	move $t9, $a0						# Save file descriptor in t9
	li $t0, 0						# t0 = line counter
	mul $t1, $s0, 2						# t1 = 2 * grid size
	addi $t1, $t1, 1					# t1 = total lines (2*size + 1 for borders)
write_bd_loop:							# Loop through each line
	bge $t0, $t1, write_bd_end				# If line counter >= total lines, end
	andi $t3, $t0, 1					# t3 = t0 & 1 (check if line is even)
	beq $t3, $zero, write_horizontal_part			# If even, write horizontal line
	j write_vertical_part					# If odd, write vertical line (cells)
write_horizontal_part:						# Write horizontal border
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, hor_start					# Address of "+"
	li $a2, 1						# Length of "+"
	syscall
	li $t4, 0						# t4 = column counter
wh_seg_loop:							# Loop through columns for segments
	bge $t4, $s0, wh_seg_end				# If column counter >= size, end
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, hor_seg						# Address of "---+" 
	li $a2, 4						# Length of "---+" 
	syscall
	addi $t4, $t4, 1					# Increment column counter
	j wh_seg_loop
wh_seg_end:
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, nl						# Address of newline
	li $a2, 1						# Length of "\n"
	syscall
	j after_write_line
write_vertical_part:						# Write vertical cells
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, vert_bar_str					# Address of "|"
	li $a2, 1						# Length of "|"
	syscall
	li $t4, 0						# t4 = column counter
wv_col_loop:							# Loop through columns for cells
	bge $t4, $s0, wv_col_end				# If column counter >= size, end
	# Write leading space
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, space_str					# Address of " "
	li $a2, 1						# Length of " "
	syscall
	# Compute row index
	sub $t5, $t0, 1						# t5 = line - 1
	li $t6, 2						# t6 = 2 (for division)
	div $t5, $t6						# Divide t5 by 2
	mflo $t7						# t7 = floor division result (row index)
	# Compute index and write cell character
	mul $t8, $t7, $s0					# t8 = row * size (index offset)
	add $t8, $t8, $t4					# t8 += column
	add $t8, $s1, $t8					# t8 = board address + index
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	move $a1, $t8						# Address of cell
	li $a2, 1						# Length 1
	syscall
	# Write trailing space
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, space_str					# Address of " "
	li $a2, 1						# Length of " "
	syscall
	# Write "|"
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, vert_bar_str					# Address of "|"
	li $a2, 1						# Length of "|"
	syscall
	addi $t4, $t4, 1					# Increment column counter
	j wv_col_loop
wv_col_end:
	# Write newline
	li $v0, 15						# Syscall for write
	move $a0, $t9						# File descriptor
	la $a1, nl						# Address of newline
	li $a2, 1						# Length of "\n"
	syscall
after_write_line:
	addi $t0, $t0, 1					# Increment line counter
	j write_bd_loop
write_bd_end:
	jr $ra							# Return to caller
# Function: Check if the current move wins the game
# Arguments: a0 = row, a1 = column, a2 = player character ('X' or 'O')
# Returns: v0 = 1 if win, 0 otherwise
check_win:
	# Horizontal check: Count consecutive pieces left and right
	li $t0, 0						# t0 = count left
	move $t1, $a0						# t1 = row
	sub $t2, $a1, 1						# t2 = column - 1
count_left_h:							# Loop to count left
	blt $t2, 0, end_count_left_h				# If column < 0, end
	mul $t3, $t1, $s0					# t3 = row * size
	add $t3, $t3, $t2					# t3 += column (index)
	add $t3, $s1, $t3					# t3 += board address
	lb $t4, 0($t3)						# Load byte at board[index]
	bne $t4, $a2, end_count_left_h				# If not player character, end
	addi $t0, $t0, 1					# Increment count left
	subi $t2, $t2, 1					# Decrement column
	j count_left_h
end_count_left_h:
	li $t5, 0						# t5 = count right
	move $t6, $a0						# t6 = row
	add $t7, $a1, 1						# t7 = column + 1
count_right_h:							# Loop to count right
	bge $t7, $s0, end_count_right_h				# If column >= size, end
	mul $t8, $t6, $s0					# t8 = row * size
	add $t8, $t8, $t7					# t8 += column (index)
	add $t8, $s1, $t8					# t8 += board address
	lb $t9, 0($t8)						# Load byte
	bne $t9, $a2, end_count_right_h				# If not player character, end
	addi $t5, $t5, 1					# Increment count right
	addi $t7, $t7, 1					# Increment column
	j count_right_h
end_count_right_h:
	add $t4, $t0, $t5					# t4 = total count (left + right)
	addi $t4, $t4, 1					# Include current cell
	bge $t4, 5, win_true					# If >= 5, win
	# Vertical check: Count consecutive pieces up and down
	li $t0, 0						# t0 = count up
	sub $t2, $a0, 1						# t2 = row - 1
	move $t3, $a1						# t3 = column
count_up_v:							# Loop to count up
	blt $t2, 0, end_count_up_v				# If row < 0, end
	mul $t4, $t2, $s0					# t4 = row * size
	add $t4, $t4, $t3					# t4 += column (index)
	add $t4, $s1, $t4					# t4 += board address
	lb $t5, 0($t4)						# Load byte
	bne $t5, $a2, end_count_up_v				# If not player character, end
	addi $t0, $t0, 1					# Increment count up
	subi $t2, $t2, 1					# Decrement row
	j count_up_v
end_count_up_v:
	li $t5, 0						# t5 = count down
	add $t6, $a0, 1						# t6 = row + 1
	move $t7, $a1						# t7 = column
count_down_v:							# Loop to count down
	bge $t6, $s0, end_count_down_v				# If row >= size, end
	mul $t8, $t6, $s0					# t8 = row * size
	add $t8, $t8, $t7					# t8 += column (index)
	add $t8, $s1, $t8					# t8 += board address
	lb $t9, 0($t8)						# Load byte
	bne $t9, $a2, end_count_down_v				# If not player character, end
	addi $t5, $t5, 1					# Increment count down
	addi $t6, $t6, 1					# Increment row
	j count_down_v
end_count_down_v:
	add $t4, $t0, $t5					# t4 = total count (up + down)
	addi $t4, $t4, 1					# Include current cell
	bge $t4, 5, win_true					# If >= 5, win
	# Diagonal check (top-left to bottom-right)
	li $t0, 0						# t0 = count upper-left
	sub $t2, $a0, 1						# t2 = row - 1
	sub $t3, $a1, 1						# t3 = column - 1
count_ul_d1:							# Loop to count upper-left
	blt $t2, 0, end_count_ul_d1				# If row < 0 or column < 0, end
	blt $t3, 0, end_count_ul_d1
	mul $t4, $t2, $s0					# t4 = row * size
	add $t4, $t4, $t3					# t4 += column (index)
	add $t4, $s1, $t4					# t4 += board address
	lb $t5, 0($t4)						# Load byte
	bne $t5, $a2, end_count_ul_d1				# If not player character, end
	addi $t0, $t0, 1					# Increment count
	subi $t2, $t2, 1					# Decrement row
	subi $t3, $t3, 1					# Decrement column
	j count_ul_d1
end_count_ul_d1:
	li $t5, 0						# t5 = count down-right
	add $t6, $a0, 1						# t6 = row + 1
	add $t7, $a1, 1						# t7 = column + 1
count_dr_d1:							# Loop to count down-right
	bge $t6, $s0, end_count_dr_d1				# If row >= size or column >= size, end
	bge $t7, $s0, end_count_dr_d1
	mul $t8, $t6, $s0					# t8 = row * size
	add $t8, $t8, $t7					# t8 += column (index)
	add $t8, $s1, $t8					# t8 += board address
	lb $t9, 0($t8)						# Load byte
	bne $t9, $a2, end_count_dr_d1				# If not player character, end
	addi $t5, $t5, 1					# Increment count
	addi $t6, $t6, 1					# Increment row
	addi $t7, $t7, 1					# Increment column
	j count_dr_d1
end_count_dr_d1:
	add $t4, $t0, $t5					# t4 = total count
	addi $t4, $t4, 1					# Include current cell
	bge $t4, 5, win_true					# If >= 5, win
	# Diagonal check (top-right to bottom-left)
	li $t0, 0						# t0 = count upper-right
	sub $t2, $a0, 1						# t2 = row - 1
	add $t3, $a1, 1						# t3 = column + 1
count_ur_d2:							# Loop to count upper-right
	blt $t2, 0, end_count_ur_d2				# If row < 0 or column >= size, end
	bge $t3, $s0, end_count_ur_d2
	mul $t4, $t2, $s0					# t4 = row * size
	add $t4, $t4, $t3					# t4 += column (index)
	add $t4, $s1, $t4					# t4 += board address
	lb $t5, 0($t4)						# Load byte
	bne $t5, $a2, end_count_ur_d2				# If not player character, end
	addi $t0, $t0, 1					# Increment count
	subi $t2, $t2, 1					# Decrement row
	addi $t3, $t3, 1					# Increment column
	j count_ur_d2
end_count_ur_d2:
	li $t5, 0						# t5 = count down-left
	add $t6, $a0, 1						# t6 = row + 1
	sub $t7, $a1, 1						# t7 = column - 1
count_dl_d2:							# Loop to count down-left
	bge $t6, $s0, end_count_dl_d2				# If row >= size or column < 0, end
	blt $t7, 0, end_count_dl_d2
	mul $t8, $t6, $s0					# t8 = row * size
	add $t8, $t8, $t7					# t8 += column (index)
	add $t8, $s1, $t8					# t8 += board address
	lb $t9, 0($t8)						# Load byte
	bne $t9, $a2, end_count_dl_d2				# If not player character, end
	addi $t5, $t5, 1					# Increment count
	addi $t6, $t6, 1					# Increment row
	subi $t7, $t7, 1					# Decrement column
	j count_dl_d2
end_count_dl_d2:
	add $t4, $t0, $t5					# t4 = total count
	addi $t4, $t4, 1					# Include current cell
	bge $t4, 5, win_true					# If >= 5, win
	# No win in any direction
	li $v0, 0						# v0 = 0 (no win)
	jr $ra
win_true:
	li $v0, 1						# v0 = 1 (win)
	jr $ra
# Function: Check if the board is full
# No arguments; uses s0 (grid size) and s1 (board address)
# Returns: v0 = 1 if full, 0 otherwise
is_board_full:
	li $t0, 0						# t0 = index counter
	mul $t1, $s0, $s0					# t1 = total cells (size * size)
loop_full_check:						# Loop through each cell
	beq $t0, $t1, is_full					# If index == total cells, board is full
	add $t2, $s1, $t0					# t2 = board address + index
	lb $t3, 0($t2)						# Load byte at cell
	beq $t3, 32, not_full					# If space (ASCII 32), not full
	addi $t0, $t0, 1					# Increment index
	j loop_full_check
is_full:
	li $v0, 1						# v0 = 1 (board full)
	jr $ra
not_full:
	li $v0, 0						# v0 = 0 (board not full)
	jr $ra