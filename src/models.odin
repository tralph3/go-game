package main

import rl "vendor:raylib"
import "gltf"

model_load_with_shader :: proc (shader: ^rl.Shader, model_path: cstring) -> rl.Model {
    model := rl.LoadModel(model_path)

    for i in 0..<model.materialCount {
        model.materials[i].shader = shader^
    }

    return model
}

model_load_with_shader_and_nodes :: proc (shader: ^rl.Shader, model_path: cstring) -> (rl.Model, gltf.ModelNodes, gltf.ReadError) {
    model := model_load_with_shader(shader, model_path)

    nodes, read_error := gltf.get_model_nodes(string(model_path))
    if read_error != nil {
        rl.UnloadModel(model)
        return model, nodes, read_error
    }

    return model, nodes, nil
}
