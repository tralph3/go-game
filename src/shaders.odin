package main

import rl "vendor:raylib"
import "core:log"

shaders_init :: proc () {
    log.info("Initializing shaders...")

    shader := &GLOBAL_STATE.assets.shaders[.LIGHTING]

    rl.SetShaderValue(
        shader^, rl.GetShaderLocation(shader^, "ambient"), &[4]f32{ 0.6, 0.6, 0.6, 1.0 }, .VEC4)

    shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] = rl.GetShaderLocation(shader^, "normalMap")
    shader.locs[rl.ShaderLocationIndex.MAP_ALBEDO] = rl.GetShaderLocation(shader^, "texture0")
}

shaders_update :: proc () {
    rl.SetShaderValue(
        GLOBAL_STATE.assets.shaders[.LIGHTING],
        rl.GetShaderLocation(GLOBAL_STATE.assets.shaders[.LIGHTING], "viewPos"),
        &GLOBAL_STATE.player.camera.position,
        .VEC3,
    )
}
