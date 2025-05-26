package main

import "core:mem"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:bytes"

BoardSetError :: enum u8 {
    NIL,
    OUT_OF_BOUNDS,
    INVALID_STATE,
    NOT_EMPTY,
    SUICIDE,
    LOOP,
}

BoardState :: enum u8 {
    OUT_OF_BOUNDS,
    EMPTY,
    BLACK,
    WHITE,
}

StoneGroup :: struct {
    liberties: u32,
    stone_type: BoardState,
    stones: [][2]u32,
}

Board :: struct {
    size: u32,
    data: []BoardState,
    next_stone: BoardState,
    prev_board_state: []BoardState,
    black_captures: u32,
    white_captures: u32,
    komi: f32,
}

board_count_score :: proc (board: ^Board) -> (black_score: f32, white_score: f32) {
    white_score = board.komi
    black_score = 0

    directions: [4][2]int = {
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
    }

    to_visit: [dynamic][2]u32
    defer delete(to_visit)

    visited: map[[2]u32]bool
    defer delete(visited)

    for y in 0..<board.size {
        for x in 0..<board.size {
            if visited[{x, y}] {
                continue
            }

            stone := board_get(board, x, y)

            switch stone {
            case .BLACK:
                black_score += 1
            case .WHITE:
                white_score += 1
            case .EMPTY:
                clear(&to_visit)
                append(&to_visit, [2]u32{x, y})

                has_white_neighbor := false
                has_black_neighbor := false

                visit: for i in 0..<len(to_visit) {
                    pos := to_visit[i]

                    for dir in directions {
                        nx := int(pos[0]) + dir[0]
                        ny := int(pos[1]) + dir[1]

                        neighbor := [2]u32{u32(nx), u32(ny)}
                        if visited[neighbor] {
                            continue
                        }

                        state := board_get(board, neighbor[0], neighbor[1])

                        switch state {
                        case .EMPTY:
                            append(&to_visit, neighbor)
                            visited[neighbor] = true
                        case .BLACK:
                            has_black_neighbor = true
                        case .WHITE:
                            has_white_neighbor = true
                        case .OUT_OF_BOUNDS:
                            fallthrough
                        }
                    }

                    visited[pos] = true
                }

                score := f32(len(to_visit))

                if has_white_neighbor && !has_black_neighbor {
                    white_score += score
                } else if has_black_neighbor && !has_white_neighbor {
                    black_score += score
                }
            case .OUT_OF_BOUNDS:
                panic("Unreachable: Iterated out of bounds of the array... somehow")
            }
        }
    }

    return black_score + f32(board.black_captures), white_score + f32(board.white_captures)
}

@(private="file")
board_swap_stone :: proc (board: ^Board) {
    if (board.next_stone == .WHITE) {
        board.next_stone = .BLACK
    } else if (board.next_stone == .BLACK) {
        board.next_stone = .WHITE
    }
}

board_get_valid_moves :: proc (board: ^Board) -> [][2]u32 {
    valid_moves: [dynamic][2]u32

    cloned_board, _ := board_clone(board)
    defer board_delete(&cloned_board)

    for y in 0..<board.size {
        for x in 0..<board.size {
            set_error := board_set(&cloned_board, x, y)

            if set_error == nil {
                append(&valid_moves, [2]u32{x, y})

                mem.copy_non_overlapping(slice.as_ptr(cloned_board.prev_board_state), slice.as_ptr(board.prev_board_state), len(board.data))
                mem.copy_non_overlapping(slice.as_ptr(cloned_board.data), slice.as_ptr(board.data), len(board.data))
            }
        }
    }

    return valid_moves[:]
}

board_new :: proc (size: u32, allocator: mem.Allocator = context.allocator) -> (board: Board, err: mem.Allocator_Error) {
    assert(size % 2 != 0 && size > 1)

    board_data := make([]BoardState, size * size, allocator) or_return
    board_prev_state := make([]BoardState, size * size, allocator) or_return

    for i in 0..<len(board_data) {
        board_data[i] = .EMPTY
    }

    mem.copy_non_overlapping(slice.as_ptr(board_prev_state), slice.as_ptr(board_data), len(board_data))

    board.size = size
    board.data = board_data
    board.next_stone = .BLACK
    board.prev_board_state = board_prev_state
    board.komi = 6.5

    return board, nil
}

board_reset :: proc (board: ^Board) {
    for i in 0..<len(board.data) {
        board.data[i] = .EMPTY
    }

    board.next_stone = .BLACK
}

board_delete :: proc (board: ^Board) {
    delete(board.data)
    delete(board.prev_board_state)
}

board_get :: proc (board: ^Board, x, y: u32) -> BoardState {
    if x < 0 || y < 0 || x >= board.size || y >= board.size {
        return .OUT_OF_BOUNDS
    }

    index := y * board.size + x

    return board.data[index]
}

board_set_no_check :: proc (board: ^Board, x, y: u32, state: BoardState) {
    index := y * board.size + x
    board.data[index] = state
}

