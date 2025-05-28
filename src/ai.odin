package main

import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:slice"
import "core:mem"

EXPLORATION_CONSTANT: f32 : 1.4142

MCTSNode :: struct {
    parent: ^MCTSNode,
    visits: u32,
    wins: i32,
    move: [2]u32,
    children: [dynamic]MCTSNode,
    untried_moves: [][2]u32,
    tried_count: u32,
    uct: f32,
}

simulate_game_at_random :: proc (board: ^Board) {
    for {
        valid_moves := board_get_valid_moves(board)
        defer delete(valid_moves)

        if len(valid_moves) <= 20 {
            break
        }

        move := rand.choice(valid_moves)

        board_set(board, move.x, move.y)
    }
}

run_mcts_ai :: proc (board: ^Board, iterations: u32) -> [2]u32 {
    root := MCTSNode {
        untried_moves = board_get_valid_moves(board),
    }
    defer delete_node(&root)

    testing_board, _ := board_clone(board)
    defer board_delete(testing_board)

    for i in 0..<iterations {
        fmt.printfln("Processing iteration %d...", i)

        iterate(testing_board, &root)

        mem.copy_non_overlapping(slice.as_ptr(testing_board.prev_board_state), slice.as_ptr(board.prev_board_state), len(board.data))
        mem.copy_non_overlapping(slice.as_ptr(testing_board.data), slice.as_ptr(board.data), len(board.data))
        testing_board.next_stone = board.next_stone
        testing_board.black_captures = board.black_captures
        testing_board.white_captures = board.white_captures
    }

    fmt.println("Finished.")

    return get_max_uct_child(root.children[:]).move
}

get_max_uct_child :: proc (children: []MCTSNode) -> ^MCTSNode {
    max_uct_child: ^MCTSNode
    max_uct: f32 = -9999999999999
    for &child in children {
        child_uct := get_node_uct(&child)
        if child_uct > max_uct {
            max_uct = child_uct
            max_uct_child = &child
        }
    }

    return max_uct_child
}

iterate :: proc (test_board: ^Board, node: ^MCTSNode) -> i32 {
    node.visits += 1

    if node.tried_count < u32(len(node.untried_moves)) {
        move_index := node.tried_count + u32(rand.int_max(len(node.untried_moves) - int(node.tried_count)))
        move := node.untried_moves[move_index]
        node.untried_moves[move_index] = node.untried_moves[node.tried_count]
        node.tried_count += 1

        side := test_board.next_stone

        board_set(test_board, move.x, move.y)

        create_child(test_board, node, move)
        child := slice.last_ptr(node.children[:])

        simulate_game_at_random(test_board)

        black_score, white_score := board_count_score(test_board)

        child.visits += 1

        // child and parent naturally play on opposite sides, the
        // result from the point of view of the current node is
        // returned
        if (black_score > white_score && side == .BLACK) || (white_score > black_score && side == .WHITE) {
            child.wins += 1
            node.wins -= 1
            return -1
        } else {
            child.wins -= 1
            node.wins += 1
            return 1
        }

    } else if len(node.children) > 0 {
        max_utc_child := get_max_uct_child(node.children[:])

        board_set(test_board, max_utc_child.move.x, max_utc_child.move.y)

        // if the child node lost, we win, and viceversa
        result := iterate(test_board, max_utc_child)
        node.wins -= result

        return -result
    } else {
        // nothing to do... visit counter was updated on the way here,
        // and there's no win or loss state so...
    }

    return 0
}

create_child :: proc (test_board: ^Board, parent: ^MCTSNode, move: [2]u32) {
    child := MCTSNode {
        parent = parent,
        move = move,
        untried_moves = board_get_valid_moves(test_board),
    }

    append(&parent.children, child)
}

delete_node :: proc (node: ^MCTSNode) {
    delete(node.untried_moves)

    for &child in node.children {
        delete_node(&child)
    }

    delete(node.children)
}

get_node_uct :: proc (node: ^MCTSNode) -> f32 {
    return (f32(node.wins) / f32(node.visits)) + \
        EXPLORATION_CONSTANT * \
        math.sqrt(math.log(f32(node.parent.visits), math.e) / f32(node.visits))
}
