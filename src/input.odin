package main

import rl "vendor:raylib"
import "core:fmt"
import "core:math"

input_process :: proc (player: ^Player, board: ^BoardObject, ogs_session: ^OGSSession, game_id: i64) {
    movement_vector: rl.Vector3 = {}

    if rl.IsKeyDown(.W) {
        movement_vector.x += 1
    }

    if rl.IsKeyDown(.S) {
        movement_vector.x -= 1
    }

    if rl.IsKeyDown(.A) {
        movement_vector.y -= 1
    }

    if rl.IsKeyDown(.D) {
        movement_vector.y += 1
    }

    if rl.IsKeyPressed(.M) {
        player_toggle_sit(player)
    }

    if rl.IsKeyPressed(.R) {
        board_reset(&board.board)
    }

    if rl.IsMouseButtonPressed(.LEFT) && player.sitting {
        ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), player.camera)

        collision := rl.GetRayCollisionQuad(ray,
            { -board.grid_size.x * 1.1, board.height, -board.grid_size.y * 1.1 },
            { -board.grid_size.x * 1.1, board.height,  board.grid_size.y * 1.1 },
            {  board.grid_size.x * 1.1, board.height,  board.grid_size.y * 1.1 },
            {  board.grid_size.x * 1.1, board.height, -board.grid_size.y * 1.1 },
        )

        if collision.hit {
            x := (collision.point.x + board.grid_size.x / 2) / tile_offset.x
            y := (collision.point.z + board.grid_size.y / 2) / tile_offset.y

            rx := u32(math.round(x))
            ry := u32(math.round(y))

            ogs_game_move(ogs_session, game_id, rx, ry)
            // error := board_set(&board.board, rx, ry)

                // if ai_thread != nil {
                //     thread.destroy(ai_thread)
                // }

                // ai_thread = thread.create_and_start_with_poly_data(&board, ai_play)
        }
    }

    mouse_wheel_delta := rl.GetMouseWheelMove()

    mouse_delta := rl.GetMouseDelta() * 0.1

    player_move(player, movement_vector, mouse_delta)

    player_update_camera_position(player, mouse_wheel_delta, { -0.5, 0.0001 }, { board.position.x, board.height, board.position.y })
}
