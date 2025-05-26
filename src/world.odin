package main

import rl "vendor:raylib"
import "core:log"
import "core:fmt"
import "gltf"

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

world_init :: proc (initial_board: ^Board) -> (ok: bool) {
    log.info("Initializing world objects...")

    GLOBAL_STATE.room_object = RoomWorldObject{
        model = &GLOBAL_STATE.assets.models[ModelID.ROOM]
    }

    board := world_make_board_world_object(initial_board) or_return
    append(&GLOBAL_STATE.board_objects, board)

    return true
}

world_make_board_world_object :: proc (initial_board: ^Board) -> (board_world_object: BoardWorldObject, ok: bool) {
    board_world_object.model = &GLOBAL_STATE.assets.models[.BOARD]

    nodes, err := gltf.get_model_nodes(string(ModelPaths[.BOARD]))
    if err != nil {
        log.error("Failed reading model nodes")
        return {}, false
    }
    defer gltf.delete_model_nodes(&nodes)

    node_id := gltf.get_node_id(&nodes, "PlayArea") or_return

    box := rl.GetMeshBoundingBox(GLOBAL_STATE.assets.models[.BOARD].meshes[node_id])

    board_world_object.play_area = box.max.xz - box.min.xz
    board_world_object.height = box.max.y
    board_world_object.board = initial_board

    return board_world_object, true
}
