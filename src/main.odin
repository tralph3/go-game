package main

import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "core:mem"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:c"
import "core:thread"
import "core:time"
import "base:runtime"
import "core:log"

import "gltf"

Mode :: enum {
    FreeRoam,
    Playing,
}

RECTANGLE_SIZE :: 60
GAP_SIZE :: 3

main :: proc () {
    GLOBAL_STATE.ctx = runtime.default_context()

    GLOBAL_STATE.ctx.logger = log.create_console_logger()
    defer log.destroy_console_logger(GLOBAL_STATE.ctx.logger)

    render_init_raylib()
    defer render_deinit_raylib()

    GLOBAL_STATE.player = player_new({ -1.0, 0.0 }, 1.4, 1)

    GLOBAL_STATE.assets = assets_load_all()
    defer assets_unload_all(&GLOBAL_STATE.assets)

    board, _ := board_new(19)
    defer board_delete(&board)

    board_object := BoardObject {
        board = board,
        position = { 0.0, 0.0, 0.0 },
    }

    shaders_configure(&shader, &{ 0.0, 0.0, 0.0, 1.0 })


    for !rl.WindowShouldClose() {
        rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "viewPos"), &player.camera.position, .VEC3)

        input_process(&player, &board_object, session, game_id)

        rl.BeginTextureMode(render_texture)
        rl.ClearBackground(rl.RED)
        rl.DrawTextPro(rl.GetFontDefault(), "Main Menu", {0, 0}, 0, 180, 12, 1, rl.WHITE)
        rl.DrawTextPro(rl.GetFontDefault(), "Play Local", {0, 180}, 0, 180, 12, 1, rl.WHITE)
        rl.DrawTextPro(rl.GetFontDefault(), "Play Online", {0, 160}, 0, 180, 12, 1, rl.WHITE)
        rl.DrawTextPro(rl.GetFontDefault(), "Exit", {0, 140}, 0, 180, 12, 1, rl.WHITE)
        rl.EndTextureMode()

        rl.BeginDrawing()

        render_world(&player, &board_object, room_model, board_model, plane_model, white_stone_model, black_stone_model)
        rl.EndDrawing()

    }

    for sound in stone_sounds {
        rl.UnloadSound(sound)
    }
}
