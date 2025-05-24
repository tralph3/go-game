package main

import rl "vendor:raylib"
import "core:log"

WorldTransform :: struct {
    position: [3]f32,
    rotation_deg: f32,
    rotation_axis: [3]f32,
}

WorldObject :: struct {
    transform: WorldTransform,
    model: ^rl.Model,
}

world_init :: proc () {
    log.info("Initializing world objects...")

    append(&GLOBAL_STATE.objects, WorldObject{
        model = &GLOBAL_STATE.assets.models[ModelID.ROOM]
    })

    append(&GLOBAL_STATE.objects, WorldObject{
        model = &GLOBAL_STATE.assets.models[ModelID.BOARD]
    })
}
