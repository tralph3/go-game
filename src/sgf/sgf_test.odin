package sgf

import "core:testing"
import "core:os"
import "core:strings"
import "core:slice"
import "core:mem"
import "core:fmt"

SGF_SAMPLE_SIMPLE :: "(;FF[4]GM[1]SZ[19])"
SGF_SAMPLE_WITH_CHILD :: "(;FF[4]GM[1];B[aa];W[bb](;B[cc])(;B[dd]))"
SGF_SAMPLE_INVALID_TOKEN :: ";FF[4]GM[1]SZ[19]@)"
SGF_SAMPLE_UNEXPECTED_EOF :: ";FF[4]GM[1]SZ[19]"
SGF_SAMPLE_COMPLEX_COMMENT :: `;C[Meijin NR: yeah, k4 is won\
derful
sweat NR: thank you! :\)
dada NR: yup. I like this move too. It's a move only to be expected from a pro. I really like it :)
jansteen 4d: Can anyone\
 explain [me\] k4?])`

to_byte_array :: proc (str: string) -> []byte {
    return slice.from_ptr(raw_data(str), len(str))
}

@(test)
parse_simple_tree_test :: proc(t: ^testing.T) {
    tree, err := parse_from_str(SGF_SAMPLE_SIMPLE)
    defer tree_delete(tree)

    testing.expect_value(t, err, nil)
    testing.expectf(t, len(tree.nodes) == 1, "Expected 1 root node, got %d", len(tree.nodes))

    testing.expect_value(t, tree.nodes[0]["FF"][0], "4")
    testing.expect_value(t, tree.nodes[0]["GM"][0], "1")
    testing.expect_value(t, tree.nodes[0]["SZ"][0], "19")
}

@(test)
parse_tree_with_children_test :: proc(t: ^testing.T) {
    tree, err := parse_from_str(SGF_SAMPLE_WITH_CHILD)
    defer tree_delete(tree)

    testing.expect_value(t, err, nil)
    testing.expectf(t, len(tree.nodes) == 3, "Expected 3 root-level nodes (FF, GM and moves), got %d", len(tree.nodes))
    testing.expectf(t, len(tree.children) == 2, "Expected 2 child variations, got %d", len(tree.children))

    child1 := tree.children[0]
    child2 := tree.children[1]

    testing.expect_value(t, child1.nodes[0]["B"][0], "cc")
    testing.expect_value(t, child2.nodes[0]["B"][0], "dd")
}

@(test)
parse_complex_comment_test :: proc (t: ^testing.T) {
    tree, err := parse_from_str(SGF_SAMPLE_COMPLEX_COMMENT)
    defer tree_delete(tree)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, tree.nodes[0]["C"][0], `Meijin NR: yeah, k4 is wonderful
sweat NR: thank you! :)
dada NR: yup. I like this move too. It's a move only to be expected from a pro. I really like it :)
jansteen 4d: Can anyone explain [me] k4?`)
}

@(test)
unexpected_token_test :: proc(t: ^testing.T) {
    tree, _, err := tree_parse(to_byte_array(SGF_SAMPLE_INVALID_TOKEN))
    defer tree_delete(tree)

    testing.expectf(
        t, err.(ParseError) == .UnexpectedToken,
        "Expected %s error, got %v", ParseError.UnexpectedToken, err)
}

@(test)
unexpected_eof_test :: proc(t: ^testing.T) {
    tree , _, err := tree_parse(to_byte_array(SGF_SAMPLE_UNEXPECTED_EOF))
    defer tree_delete(tree)

    testing.expectf(
        t, err.(ParseError) == .UnexpectedEOF,
        "Expected %s error, got %v", ParseError.UnexpectedEOF, err)
}

@(test)
value_parse_edge_case_test :: proc(t: ^testing.T) {
    buf := to_byte_array("[abc\\\\]def]")
    val, _, err := value_parse(buf[1:]) // skip to after [
    defer delete(val)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, val, "abc\\")
}

@(test)
value_parse_newline_escape_test :: proc(t: ^testing.T) {
    buf := to_byte_array("[abc\\\ndef]")
    val, _, err := value_parse(buf[1:]) // skip to after [
    defer delete(val)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, val, "abcdef")
}

@(test)
value_parse_empty_value_test :: proc (t: ^testing.T) {
    buf := to_byte_array("[]")
    val, _, err := value_parse(buf[1:]) // skip to after [
    defer delete(val)

    testing.expect_value(t, err, nil)
    testing.expect_value(t, val, "")
}

@(test)
is_escape_character_test :: proc (t: ^testing.T) {
    testing.expect(t, is_escape_character(to_byte_array("\\"), 0))
    testing.expect(t, !is_escape_character(to_byte_array("\\\\"), 1))
    testing.expect(t, is_escape_character(to_byte_array("ab\\"), 2))
    testing.expect(t, !is_escape_character(to_byte_array("\\\\]"), 1))
    testing.expect(t, !is_escape_character(to_byte_array("abcgg"), 2))
    testing.expect(t, !is_escape_character(to_byte_array("\\\\\\\\"), 3))
}

@(test)
node_parse_with_multiple_value_test :: proc (t: ^testing.T) {
    buf1 := to_byte_array("A[aa]C[xx]A[bb]A[cc];")
    buf2 := to_byte_array("C[xx]A[aa][bb][cc];")
    buf3 := to_byte_array("A[aa]C[xx]A[bb][cc];")

    node1, _, err1 := node_parse(buf1)
    defer node_delete(&node1)

    testing.expect_value(t, err1, nil)

    node2, _, err2 := node_parse(buf2)
    defer node_delete(&node2)

    testing.expect_value(t, err2, nil)

    node3, _, err3 := node_parse(buf3)
    defer node_delete(&node3)

    testing.expect_value(t, err3, nil)

    nodes := []Node{ node1, node2, node3 }

    for node in nodes {
        testing.expect_value(t, len(node), 2)
        testing.expect_value(t, len(node["A"]), 3)
        testing.expect_value(t, len(node["C"]), 1)
        testing.expect_value(t, node["A"][0], "aa")
        testing.expect_value(t, node["A"][1], "bb")
        testing.expect_value(t, node["A"][2], "cc")
        testing.expect_value(t, node["C"][0], "xx")
    }
}

@(test)
to_sfg_file_and_back_test :: proc (t: ^testing.T) {
    sgf_string := "(;A[aa](;B[bb])(;C[cc];D[dd]))"

    tree, err := parse_from_str(sgf_string)
    defer tree_delete(tree)
    testing.expect_value(t, err, nil)

    converted_str, err2 := tree_to_sgf(&tree)
    defer delete(converted_str)
    testing.expect_value(t, err2, nil)

    tree2, err3 := parse_from_str(converted_str)
    defer tree_delete(tree2)
    testing.expect_value(t, err3, nil)

    testing.expect_value(t, len(tree.nodes), len(tree2.nodes))
    testing.expect_value(t, len(tree.children), len(tree2.children))

    testing.expect_value(t, tree.nodes[0]["A"][0], tree2.nodes[0]["A"][0])

    testing.expect_value(t, tree.children[0].nodes[0]["B"][0], tree2.children[0].nodes[0]["B"][0])

    testing.expect_value(t, tree.children[1].nodes[0]["C"][0], tree2.children[1].nodes[0]["C"][0])
    testing.expect_value(t, tree.children[1].nodes[1]["D"][0], tree2.children[1].nodes[1]["D"][0])
}
