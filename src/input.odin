package main

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:math/linalg"

input_process :: proc () {
    // if rl.IsMouseButtonPressed(.LEFT) && player.sitting {
    //     ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), player.camera)

    //     collision := rl.GetRayCollisionQuad(ray,
    //         { -board.grid_size.x * 1.1, board.height, -board.grid_size.y * 1.1 },
    //         { -board.grid_size.x * 1.1, board.height,  board.grid_size.y * 1.1 },
    //         {  board.grid_size.x * 1.1, board.height,  board.grid_size.y * 1.1 },
    //         {  board.grid_size.x * 1.1, board.height, -board.grid_size.y * 1.1 },
    //     )

    //     if collision.hit {
    //         x := (collision.point.x + board.grid_size.x / 2) / tile_offset.x
    //         y := (collision.point.z + board.grid_size.y / 2) / tile_offset.y

    //         rx := u32(math.round(x))
    //         ry := u32(math.round(y))

    //         ogs_game_move(ogs_session, game_id, rx, ry)
    //         // error := board_set(&board.board, rx, ry)

    //             // if ai_thread != nil {
    //             //     thread.destroy(ai_thread)
    //             // }

    //             // ai_thread = thread.create_and_start_with_poly_data(&board, ai_play)
    //     }
    // }

    // mouse_wheel_delta := rl.GetMouseWheelMove()

    // mouse_delta := rl.GetMouseDelta() * 0.1

    // player_move(player, movement_vector, mouse_delta)

    // player_update_camera_position(player, mouse_wheel_delta, { -0.5, 0.0001 }, { board.position.x, board.height, board.position.y })
}

input_get_clicked_board_object :: proc () -> ^BoardWorldObject {
    if !rl.IsMouseButtonPressed(.LEFT) {
        return nil
    }

    click: [2]f32 = { f32(rl.GetRenderWidth()) / 2.0, f32(rl.GetRenderHeight()) / 2.0 }
    ray := rl.GetScreenToWorldRay(click, GLOBAL_STATE.player.camera)

    for &board in GLOBAL_STATE.board_objects {
        box := rl.GetModelBoundingBox(board.model^)
        box.min += board.transform.position
        box.max += board.transform.position

        if rl.GetRayCollisionBox(ray, box).hit {
            return &board
        }
    }

    return nil
}

input_get_board_coord :: proc (board: ^BoardWorldObject) -> (coord: [2]u32, hit, click: bool) {
    click = rl.IsMouseButtonPressed(.LEFT)

    ray := rl.GetScreenToWorldRay(
        rl.GetMousePosition(), GLOBAL_STATE.player.camera)

    half_area := board.play_area / 2
    half_scaled := half_area * 1.05 // give a bit of margin so you
                                    // don't have to be extremely
                                    // precise to play in the corners
    board_top := board.transform.position.y + board.height

    top_left: [3]f32     = { board.transform.position.x - half_scaled.x, board_top, board.transform.position.z - half_scaled.y }
    bottom_left: [3]f32  = { board.transform.position.x - half_scaled.x, board_top, board.transform.position.z + half_scaled.y }
    bottom_right: [3]f32 = { board.transform.position.x + half_scaled.x, board_top, board.transform.position.z + half_scaled.y }
    top_right: [3]f32    = { board.transform.position.x + half_scaled.x, board_top, board.transform.position.z - half_scaled.y }

    collision := rl.GetRayCollisionQuad(ray, top_left, bottom_left, bottom_right, top_right)

    if !collision.hit {
        return
    }

    tile_offset := board.play_area / f32(board.board.size - 1)

    x := (collision.point.x + half_area.x - board.transform.position.x) / tile_offset.x
    y := (collision.point.z + half_area.y - board.transform.position.z) / tile_offset.y

    rx := u32(math.round(x))
    ry := u32(math.round(y))

    return {rx, ry}, true, click
}

input_get_movement_vector :: proc () -> (movement_vector: [3]f32) {
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

    return linalg.normalize(movement_vector)
}

input_should_toggle_sit :: proc () -> bool {
    return rl.IsKeyPressed(.M)
}
