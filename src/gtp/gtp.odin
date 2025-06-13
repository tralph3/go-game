package gtp

import "core:os/os2"
import "core:slice"
import "core:fmt"
import "core:strings"
import "core:sync/chan"
import "core:strconv"
import "core:thread"

EVENT_CHANNEL_BUFFER_SIZE :: 8

COMMAND_GENMOVE :: "genmove"
COMMAND_PLAY :: "play"
COMMAND_BOARDSIZE :: "boardsize"
COMMAND_KOMI :: "komi"
COMMAND_CLEAR_BOARD :: "clear_board\n"
COMMAND_SHOWBOARD :: "showboard\n"

GTPClient :: struct {
    stdin_w: ^os2.File,
    stdout_r: ^os2.File,
    command_channel: chan.Chan(string, .Both),
    process: os2.Process,
    event_thread: ^thread.Thread,
    event_callback: proc (command, response: string, user_data: rawptr),
    board_size: u32,
    user_data: rawptr,
}

Side :: enum {
    WHITE,
    BLACK,
}

client_read_events :: proc (client: ^GTPClient) {
    for {
        if chan.is_closed(client.command_channel) { break }
        command, ok := chan.recv(chan.as_recv(client.command_channel))
        if !ok {
            delete(command)
            break
        }

        when ODIN_DEBUG {
            if strings.starts_with(command, COMMAND_GENMOVE) ||
                strings.starts_with(command, COMMAND_PLAY) {
                client_send_command(client, COMMAND_SHOWBOARD)
            }
        }

        os2.write(client.stdin_w, slice.bytes_from_ptr(raw_data(command), len(command)))

        buf: [2048]byte
        total: int
        str: string
        for {
            total += os2.read(client.stdout_r, buf[total:]) or_continue
            str = strings.string_from_ptr(raw_data(buf[:]), total)
            if strings.contains(str, "\n\n") { break }
        }

        assert(strings.starts_with(str, "="), str)

        response := str[2:]

        client.event_callback(command, response, client.user_data)
    }
}

client_new :: proc (engine_command: []string) -> (client: ^GTPClient, err: os2.Error) {
    client = new(GTPClient)

    client.command_channel = chan.create(
        type_of(client.command_channel), EVENT_CHANNEL_BUFFER_SIZE, context.allocator) or_return

    stdin_r, stdin_w := os2.pipe() or_return
    stdout_r, stdout_w := os2.pipe() or_return

    client.stdin_w = stdin_w
    client.stdout_r = stdout_r

    client.process = os2.process_start({
        command = engine_command,
        stdout = stdout_w,
        stdin = stdin_r,
    }) or_return

    os2.close(stdout_w)
    os2.close(stdin_r)

    client.event_thread = thread.create_and_start_with_poly_data(client, client_read_events, init_context=context)

    return
}

client_configure :: proc (client: ^GTPClient, board_size: u32, komi: f32, event_callback: proc (string, string, rawptr)) {
    board_size_cmd := fmt.aprintfln("%s %d", COMMAND_BOARDSIZE, board_size)
    defer delete(board_size_cmd)

    komi_cmd := fmt.aprintfln("%s %f", COMMAND_KOMI, komi)
    defer delete(komi_cmd)

    client.event_callback = event_callback
    client.board_size = board_size

    client_send_command(client, board_size_cmd)
    client_send_command(client, komi_cmd)
    client_send_command(client, COMMAND_CLEAR_BOARD)
}

client_send_command :: proc (client: ^GTPClient, command: string) {
    cmd := strings.clone(command)
    chan.send(chan.as_send(client.command_channel), cmd)
}

client_make_move :: proc (client: ^GTPClient, x, y: u32, side: Side) {
    side_str: string
    opposite: string
    switch side {
    case .WHITE:
        side_str = "w"
        opposite = "b"
    case .BLACK:
        side_str = "b"
        opposite = "w"
    }

    coord := number_coord_to_gtp_coord({ x, y }, client.board_size)
    defer delete(coord)

    command := fmt.aprintfln("%s %s %s", COMMAND_PLAY, side_str, coord)
    defer delete(command)

    client_send_command(client, command)

    gen_command := fmt.aprintfln("%s %s", COMMAND_GENMOVE, opposite)
    defer delete(gen_command)

    client_send_command(client, gen_command)
}

client_delete :: proc (client: ^GTPClient) {
    _ = os2.process_kill(client.process)
    _ = os2.process_close(client.process)

    chan.close(client.command_channel)

    os2.close(client.stdin_w)
    os2.close(client.stdout_r)

    thread.join(client.event_thread)
    thread.destroy(client.event_thread)

    // clear channel buffer
    for {
        c, ok := chan.try_recv(client.command_channel)
        if !ok { break }
        delete(c)
    }

    chan.destroy(client.command_channel)

    free(client)
}

number_coord_to_gtp_coord :: proc (coord: [2]u32, board_size: u32, allocator := context.allocator) -> string {
    coord := coord
    coord.y = board_size - coord.y
    coord.x += 'A'

    if coord.x >= 'I' {
        coord.x += 1
    }

    return fmt.aprintf("%c%d", coord.x, coord.y, allocator=allocator)
}

gtp_coord_to_number :: proc (coord: string, board_size: u32) -> [2]u32 {
    assert(len(coord) >= 2)

    string_to_upper_in_place(coord)

    x := (^u8)(raw_data(coord))^

    if x >= 'I' {
        x -= 1
    }

    x -= 'A'

    y := board_size - u32(strconv.atoi(coord[1:]))

    return { u32(x), y }
}

string_to_upper_in_place :: proc (str: string) {
    // WARNING: Don't pass static strings!

    str_ptr := ([^]u8)(raw_data(str))

    for i in 0..<len(str) {
        b := str_ptr[i]

        if b >= 'a' && b <= 'z' {
            str_ptr[i] -= 'a' - 'A'
        }
    }
}
