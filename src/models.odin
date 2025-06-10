package main

import rl "vendor:raylib"
import "gltf"
import "core:log"

models_init :: proc () {
    log.info("Initializing models...")

    models_apply_shader()
    models_gen_mipmaps()
}

models_apply_shader :: proc () {
    shader := &GLOBAL_STATE.assets.shaders[.LIGHTING]

    for model in GLOBAL_STATE.assets.models {
        for material_id in 0..<model.materialCount {
            model.materials[material_id].shader = shader^
        }
    }
}

models_gen_mipmaps :: proc () {
    for model in GLOBAL_STATE.assets.models {
        for i in 0..<model.materialCount {
            rl.GenTextureMipmaps(&model.materials[i].maps[0].texture)
            rl.SetTextureFilter(model.materials[i].maps[0].texture, .TRILINEAR)
        }
    }
}
