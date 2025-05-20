package main

import rl "vendor:raylib"

render_world :: proc (player: ^Player, board: ^BoardObject, world_model, board_model, white_stone_model, black_stone_model: rl.Model) {
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)

    rl.BeginMode3D(player.camera)

    rl.DrawModel(board_model, board.position, 1.0, rl.WHITE)
    rl.DrawModel(world_model, {}, 1.0, rl.WHITE)

    for y in 0..<board.board.size {
        for x in 0..<board.board.size {
            model: rl.Model
            board_value := board_get(&board.board, x, y)

            if (board_value == .WHITE) {
                model = white_stone_model
            } else if (board_value == .BLACK) {
                model = black_stone_model
            } else {
                continue
            }

            offset := (f32(board.board.size) - 1.0) / 2.0
            draw_x := tile_offset.x * (f32(x) - offset)
            draw_y := tile_offset.y * (f32(y) - offset)

            rl.DrawModel(model, {draw_x, board.height, draw_y}, 1, rl.WHITE)
        }
    }

    rl.EndMode3D()
    rl.EndDrawing()
}
