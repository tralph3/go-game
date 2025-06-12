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
import "core:strings"

import "gtp"
import "gltf"
import cl "clay"

main :: proc () {
    context.logger = log.create_console_logger(opt={ .Level, .Terminal_Color })
    defer log.destroy_console_logger(context.logger)

    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				log.errorf("=== %v allocations not freed ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					log.errorf("%v bytes @ %v", entry.size, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

    GLOBAL_STATE.ctx = context
    defer state_free()

    render_init_renderer()
    defer render_deinit_renderer()

    if !assets_load_all() {
        log.error("Failed loading assets")
        return
    }
    defer assets_unload_all()

    shaders_init()
    models_init()

    ui_init()
    defer ui_deinit()

    if !world_init() {
        log.error("Failed initializing world objects")
        return
    }
    defer board_controller_free_all()

    board_configure_client_type(GLOBAL_STATE.board_controllers[0], .NONE)

    player_init({ -1.0, 0.0 }, 1.9, 1)

    for !GLOBAL_STATE.should_exit && !rl.WindowShouldClose() {
        board_controllers_make_all_pending_moves()
        if GLOBAL_STATE.player.state == .MENU {
            ui_update()
        }
        shaders_update()
        player_update()
        render_world()

        free_all(context.temp_allocator)
    }
}
