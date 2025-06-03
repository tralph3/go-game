package sgf

import "core:os/os2"
import "core:strings"
import "core:slice"
import "core:mem"
import "core:fmt"

Node :: map[string][dynamic]string

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

    contents_str := strings.string_from_ptr(raw_data(contents), len(contents))

    return parse_from_str(contents_str)
}

parse_from_str :: proc (contents: string) -> (tree: Tree, err: Error) {
    start_idx := strings.index(contents, "(")
    contents_slice := slice.from_ptr(raw_data(contents), len(contents))

    tree, _, err = tree_parse(contents_slice[start_idx + 1:])
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

    last_identifier: string = ""

    for {
        if index >= len(contents) {
            err = .UnexpectedEOF
            return
        }

        char := contents[index]
        defer index += 1

        if char == '[' {
            key: string
            if len(identifier) == 0 {
                if last_identifier == "" {
                    err = .UnexpectedToken
                    return
                }

                key = strings.clone(last_identifier)
            } else {
                key = strings.clone_from_ptr(raw_data(identifier), len(identifier)) or_return
            }

            val, end_index, parse_error := value_parse(contents[index + 1:])
            if parse_error != nil {
                delete(key)
            }

            index += end_index + 1

            key_ptr, _, just_inserted := map_entry(&node, key) or_return

            defer if !just_inserted {
                // key was already present, so we would leak memory if
                // we don't free the repeats. this should
                // theoretically never happen since, according to the
                // spec, you can only have one of each property per
                // node, but OGS stores labels this way, so i must
                // support it...
                delete(key)
            }

            append(&node[key], val) or_return

            last_identifier = key_ptr^

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

tree_to_file :: proc (tree: ^Tree, path: string) -> (err: Error) {
    str := tree_to_sgf(tree) or_return
    defer delete(str)

    os2.write_entire_file(path, slice.from_ptr(raw_data(str), len(str))) or_return

    return
}

tree_to_sgf :: proc (tree: ^Tree) -> (str: string, err: mem.Allocator_Error) {
    res: [dynamic]byte
    defer if err != nil {
        delete(res)
    }

    append(&res, '(') or_return

    for node in tree.nodes {
        append(&res, ';') or_return

        for key, vals in node {
            append(&res, ..slice.from_ptr(raw_data(key), len(key))) or_return

            for val in vals {
                append(&res, '[') or_return
                append(&res, ..slice.from_ptr(raw_data(val), len(val))) or_return
                append(&res, ']') or_return
            }
        }
        append(&res, '\n') or_return
    }

    for &child in tree.children {
        child_str := tree_to_sgf(&child) or_return
        append(&res, ..slice.from_ptr(raw_data(child_str), len(child_str))) or_return
        delete(child_str)
    }

    if res[len(res) - 1] == '\n' {
        res[len(res) - 1] = ')'
    } else {
        append(&res, ')') or_return
    }

    append(&res, '\n') or_return

    return strings.string_from_ptr(raw_data(res), len(res)), nil
}

node_delete :: proc (node: ^Node) {
    for key, vals in node {
        for val in vals {
            delete(val)
        }

        delete(key)
        delete(vals)
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
