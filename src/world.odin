package main

import rl "vendor:raylib"
import "core:log"
import "gltf"
import "core:encoding/json"
import "core:math/rand"

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
    coord_offsets: [][2]f32,
}

RoomWorldObject :: struct {
    using object: WorldObject,
}

world_init :: proc () -> (ok: bool) {
    log.info("Initializing world objects...")

    GLOBAL_STATE.room_object = RoomWorldObject{
        model = &GLOBAL_STATE.assets.models[ModelID.ROOM],
    }

    controller := board_controller_new(19, {}, .LOCAL) or_return

    if _, err := append(&GLOBAL_STATE.board_controllers, controller); err != nil {
        return
    }

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

    world_generate_board_offsets(board_world_object, u32(board_size))

    ok = true
    return
}

world_board_world_object_free :: proc (board_world_object: ^BoardWorldObject) {
    delete(board_world_object.coord_offsets)
    free(board_world_object)
}

world_generate_board_offsets :: proc (board_world_object: ^BoardWorldObject, board_size: u32) {
    board_world_object.coord_offsets = make([][2]f32, board_size * board_size)
    tile_offset := board_world_object.play_area / f32(board_size - 1)

    for i in 0..<len(board_world_object.coord_offsets) {
        board_world_object.coord_offsets[i].x = (rand.float32() - 0.5) * tile_offset.x * 0.12
        board_world_object.coord_offsets[i].y = (rand.float32() - 0.5) * tile_offset.y * 0.12
    }
}
