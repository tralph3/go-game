package main

import rl "vendor:raylib"
import "core:log"
import "core:fmt"

WorldTransform :: struct {
    position: [3]f32,
    rotation_deg: f32,
    rotation_axis: [3]f32,
}

WorldObject :: struct {
    transform: WorldTransform,
    model: ^rl.Model,
}

BoardWorldObject :: struct {
    using object: WorldObject,
    board: ^Board,
    height: f32,
    play_area: [2]f32,
}

RoomWorldObject :: struct {
    using object: WorldObject,
}

world_init :: proc (initial_board: ^Board) {
    log.info("Initializing world objects...")

    GLOBAL_STATE.room_object = RoomWorldObject{
        model = &GLOBAL_STATE.assets.models[ModelID.ROOM]
    }

    append(&GLOBAL_STATE.board_objects, BoardWorldObject{
        board = initial_board,
        height = 0.27,

        model = &GLOBAL_STATE.assets.models[ModelID.BOARD]
    })
}
