package main

import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "core:mem"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:c"
import "core:thread"
import "core:time"

import "gltf"

Mode :: enum {
    FreeRoam,
    Playing,
}

RECTANGLE_SIZE :: 60
GAP_SIZE :: 3

tile_offset: [2]f32

ai_thread: ^thread.Thread = nil

ai_play :: proc (board: ^Board) {
    ai_move := run_mcts_ai(board, 10)
    board_set(board, ai_move.x, ai_move.y)
}

frame_delta: f32 = 0.0

main :: proc () {


    rl.SetTraceLogLevel(.NONE)
    rl.SetConfigFlags({ .MSAA_4X_HINT })

    rl.InitWindow(800, 600, "Go")
    defer rl.CloseWindow()

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    player := player_new({ -1.0, 0.0 }, 1.4, 1)

    board, _ := board_new(19)
    defer board_delete(&board)

    board_object := BoardObject {
        board = board,
        position = { 0.0, 0.0, 0.0 },
    }

    shader := shaders_load()
    defer rl.UnloadShader(shader)

    shaders_configure(&shader, &{ 0.0, 0.0, 0.0, 1.0 })

    board_model, board_nodes, _ := model_load_with_shader_and_nodes(&shader, "./assets/models/board.glb")
    defer rl.UnloadModel(board_model)
    defer gltf.delete_model_nodes(&board_nodes)

    board_grid_mesh_id, _ := gltf.get_node_id(&board_nodes, "PlayArea")
    board_grid_bounding_box := rl.GetMeshBoundingBox(board_model.meshes[board_grid_mesh_id])

    board_object.grid_size = board_grid_bounding_box.max.xz - board_grid_bounding_box.min.xz
    board_object.height = board_grid_bounding_box.max.y

    tile_offset = { board_object.grid_size.x / f32(board_object.board.size - 1), board_object.grid_size.y / f32(board_object.board.size - 1) }

    white_stone_model := model_load_with_shader(&shader, "./assets/models/white_stone.glb")
    defer rl.UnloadModel(white_stone_model)

    black_stone_model := model_load_with_shader(&shader, "./assets/models/black_stone.glb")
    defer rl.UnloadModel(black_stone_model)

    room_model := model_load_with_shader(&shader, "./assets/models/room.glb")
    defer rl.UnloadModel(room_model)

    stone_sounds: []rl.Sound = {
        rl.LoadSound("./assets/sounds/stone1.ogg"),
        rl.LoadSound("./assets/sounds/stone2.ogg"),
        rl.LoadSound("./assets/sounds/stone3.ogg"),
    }

    for !rl.WindowShouldClose() {
        frame_delta = rl.GetFrameTime()

        rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "viewPos"), &player.camera.position, .VEC3)

        input_process(&player, &board_object)

        render_world(&player, &board_object, room_model, board_model, white_stone_model, black_stone_model)
    }

    for sound in stone_sounds {
        rl.UnloadSound(sound)
    }
}
