package main

import rl "vendor:raylib"
import "core:math/linalg"
import "core:log"

render_init_raylib :: proc () {
    log.info("Starting raylib...")

    rl.SetTraceLogLevel(.NONE)
    rl.SetConfigFlags({ .MSAA_4X_HINT })

    rl.InitWindow(800, 600, "Go")

    rl.SetTargetFPS(60)

    rl.DisableCursor()

    rl.InitAudioDevice()
}

render_deinit_raylib :: proc () {
    log.info("Shutting down raylib...")

    rl.CloseAudioDevice()
    rl.CloseWindow()
}

render_world :: proc () {
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)

    rl.BeginMode3D(GLOBAL_STATE.player.camera)

    rl.DrawModelEx(
        GLOBAL_STATE.room_object.model^,
        GLOBAL_STATE.room_object.transform.position,
        GLOBAL_STATE.room_object.transform.rotation_axis,
        GLOBAL_STATE.room_object.transform.rotation_deg,
        1.0,
        rl.WHITE)

    for board_object in GLOBAL_STATE.board_objects {
        rl.DrawModelEx(
            board_object.model^,
            board_object.transform.position,
            board_object.transform.rotation_axis,
            board_object.transform.rotation_deg,
            1.0,
            rl.WHITE)
    }

    for object in GLOBAL_STATE.objects {
        rl.DrawModelEx(
            object.model^,
            object.transform.position,
            object.transform.rotation_axis,
            object.transform.rotation_deg,
            1.0,
            rl.WHITE)
    }

    // for y in 0..<board.board.size {
    //     for x in 0..<board.board.size {
    //         model: rl.Model
    //         board_value := board_get(&board.board, x, y)

    //         if (board_value == .WHITE) {
    //             model = white_stone_model
    //         } else if (board_value == .BLACK) {
    //             model = black_stone_model
    //         } else {
    //             continue
    //         }

    //         offset := (f32(board.board.size) - 1.0) / 2.0
    //         draw_x := tile_offset.x * (f32(x) - offset)
    //         draw_y := tile_offset.y * (f32(y) - offset)

    //         rl.DrawModel(model, {draw_x, board.height, draw_y}, 1, rl.WHITE)
    //     }
    // }

    rl.EndMode3D()

    when ODIN_DEBUG {
        rl.DrawFPS(0, 0)
    }

    rl.EndDrawing()
}
