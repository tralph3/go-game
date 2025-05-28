package main

import rl "vendor:raylib"
import "core:math"
import "core:math/linalg"
import "core:log"
import "core:fmt"

PlayerMoveCallback :: proc ()
PlayerInteractCallback :: proc ()
PlayerCameraCallback :: proc ()

PlayerStateCallbacks :: struct {
    move: PlayerMoveCallback,
    interact: PlayerInteractCallback,
    camera: PlayerCameraCallback,
}

PlayerState :: enum {
    ROAMING,
    PLAYING,
    MENU,
}

Player :: struct {
    camera: rl.Camera,          // doubles as player position
    speed: f32,
    max_speed: f32,
    height: f32,
    sitting_height: f32,
    direction: [3]f32,
    callbacks: [PlayerState]PlayerStateCallbacks,
    state: PlayerState,
    current_board: ^BoardWorldObject,
}

player_init :: proc (start_pos: [2]f32, speed, height: f32) {
    log.info("Initializing player...")

    player := Player {
        camera = rl.Camera {
            position = { start_pos.x, height, start_pos.y },
            up = { 0.0, 1.0, 0.0 },
            fovy = 90.0,
            projection = .PERSPECTIVE,
        },
        speed = 0,
        max_speed = speed,
        height = height,
        state = .ROAMING,
    }

    player.callbacks[.ROAMING].move = player_move_roaming
    player.callbacks[.PLAYING].move = player_move_null
    player.callbacks[.MENU].move = player_move_null

    player.callbacks[.ROAMING].interact = player_interact_roaming
    player.callbacks[.PLAYING].interact = player_interact_playing
    player.callbacks[.MENU].interact = player_interact_null

    player.callbacks[.ROAMING].camera = player_camera_roaming
    player.callbacks[.PLAYING].camera = player_camera_playing
    player.callbacks[.MENU].camera = player_interact_null

    player.current_board = &GLOBAL_STATE.board_objects[0]

    GLOBAL_STATE.player = player
}

player_update :: proc () {
    player := &GLOBAL_STATE.player

    player.callbacks[player.state].move()
    player.callbacks[player.state].interact()
    player.callbacks[player.state].camera()
}

player_move_roaming :: proc () {
    direction := input_get_movement_vector()

    player := &GLOBAL_STATE.player

    if direction.x != 0 || direction.y != 0 {
        player.speed = linalg.lerp(player.speed, player.max_speed, 1 - math.pow(0.0001, rl.GetFrameTime()))
        player.direction = direction
    } else {
        player.speed = linalg.lerp(player.speed, 0, 1 - math.pow(0.0001, rl.GetFrameTime()))
    }

    velocity := player.direction * player.speed * rl.GetFrameTime()

    look_delta := rl.GetMouseDelta() * 0.2

    rl.UpdateCameraPro(&player.camera, velocity, { look_delta.x, look_delta.y, 0 }, 0)
}

player_interact_playing :: proc () {
    if input_should_toggle_sit() {
        player_change_state_roaming()
        return
    }

    player := &GLOBAL_STATE.player

    coord, hit := input_get_clicked_board_coord(player.current_board)
    if !hit {
        return
    }

    if err := board_set(player.current_board.board, coord.x, coord.y); err != nil {
        return
    }

    sound_play_random(.STONE_PLACE_1, .STONE_PLACE_LAST)
}

player_interact_roaming :: proc () {
    if input_should_toggle_sit() {
        player_change_state_playing()
        return
    }
}

player_move_null :: proc () {
    // this function does nothing
}

player_interact_null :: proc () {
    // this function does nothing
}

player_camera_roaming :: proc () {
    player := &GLOBAL_STATE.player

    player.camera.position.y = linalg.lerp(player.camera.position.y, player.height, 1 - math.pow(0.0001, rl.GetFrameTime()))
    player.camera.fovy = linalg.lerp(player.camera.fovy, 90.0, 1 - math.pow(0.0001, rl.GetFrameTime()))
}

player_camera_playing :: proc () {
    player := &GLOBAL_STATE.player
    board := player.current_board

    board_pos := board.transform.position

    min_height := board.height + 0.3
    max_height := board.height + 0.9

    player.sitting_height += rl.GetMouseWheelMove() * 0.1
    player.sitting_height = clamp(player.sitting_height, min_height, max_height)

    board_top_y := board_pos.y + board.height

    target := board_pos
    target.y = board_top_y

    position_offset := [3]f32{ 0, player.sitting_height, 1.25 - player.sitting_height }

    desired_pos := board_pos + position_offset

    smoothing := 1 - math.pow(0.01, rl.GetFrameTime())
    player.camera.target = linalg.lerp(player.camera.target, target, smoothing)
    player.camera.position = linalg.lerp(player.camera.position, desired_pos, smoothing)
    player.camera.fovy = linalg.lerp(player.camera.fovy, 40.0, smoothing)
}


player_change_state_playing :: proc () {
    player := &GLOBAL_STATE.player

    rl.EnableCursor()

    player.state = .PLAYING
    player.speed = 0
}

player_change_state_roaming :: proc () {
    player := &GLOBAL_STATE.player

    rl.DisableCursor()

    player.state = .ROAMING
    player.speed = 0
}
