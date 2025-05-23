package main

import rl "vendor:raylib"
import "core:math/linalg"

plane_down := true

plane_position: rl.Vector3 = { -0.3, 0.27, 0 }
plane_rotation: f32 = 0.0

render_init_raylib :: proc () {
    rl.SetTraceLogLevel(.NONE)
    rl.SetConfigFlags({ .MSAA_4X_HINT, .VSYNC_HINT })

    rl.InitWindow(800, 600, "Go")

    rl.InitAudioDevice()
}

render_deinit_raylib :: proc () {
    rl.CloseAudioDevice()
    rl.CloseWindow()
}

render_world :: proc (player: ^Player, board: ^BoardObject, world_model, board_model, plane, white_stone_model, black_stone_model: rl.Model) {
    rl.ClearBackground(rl.BLACK)

    rl.BeginMode3D(player.camera)

    rl.DrawModel(board_model, board.position, 1.0, rl.WHITE)
    rl.DrawModel(world_model, {}, 1.0, rl.WHITE)

    plane_position_target: rl.Vector3
    plane_rotation_target: f32

    if rl.IsKeyPressed(.N) {
        plane_down = !plane_down
    }

    if plane_down {
        plane_position_target = { -0.3, 0.27, 0 }
        plane_rotation_target = 0.0
    } else {
        plane_position_target = { 0,  0.85, 0 }
        plane_rotation_target = 80
    }

    plane_position = linalg.lerp(plane_position, plane_position_target, 0.01)
    plane_rotation = linalg.lerp(plane_rotation, plane_rotation_target, 0.01)

    rl.DrawModelEx(plane,
                   plane_position, {1.0, 0, 0},
                   plane_rotation,
                   1, rl.WHITE)

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
}
