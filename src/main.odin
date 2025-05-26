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
    context.logger = log.create_console_logger(opt={ .Level, .Terminal_Color })
    defer log.destroy_console_logger(context.logger)

    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				log.errorf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					log.errorf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}
	}


    GLOBAL_STATE.ctx = context
    defer state_free()

    render_init_raylib()
    defer render_deinit_raylib()

    if !assets_load_all() {
        log.errorf("Failed loading assets")
        return
    }
    defer assets_unload_all()

    board, _ := board_new(19)
    defer board_delete(&board)

    shaders_init()
    models_init()
    world_init(&board)

    player_init({ -1.0, 0.0 }, 1.9, 1)

    for !rl.WindowShouldClose() {
        shaders_update()
        player_update()
        render_world()

        free_all(context.temp_allocator)
    }
}
