package main

import rl "vendor:raylib"
import "core:math/linalg"

Player :: struct {
    camera: rl.Camera,
    speed: f32,
    max_speed: f32,
    height: f32,
    sitting: bool,
    sitting_height: f32,
    direction: [3]f32,
}

player_new :: proc (start_pos: [2]f32, speed, height: f32) -> Player {
    player := Player {
        camera = rl.Camera {
            position = { start_pos.x, height, start_pos.y },
            up = { 0.0, 1.0, 0.0 },
            fovy = 90.0,
            projection = .PERSPECTIVE,
        },
        sitting_height = 0.7,
        speed = 0,
        max_speed = speed,
        height = height,
        sitting = true,
    }

    return player
}

player_move :: proc (player: ^Player, direction: [3]f32, look_delta: [2]f32) {
    if player.sitting {
        return
    }

    if direction.x != 0 || direction.y != 0 {
        player.speed = rl.Lerp(player.speed, player.max_speed, 0.01)
        player.direction = direction
    } else {
        player.speed = rl.Lerp(player.speed, 0, 0.01)
    }

    velocity := player.direction * player.speed * frame_delta

    rl.UpdateCameraPro(&player.camera, velocity, { look_delta.x, look_delta.y, 0.0 }, 0)
}

player_update_camera_position :: proc (player: ^Player, direction: f32, sit_position: [2]f32, board_position: [3]f32) {
    if !player.sitting {
        player.camera.position.y = rl.Lerp(player.camera.position.y, player.height, 0.01)
        player.camera.fovy = rl.Lerp(player.camera.fovy, 90.0, 0.01)
        return
    }

    player.camera.fovy = linalg.lerp(player.camera.fovy, 40.0, 0.005)
    player.camera.target = linalg.lerp(player.camera.target, board_position, 0.005)

    player.sitting_height += direction * 0.1
    player.sitting_height = clamp(player.sitting_height, 0.5, 1.2)


    player.camera.position = linalg.lerp(player.camera.position, [3]f32{ 0.0, player.sitting_height, 1.25 - player.sitting_height }, 0.005)
}

player_toggle_sit :: proc (player: ^Player) {
    if player.sitting {
        rl.DisableCursor()
    } else {
        rl.EnableCursor()
    }

    player.speed = 0
    player.sitting = !player.sitting
}
