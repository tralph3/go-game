package main

import rl "vendor:raylib"
import "core:log"
import "core:fmt"
import "gltf"
import "core:encoding/json"

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

world_init :: proc () -> (ok: bool) {
    log.info("Initializing world objects...")

    GLOBAL_STATE.room_object = RoomWorldObject{
        model = &GLOBAL_STATE.assets.models[ModelID.ROOM]
    }

    board := world_make_board_world_object() or_return
    append(&GLOBAL_STATE.board_objects, board)

    return true
}

world_make_board_world_object :: proc () -> (board_world_object: BoardWorldObject, ok: bool) {
    board_world_object.model = &GLOBAL_STATE.assets.models[.BOARD]

    nodes, err_model_nodes := gltf.get_model_nodes(string(ModelPaths[.BOARD]))
    if err_model_nodes != nil {
        log.errorf("Failed reading model nodes: %s", err_model_nodes)
        return {}, false
    }
    defer gltf.delete_model_nodes(&nodes)

    node_id := gltf.get_node_id(&nodes, "PlayArea") or_return
    board_size := gltf.get_node_extra(&nodes, node_id, "Size").(json.Integer) or_return

    board, err_board_new := board_new(u32(board_size))
    if err_board_new != nil {
        log.errorf("Failed creating board: %s", err_board_new)
        return board_world_object, false
    }

    box := rl.GetMeshBoundingBox(GLOBAL_STATE.assets.models[.BOARD].meshes[node_id])

    board_world_object.play_area = box.max.xz - box.min.xz
    board_world_object.height = box.max.y
    board_world_object.board = board

    return board_world_object, true
}

world_delete_board_world_objects :: proc () {
    for board_world_object in GLOBAL_STATE.board_objects {
        board_delete(board_world_object.board)
    }
}
