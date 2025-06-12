package main

import rl "vendor:raylib"
import "core:c"
import "core:log"

Assets :: struct {
    models: [ModelID]rl.Model,
    sounds: [SoundID]rl.Sound,
    shaders: [ShaderID]rl.Shader,
    fonts: [FontID]rl.Font,
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

FontID :: enum {
    TITLE,
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

FontPaths :: [FontID]struct { path: cstring, size: c.int } {
        .TITLE = { "./assets/fonts/PierceRoman.otf", 32 },
}

assets_load_all :: proc () -> (ok: bool) {
    log.info("Loading assets...")

    assets_load_models() or_return
    assets_load_sounds() or_return
    assets_load_shaders() or_return
    assets_load_fonts() or_return

    return true
}

assets_unload_all :: proc () {
    log.info("Unloading assets...")

    assets_unload_models()
    assets_unload_sounds()
    assets_unload_shaders()
    assets_unload_fonts()
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
assets_load_fonts :: proc () -> (ok: bool) {
    log.info("Loading fonts...")

    for load_info, font_id in FontPaths {
        GLOBAL_STATE.assets.fonts[font_id] = rl.LoadFontEx(load_info.path, load_info.size, nil, 0)
        if !rl.IsFontValid(GLOBAL_STATE.assets.fonts[font_id]) {
            log.errorf("Failed loading font: '%s'", load_info.path)
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

@(private="file")
assets_unload_fonts :: proc () {
    for font in GLOBAL_STATE.assets.fonts {
        rl.UnloadFont(font)
    }
}
