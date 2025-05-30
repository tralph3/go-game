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
    height: f32,
    play_area: [2]f32,
    hovered_coord: [2]i32,
}

RoomWorldObject :: struct {
    using object: WorldObject,
}

world_init :: proc () -> (ok: bool) {
    log.info("Initializing world objects...")

    GLOBAL_STATE.room_object = RoomWorldObject{
        model = &GLOBAL_STATE.assets.models[ModelID.ROOM],
    }

    controller := board_controller_new(19, {}) or_return

    append(&GLOBAL_STATE.board_controllers, controller)

    ok = true
    return
}

world_board_world_object_new :: proc () -> (board_world_object: ^BoardWorldObject, ok: bool) {
    board_world_object = new(BoardWorldObject)
    board_world_object.model = &GLOBAL_STATE.assets.models[.BOARD]
    board_world_object.hovered_coord = { -1, -1 }

    nodes, err_model_nodes := gltf.get_model_nodes(string(ModelPaths[.BOARD]))
    if err_model_nodes != nil {
        log.errorf("Failed reading model nodes: %s", err_model_nodes)
        return
    }
    defer gltf.delete_model_nodes(&nodes)

    node_id := gltf.get_node_id(&nodes, "PlayArea") or_return
    board_size := gltf.get_node_extra(&nodes, node_id, "Size").(json.Integer) or_return

    box := rl.GetMeshBoundingBox(GLOBAL_STATE.assets.models[.BOARD].meshes[node_id])

    board_world_object.play_area = box.max.xz - box.min.xz
    board_world_object.height = box.max.y

    ok = true
    return
}

world_board_world_object_free :: proc (board_world_object: ^BoardWorldObject) {
    free(board_world_object)
}
