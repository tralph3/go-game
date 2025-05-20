package gltf

import "core:os/os2"
import "core:io"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:encoding/json"

GLTF_HEADER_SIZE :: 12
GLTF_MAGIC_NUMBER :: 0x46546C67
GLTF_JSON_CHUNK :: 0x4E4F534A
GLTF_VERSION :: 2

GeneralError :: enum {
    None = 0,
    NodeNotFoundError,
}

ModelNodes :: struct {
    nodes: []struct {
        mesh: int,
        name: string,
        translation: [3]f32,
    },
}

ReadError :: union {
    os2.Error,
    io.Error,
    HeaderReadError,
    EmptyChunkError,
    UnknownChunkTypeError,
    json.Unmarshal_Error,
}

HeaderReadError :: union {
    UnknownMagicNumberError,
    UnknownFileVersionError,
    EmptyFileError,
}

UnknownMagicNumberError :: struct{}
UnknownFileVersionError :: struct{}
EmptyFileError :: struct{}
EmptyChunkError :: struct{}
UnknownChunkTypeError :: struct{}

check_file_header :: proc (file: ^os2.File) -> HeaderReadError {
    header_buf := make([]byte, GLTF_HEADER_SIZE)
    defer delete(header_buf)

    _, read_err := io.read_at_least(file.stream, header_buf, GLTF_HEADER_SIZE)

    magic: u32le
    mem.copy_non_overlapping(&magic, slice.as_ptr(header_buf), 4)
    if magic != GLTF_MAGIC_NUMBER {
        return UnknownMagicNumberError{}
    }

    version: u32le
    mem.copy_non_overlapping(&version, slice.as_ptr(header_buf[4:]), 4)
    if version != GLTF_VERSION {
        return UnknownFileVersionError{}
    }

    size: u32le
    mem.copy_non_overlapping(&size, slice.as_ptr(header_buf[8:]), 4)
    if size == 0 {
        return EmptyFileError{}
    }

    return nil
}

get_model_nodes :: proc (file_path: string) -> (nodes: ModelNodes, err: ReadError) {
    file := os2.open(file_path) or_return
    defer os2.close(file)

    check_file_header(file) or_return

    json_chunk_buf := make([]byte, 8)
    defer delete(json_chunk_buf)

    io.read_at_least(file.stream, json_chunk_buf, 8) or_return

    chunk_length: u32le
    mem.copy_non_overlapping(&chunk_length, slice.as_ptr(json_chunk_buf), 4)
    if chunk_length == 0 {
        return nodes, EmptyChunkError{}
    }

    chunk_type: u32le
    mem.copy_non_overlapping(&chunk_type, slice.as_ptr(json_chunk_buf[4:]), 4)
    if chunk_type != GLTF_JSON_CHUNK {
        return nodes, UnknownChunkTypeError{}
    }

    json_data_buf := make([]byte, chunk_length)
    defer delete(json_data_buf)

    io.read_at_least(file.stream, json_data_buf, int(chunk_length)) or_return

    json.unmarshal(json_data_buf, &nodes) or_return

    return nodes, nil
}

get_node_translation :: proc (nodes: ^ModelNodes, node_name: string) -> ([3]f32, GeneralError) {
    for node in nodes.nodes {
        if node.name == node_name {
            return node.translation, nil
        }
    }

    return {}, .NodeNotFoundError
}

get_node_id :: proc (nodes: ^ModelNodes, node_name: string) -> (int, GeneralError) {
    for node in nodes.nodes {
        if node.name == node_name {
            return node.mesh, nil
        }
    }

    return {}, .NodeNotFoundError
}

delete_model_nodes :: proc (nodes: ^ModelNodes) {
    for node in nodes.nodes {
        delete(node.name)
    }

    delete(nodes.nodes)
}
