package sgf

import "core:os/os2"
import "core:strings"
import "core:mem"
import "core:fmt"

Node :: map[string]string

Tree :: struct {
    nodes: [dynamic]Node,
    children: [dynamic]Tree,
}

Error :: union {
    ParseError,
    mem.Allocator_Error,
    os2.Error,
}

ParseError :: enum {
    UnexpectedToken,
    UnexpectedEOF,
}

parse_from_file :: proc (path: string) -> (tree: Tree, err: Error) {
    contents := os2.read_entire_file_from_path(path, context.allocator) or_return
    defer delete(contents)

    tree, _, err = tree_parse(contents)
    if err != nil {
        tree_delete(tree)
    }

    return
}

tree_parse :: proc (contents: []byte) -> (tree: Tree, end_index: int, err: Error) {
    index := 0

    for {
        if index >= len(contents) { break }

        char := contents[index]
        defer index += 1

        if strings.is_space(rune(char)) { continue }
        if char == ')' { break }

        if char == '(' {
            child, end_index, parse_error := tree_parse(contents[index + 1:])
            err = parse_error
            append(&tree.children, child)
            if err != nil { return }

            index += end_index + 1
        } else if char == ';' {
            node, end_index, parse_error := node_parse(contents[index + 1:])
            err = parse_error
            append(&tree.nodes, node)
            if err != nil { return }

            index += end_index + 1
        }
    }

    // due to the defer incrementing the index when leaving the loop,
    // the index must be subtracted for it to be accurate
    return tree, index - 1, nil
}

node_parse :: proc (contents: []byte) -> (node: Node, end_index: int, err: Error) {
    index := 0

    // spec: identifiers can't be greater than two characters
    identifier := make([dynamic]byte, 2)
    clear(&identifier)
    defer delete(identifier)

    defer if err != nil {
        node_delete(&node)
    }

    for {
        if index >= len(contents) {
            err = .UnexpectedEOF
            return
        }

        char := contents[index]
        defer index += 1

        if char == '[' {
            if len(identifier) == 0 {
                err = .UnexpectedToken
                return
            }

            key := strings.clone_from_ptr(raw_data(identifier), len(identifier)) or_return
            val, end_index, parse_error := value_parse(contents[index + 1:])
            if parse_error != nil {
                delete(key)
            }

            index += end_index + 1

            map_insert(&node, key, val)

            clear(&identifier)
        } else if (char >= 'A' && char <= 'Z') && len(identifier) < 2 {
            append(&identifier, char)
        } else if char == ';' || char == '(' || char == ')' {
            break
        } else if strings.is_space(rune(char)) {
            continue
        } else {
            err = .UnexpectedToken
            return
        }
    }

    // nodes don't have a terminator character, it stops when it
    // encounters the token for the next item, thus two indeces should
    // be subtracted instead of the usual one
    return node, index - 2, nil
}

value_parse :: proc (contents: []byte) -> (val: string, end_index: int, err: Error) {
    index := 0

    result := make([dynamic]byte, 8)
    clear(&result)
    defer delete(result)

    for {
        if index >= len(contents) {
            err = .UnexpectedEOF
            return
        }

        char := contents[index]
        defer index += 1

        if char == ']' && (index == 0 || !is_escape_character(contents, index - 1)) {
            break
        } else if is_escape_character(contents, index) {
            continue
        } else if char == '\n' && index != 0 && is_escape_character(contents, index - 1) {
            continue
        }

        append(&result, char)
    }

    val = strings.clone_from_ptr(raw_data(result), len(result)) or_return

    // due to the defer incrementing the index when leaving the loop,
    // the index must be subtracted for it to be accurate
    return val, index - 1, nil
}

is_escape_character :: proc (contents: []byte, pos: int) -> bool {
    char := contents[pos]
    if char != '\\' { return false }
    if pos == 0 { return true }

    escape_char_count := 0
    for i := pos - 1; i >= 0; i -= 1 {
        if contents[i] == '\\' {
            escape_char_count += 1
        } else {
            break
        }
    }

    // if there is an odd amount of preceding escape chars, then the
    // one at the current pos is escaped, and doesn't count
    return escape_char_count % 2 == 0
}

node_delete :: proc (node: ^Node) {
    for key, val in node {
        delete(key)
        delete(val)
    }

    delete(node^)
}

tree_delete :: proc (tree: Tree) {
    for &node in tree.nodes {
        node_delete(&node)
    }

    for children in tree.children {
        tree_delete(children)
    }

    delete(tree.nodes)
    delete(tree.children)
}
