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

main :: proc () {
    GLOBAL_STATE.ctx = runtime.default_context()

    GLOBAL_STATE.ctx.logger = log.create_console_logger()
    defer log.destroy_console_logger(GLOBAL_STATE.ctx.logger)

    context = GLOBAL_STATE.ctx

    render_init_raylib()
    defer render_deinit_raylib()

    GLOBAL_STATE.assets = assets_load_all()
    defer assets_unload_all(&GLOBAL_STATE.assets)

    shaders_init()
    models_init()
    world_init()
    player_init({ -1.0, 0.0 }, 1.4, 1)

    board, _ := board_new(19)
    defer board_delete(&board)

    for !rl.WindowShouldClose() {
        shaders_update()
        player_update()
        render_world()
    }
}
