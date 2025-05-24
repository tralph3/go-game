package main

import rl "vendor:raylib"
import "gltf"
import "core:log"

models_init :: proc () {
    log.info("Initializing models...")

    models_apply_shader()
}

models_apply_shader :: proc () {
    shader := &GLOBAL_STATE.assets.shaders[ShaderID.VISUAL]

    for model in GLOBAL_STATE.assets.models {
        for material_id in 0..<model.materialCount {
            model.materials[material_id].shader = shader^
        }
    }
}

// model_load_with_shader_and_nodes :: proc (shader: ^rl.Shader, model_path: cstring) -> (rl.Model, gltf.ModelNodes, gltf.ReadError) {
//     model := model_load_with_shader(shader, model_path)

//     nodes, read_error := gltf.get_model_nodes(string(model_path))
//     if read_error != nil {
//         rl.UnloadModel(model)
//         return model, nodes, read_error
//     }

//     return model, nodes, nil
// }