board_set_no_ko :: proc (board: ^Board, x, y: u32) -> BoardSetError {
    tmp_board, _ := board_clone(board)
    defer board_delete(&tmp_board)

    board_state := board_get(board, x, y)

    if board_state == .OUT_OF_BOUNDS {
        return .OUT_OF_BOUNDS
    }

    if board_state != .EMPTY {
        return .NOT_EMPTY
    }

    directions: [4][2]int = {
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
    }

    // placed prematurely to make liberty counting easier
    board_set_no_check(board, x, y, board.next_stone)

    captures_stones := false
    opposite_stone: BoardState = board.next_stone == .BLACK ? .WHITE : .BLACK
    for direction in directions {
        nx := x + u32(direction[0])
        ny := y + u32(direction[1])
        stone := board_get(board, nx, ny)

        if stone != opposite_stone {
            continue
        }

        group := board_get_group_at_point(board, nx, ny)
        defer delete(group.stones)
        if group.stone_type == .OUT_OF_BOUNDS {
            continue
        }

        if group.stone_type == opposite_stone && group.liberties == 0 {
            captures_stones = true
            for stone_coord in group.stones {
                board_set_no_check(board, stone_coord[0], stone_coord[1], .EMPTY)
            }

            if board.next_stone == .BLACK {
                board.black_captures += u32(len(group.stones))
            } else {
                board.white_captures += u32(len(group.stones))
            }
        }
    }

    if !captures_stones {
        group := board_get_group_at_point(board, x, y)
        defer delete(group.stones)

        if group.liberties == 0 {
            // undo movement if it turned out to be invalid
            board_set_no_check(board, x, y, .EMPTY)
            return .SUICIDE
        }
    }

    board_set_no_check(board, x, y, board.next_stone)

    board_swap_stone(board)

    mem.copy_non_overlapping(slice.as_ptr(board.prev_board_state), slice.as_ptr(tmp_board.data), len(board.data))

    return nil
}

board_set :: proc (board: ^Board, x, y: u32) -> BoardSetError {
    cloned_board, _ := board_clone(board)
    defer board_delete(&cloned_board)

    board_set_no_ko(&cloned_board, x, y)

    ko := true
    for i in 0..<len(cloned_board.data) {
        if cloned_board.data[i] != board.prev_board_state[i] {
            ko = false
            break
        }
    }

    if ko {
        return .LOOP
    }

    return board_set_no_ko(board, x, y)
}

board_clone :: proc (board: ^Board, allocator: mem.Allocator = context.allocator) -> (Board, mem.Allocator_Error) {
    new_copy, err := board_new(board.size, allocator)
    if err != nil {
        return new_copy, err
    }

    mem.copy_non_overlapping(slice.as_ptr(new_copy.data), slice.as_ptr(board.data), len(board.data))
    mem.copy_non_overlapping(slice.as_ptr(new_copy.prev_board_state), slice.as_ptr(board.prev_board_state), len(board.data))

    new_copy.next_stone = board.next_stone

    return new_copy, nil
}

board_get_group_at_point :: proc (board: ^Board, x, y: u32) -> StoneGroup {
    stone := board_get(board, x, y)

    if stone == .OUT_OF_BOUNDS {
        return {
            stone_type = .OUT_OF_BOUNDS,
            stones = nil,
        }
    }

    liberty_count: u32 = 0

    to_visit: [dynamic][2]u32

    visited: map[[2]u32]bool
    defer delete(visited)

    append(&to_visit, [2]u32{x, y})

    directions: [4][2]int = {
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
    }

    for index in 0..<len(to_visit) {
        pos := to_visit[index]

        for dir in directions {
            nx := int(pos[0]) + dir[0]
            ny := int(pos[1]) + dir[1]

            neighbor := [2]u32{u32(nx), u32(ny)}
            if visited[neighbor] {
                continue
            }

            state := board_get(board, neighbor[0], neighbor[1])

            if state == BoardState.EMPTY {
                liberty_count += 1
                visited[neighbor] = true
            } else if state == stone {
                append(&to_visit, neighbor)
                visited[neighbor] = true
            }
        }
    }

    return {
        liberties = liberty_count,
        stone_type = stone,
        stones = to_visit[:],
    }
}

board_get_sgf_coordinate :: proc (x, y: u32, allocator := context.allocator) -> string {
    lowercase_ascii_offset :: 97

    return fmt.tprintf("%c%c", lowercase_ascii_offset + x, lowercase_ascii_offset + y)
}

board_get_sgf_coordinate_cstring :: proc (x, y: u32, allocator := context.allocator) -> cstring {
    lowercase_ascii_offset :: 97

    return fmt.ctprintf("%c%c", lowercase_ascii_offset + x, lowercase_ascii_offset + y)
}

board_get_coordinate_from_sgf_cstring :: proc "contextless" (str: cstring) -> [2]u32 {
    lowercase_ascii_offset :: 97

    x := ([^]u8)(str)[0] - lowercase_ascii_offset
    y := ([^]u8)(str)[1] - lowercase_ascii_offset

    return { u32(x), u32(y) }
}
