package sgf

import "core:testing"
import "core:os"
import "core:strings"
import "core:slice"
import "core:mem"

SGF_SAMPLE_SIMPLE :: "(;FF[4]GM[1]SZ[19])"
SGF_SAMPLE_WITH_CHILD :: "(;FF[4]GM[1];B[aa];W[bb](;B[cc])(;B[dd]))"
SGF_SAMPLE_INVALID_TOKEN :: "(;FF[4]GM[1]SZ[19]@)"
SGF_SAMPLE_UNEXPECTED_EOF :: "(;FF[4]GM[1]SZ[19]"

to_byte_array :: proc (str: string) -> []byte {
    return slice.from_ptr(raw_data(str), len(str))
}

@(test)
parse_simple_tree_test :: proc(t: ^testing.T) {
    root, _, err := tree_parse(to_byte_array(SGF_SAMPLE_SIMPLE))
    defer tree_delete(root)

    tree := root.children[0]

    testing.expect_value(t, err, nil)
    testing.expectf(t, len(tree.nodes) == 1, "Expected 1 root node, got %d", len(tree.nodes))

    testing.expect_value(t, tree.nodes[0]["FF"], "4")
    testing.expect_value(t, tree.nodes[0]["GM"], "1")
    testing.expect_value(t, tree.nodes[0]["SZ"], "19")
}

@(test)
parse_tree_with_children_test :: proc(t: ^testing.T) {
    root, _, err := tree_parse(to_byte_array(SGF_SAMPLE_WITH_CHILD))
    defer tree_delete(root)

    tree := root.children[0]

    testing.expect_value(t, err, nil)
    testing.expectf(t, len(tree.nodes) == 3, "Expected 3 root-level nodes (FF, GM and moves), got %d", len(tree.nodes))
    testing.expectf(t, len(tree.children) == 2, "Expected 2 child variations, got %d", len(tree.children))

    child1 := tree.children[0]
    child2 := tree.children[1]

    testing.expect_value(t, child1.nodes[0]["B"], "cc")
    testing.expect_value(t, child2.nodes[0]["B"], "dd")
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
