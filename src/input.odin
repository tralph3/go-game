package main

import rl "vendor:raylib"
import "core:math"
import "core:math/linalg"

input_get_clicked_controller :: proc () -> ^BoardController {
    if !rl.IsMouseButtonPressed(.LEFT) {
        return nil
    }

    click: [2]f32 = { f32(rl.GetScreenWidth()) / 2.0, f32(rl.GetScreenHeight()) / 2.0 }
    ray := rl.GetScreenToWorldRay(click, GLOBAL_STATE.player.camera)

    for controller in GLOBAL_STATE.board_controllers {
        box := rl.GetModelBoundingBox(controller.object.model^)
        box.min += controller.object.transform.position
        box.max += controller.object.transform.position

        if rl.GetRayCollisionBox(ray, box).hit {
            return controller
        }
    }

    return nil
}

input_get_board_coord :: proc (controller: ^BoardController) -> (coord: [2]u32, hit, click: bool) {
    click = rl.IsMouseButtonPressed(.LEFT)

    ray := rl.GetScreenToWorldRay(
        rl.GetMousePosition(), GLOBAL_STATE.player.camera)

    half_area := controller.object.play_area / 2
    half_scaled := half_area * 1.05 // give a bit of margin so you
                                    // don't have to be extremely
                                    // precise to play in the corners
    board_top := controller.object.transform.position.y + controller.object.height

    top_left: [3]f32     = { controller.object.transform.position.x - half_scaled.x, board_top, controller.object.transform.position.z - half_scaled.y }
    bottom_left: [3]f32  = { controller.object.transform.position.x - half_scaled.x, board_top, controller.object.transform.position.z + half_scaled.y }
    bottom_right: [3]f32 = { controller.object.transform.position.x + half_scaled.x, board_top, controller.object.transform.position.z + half_scaled.y }
    top_right: [3]f32    = { controller.object.transform.position.x + half_scaled.x, board_top, controller.object.transform.position.z - half_scaled.y }

    collision := rl.GetRayCollisionQuad(ray, top_left, bottom_left, bottom_right, top_right)

    if !collision.hit {
        return
    }

    tile_offset := controller.object.play_area / f32(controller.board.size - 1)

    x := (collision.point.x + half_area.x - controller.object.transform.position.x) / tile_offset.x
    y := (collision.point.z + half_area.y - controller.object.transform.position.z) / tile_offset.y

    rx := u32(math.round(x))
    ry := u32(math.round(y))

    return { rx, ry }, true, click
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

    if movement_vector == { 0, 0, 0 } {
        return
    }

    return linalg.normalize(movement_vector)
}

input_should_toggle_sit :: proc () -> bool {
    return rl.IsKeyPressed(.M)
}

input_should_open_menu :: proc () -> bool {
    return rl.IsKeyPressed(.ESCAPE)
}
