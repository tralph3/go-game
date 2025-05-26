package main

import rl "vendor:raylib"
import "core:log"

Assets :: struct {
    models: [ModelID]rl.Model,
    sounds: [SoundID]rl.Sound,
    shaders: [ShaderID]rl.Shader,
}

ModelID :: enum {
    ROOM,
    BOARD,
    WHITE_STONE,
    BLACK_STONE,
    CLIPBOARD,
}

SoundID :: enum {
    STONE_PLACE_1,
    STONE_PLACE_2,
    STONE_PLACE_LAST,
}

ShaderID :: enum {
    LIGHTING,
}

ModelPaths :: [ModelID]cstring {
        .ROOM = "./assets/models/room.glb",
        .BOARD = "./assets/models/board.glb",
        .WHITE_STONE = "./assets/models/white_stone.glb",
        .BLACK_STONE = "./assets/models/black_stone.glb",
        .CLIPBOARD = "./assets/models/clipboard.glb",
}

SoundPaths :: [SoundID]cstring {
        .STONE_PLACE_1 = "./assets/sounds/stone_place_1.ogg",
        .STONE_PLACE_2 = "./assets/sounds/stone_place_2.ogg",
        .STONE_PLACE_LAST = "./assets/sounds/stone_place_3.ogg",
}

ShaderPaths :: [ShaderID][2]cstring {
        .LIGHTING = { "./assets/shaders/lighting.vert", "./assets/shaders/lighting.frag" },
}

assets_load_all :: proc () -> (ok: bool) {
    log.info("Loading assets...")

    assets_load_models() or_return
    assets_load_sounds() or_return
    assets_load_shaders() or_return

    return true
}

assets_unload_all :: proc () {
    log.info("Unloading assets...")

    assets_unload_models()
    assets_unload_sounds()
    assets_unload_shaders()
}

@(private="file")
assets_load_models :: proc () -> (ok: bool) {
    log.info("Loading models...")

    for path, model_id in ModelPaths {
        GLOBAL_STATE.assets.models[model_id] = rl.LoadModel(path)
        if !rl.IsModelValid(GLOBAL_STATE.assets.models[model_id]) {
            log.errorf("Failed loading model: '%s'", path)
            return false
        }
    }

    return true
}

@(private="file")
assets_load_sounds :: proc () -> (ok: bool) {
    log.info("Loading sounds...")

    for path, sound_id in SoundPaths {
        GLOBAL_STATE.assets.sounds[sound_id] = rl.LoadSound(path)
        if !rl.IsSoundValid(GLOBAL_STATE.assets.sounds[sound_id]) {
            log.errorf("Failed loading sound: '%s'", path)
            return false
        }
    }

    return true
}

@(private="file")
assets_load_shaders :: proc () -> (ok: bool) {
    log.info("Loading shaders...")

    for paths, shader_id in ShaderPaths {
        GLOBAL_STATE.assets.shaders[shader_id] = rl.LoadShader(paths[0], paths[1])
        // TODO: `IsShaderValid` seems to always return true
        if !rl.IsShaderValid(GLOBAL_STATE.assets.shaders[shader_id]) {
            log.errorf("Failed loading shader: '%s' | '%s'", paths[0], paths[1])
            return false
        }
    }

    return true
}

@(private="file")
assets_unload_models :: proc () {
    for model in GLOBAL_STATE.assets.models {
        rl.UnloadModel(model)
    }
}

@(private="file")
assets_unload_sounds :: proc () {
    for sound in GLOBAL_STATE.assets.sounds {
        rl.UnloadSound(sound)
    }
}

@(private="file")
assets_unload_shaders :: proc () {
    for shader in GLOBAL_STATE.assets.shaders {
        rl.UnloadShader(shader)
    }
}
