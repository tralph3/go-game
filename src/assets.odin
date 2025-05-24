package main

import rl "vendor:raylib"
import "core:log"

Assets :: struct {
    models: []rl.Model,
    sounds: []rl.Sound,
    shaders: []rl.Shader,
}

ModelID :: enum {
    ROOM,
    BOARD,
    WHITE_STONE,
    BLACK_STONE,
    CLIPBOARD,
    LAST,
}

SoundID :: enum {
    STONE_PLACE_FIRST,
    STONE_PLACE_2,
    STONE_PLACE_LAST,
    LAST,
}

ShaderID :: enum {
    VISUAL,
    LAST,
}

assets_load_all :: proc () -> Assets {
    log.info("Loading assets...")

    assets: Assets

    assets.models  = assets_load_models()
    assets.sounds  = assets_load_sounds()
    assets.shaders = assets_load_shaders()

    return assets
}

assets_unload_all :: proc (assets: ^Assets) {
    log.info("Unloading assets...")

    assets_unload_models(assets)
    assets_unload_sounds(assets)
    assets_unload_shaders(assets)
}

@(private="file")
assets_load_models :: proc () -> []rl.Model {
    log.info("Loading models...")

    models := make([]rl.Model, ModelID.LAST)

    models[ModelID.ROOM] = rl.LoadModel("./assets/models/room.glb")
    models[ModelID.BOARD] = rl.LoadModel("./assets/models/board.glb")
    models[ModelID.WHITE_STONE] = rl.LoadModel("./assets/models/white_stone.glb")
    models[ModelID.BLACK_STONE] = rl.LoadModel("./assets/models/black_stone.glb")
    models[ModelID.CLIPBOARD] = rl.LoadModel("./assets/models/clipboard.glb")

    return models
}

@(private="file")
assets_load_sounds :: proc () -> []rl.Sound {
    log.info("Loading sounds...")

    sounds := make([]rl.Sound, SoundID.LAST)

    sounds[SoundID.STONE_PLACE_FIRST] = rl.LoadSound("./assets/sounds/stone_place_1.ogg")
    sounds[SoundID.STONE_PLACE_2] = rl.LoadSound("./assets/sounds/stone_place_2.ogg")
    sounds[SoundID.STONE_PLACE_LAST] = rl.LoadSound("./assets/sounds/stone_place_3.ogg")

    return sounds
}

@(private="file")
assets_load_shaders :: proc () -> []rl.Shader {
    log.info("Loading shaders...")

    shaders := make([]rl.Shader, ShaderID.LAST)

    shaders[ShaderID.VISUAL] = rl.LoadShader("./assets/shaders/visual.vert", "./assets/shaders/visual.frag")

    return shaders
}

@(private="file")
assets_unload_models :: proc (assets: ^Assets) {
    for model in assets.models {
        rl.UnloadModel(model)
    }

    delete(assets.models)
}

@(private="file")
assets_unload_sounds :: proc (assets: ^Assets) {
    for sound in assets.sounds {
        rl.UnloadSound(sound)
    }

    delete(assets.sounds)
}

@(private="file")
assets_unload_shaders :: proc (assets: ^Assets) {
    for shader in assets.shaders {
        rl.UnloadShader(shader)
    }

    delete(assets.shaders)
}
