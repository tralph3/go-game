package main

import rl "vendor:raylib"

shaders_load :: proc () -> rl.Shader {
    shader := rl.LoadShader("./assets/shaders/visual.vert", "./assets/shaders/visual.frag")

    return shader
}

shaders_configure :: proc (shader: ^rl.Shader, ambient_color: ^[4]f32) {
    rl.SetShaderValue(shader^, rl.GetShaderLocation(shader^, "ambient"), ambient_color, .VEC4)

    shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] = rl.GetShaderLocation(shader^, "normalMap")
    shader.locs[rl.ShaderLocationIndex.MAP_ALBEDO] = rl.GetShaderLocation(shader^, "texture0")
}
