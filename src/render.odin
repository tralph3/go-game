package main

import rl "vendor:raylib"
import "core:math/linalg"
import "core:log"

render_init_renderer :: proc () {
    log.info("Starting renderer...")

    rl.SetTraceLogLevel(.NONE)
    rl.SetConfigFlags({ .MSAA_4X_HINT })

    rl.InitWindow(800, 600, "Go")

    rl.SetTargetFPS(60)

    rl.DisableCursor()

    rl.InitAudioDevice()
}

render_deinit_renderer :: proc () {
    log.info("Shutting down renderer...")

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

        half_area := board_object.play_area / 2
        tile_offset := board_object.play_area / f32(board_object.board.size - 1)
        board_top := board_object.transform.position.y + board_object.height
        player := &GLOBAL_STATE.player

        for y in 0..<board_object.board.size {
            for x in 0..<board_object.board.size {
                opacity: u8 = 255
                board_value := board_get(board_object.board, x, y)
                model, get_model_ok := get_model_from_stone_type(board_value)

                if !get_model_ok {
                    if board_object.hovered_coord == { i32(x), i32(y) } {
                        model, _ = get_model_from_stone_type(board_object.board.next_stone)
                        opacity = 80
                    } else {
                        continue
                    }
                }

                draw_x := f32(x) * tile_offset.x - half_area.x + board_object.transform.position.x
                draw_y := f32(y) * tile_offset.y - half_area.y + board_object.transform.position.z

                rl.DrawModel(model, {draw_x, board_top, draw_y}, 1, { 255, 255, 255, opacity })
            }
        }
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

    rl.EndMode3D()

    if GLOBAL_STATE.player.state == .ROAMING {
        rl.DrawCircle(rl.GetRenderWidth() / 2, rl.GetRenderHeight() / 2, 1, rl.WHITE)
    }

    when ODIN_DEBUG {
        rl.DrawFPS(0, 0)
    }

    rl.EndDrawing()
}

@(private="file")
get_model_from_stone_type :: proc (stone_type: BoardState) -> (model: rl.Model, ok: bool) {
    #partial switch stone_type {
    case .BLACK:
        return GLOBAL_STATE.assets.models[.BLACK_STONE], true
    case .WHITE:
        return GLOBAL_STATE.assets.models[.WHITE_STONE], true
    }

    return
}
