package main

import rl "vendor:raylib"
import "core:log"

render_init_renderer :: proc () {
    log.info("Starting renderer...")

    rl.SetTraceLogLevel(.NONE)
    rl.SetConfigFlags({ .MSAA_4X_HINT })

    rl.InitWindow(800, 600, "Go")

    rl.SetExitKey(.KEY_NULL)

    rl.SetTargetFPS(60)

    rl.EnableCursor()

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

    for controller in GLOBAL_STATE.board_controllers {
        rl.DrawModelEx(
            controller.object.model^,
            controller.object.transform.position,
            controller.object.transform.rotation_axis,
            controller.object.transform.rotation_deg,
            1.0,
            rl.WHITE)

        half_area := controller.object.play_area / 2
        tile_offset := controller.object.play_area / f32(controller.board.size - 1)
        board_top := controller.object.transform.position.y + controller.object.height

        for y in 0..<controller.board.size {
            for x in 0..<controller.board.size {
                opacity: u8 = 255
                board_value := board_get(controller.board, x, y)
                model, get_model_ok := get_model_from_stone_type(board_value)

                if !get_model_ok {
                    if controller.object.hovered_coord == { i32(x), i32(y) } {
                        model, _ = get_model_from_stone_type(controller.board.next_stone)
                        opacity = 80
                    } else {
                        continue
                    }
                }

                offsets := controller.object.coord_offsets[x + y * controller.board.size]

                draw_x := f32(x) * tile_offset.x - half_area.x + controller.object.transform.position.x + offsets.x
                draw_y := f32(y) * tile_offset.y - half_area.y + controller.object.transform.position.z + offsets.y

                rl.DrawModel(model, {draw_x, board_top, draw_y}, 0.9, { 255, 255, 255, opacity })
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

    if GLOBAL_STATE.player.state == .MENU {
        ui_layout := ui_create_main_menu_layout()

        clay_raylib_render(&ui_layout)
    }

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
