package main

import sio "socketio"
import "core:strings"
import "core:fmt"
import "base:runtime"

OGS_URL :: "https://online-go.com"

OGSConnectionStatus :: enum {
    Disconnected,
    Connected,
    Failed,
}

OGSClient :: struct {
    client: sio.SIO_Client,
    socket: sio.SIO_Socket,
    connection_status: OGSConnectionStatus,
    board: ^Board,
}

ogs_connect :: proc () -> ^OGSClient  {
    ogs_client := new(OGSClient)

    ogs_client.client = sio.client_create()

    sio.client_set_open_listener(ogs_client.client, ogs_open_connection_callback, ogs_client)
    sio.client_set_close_listener(ogs_client.client, ogs_close_connection_callback, ogs_client)
    sio.client_set_fail_listener(ogs_client.client, ogs_fail_connection_callback, ogs_client)

    sio.client_connect(ogs_client.client, OGS_URL)

    ogs_client.socket = sio.client_get_socket(ogs_client.client, "")

    return ogs_client
}

ogs_authenticate :: proc (client: ^OGSClient, jwt: cstring) {
    fmt.println("authenticating")
    msg := sio.message_create_object()
    defer sio.message_destroy(msg)

    sio.message_object_set(msg, "jwt", sio.message_create_string(jwt))

    sio.socket_emit(client.socket, "authenticate", msg)
}

ogs_load_game :: proc (client: ^OGSClient, game_id: i64) {
    fmt.println("loading game")

    sio.socket_on(client.socket, strings.clone_to_cstring(fmt.tprintf("game/%d/gamedata", game_id)), ogs_gamedata_callback, client)

    msg := sio.message_create_object()
    defer sio.message_destroy(msg)

    sio.message_object_set(msg, "game_id", sio.message_create_integer(game_id))
    sio.message_object_set(msg, "chat", sio.message_create_boolean(0))

    sio.socket_emit(client.socket, "game/connect", msg)
}

ogs_gamedata_callback :: proc "c" (event: cstring, msg: sio.SIO_Message, client: rawptr) {
    context = runtime.default_context()
    move_array := sio.message_object_get(msg, "moves")
    move_array_size := sio.message_array_size(move_array)

    for i in 0..<move_array_size {
        move := sio.message_array_get(move_array, i)
        x := sio.message_get_integer(sio.message_array_get(move, 0))
        y := sio.message_get_integer(sio.message_array_get(move, 1))

        board_set((^OGSClient)(client).board, u32(x), u32(y))
    }
}

@(private="file")
ogs_open_connection_callback :: proc "c" (ogs_client: rawptr) {
    (^OGSClient)(ogs_client).connection_status = .Connected

    context = runtime.default_context()
    fmt.println("Connected!")
}

@(private="file")
ogs_close_connection_callback :: proc "c" (ogs_client: rawptr) {
    (^OGSClient)(ogs_client).connection_status = .Disconnected
}

@(private="file")
ogs_fail_connection_callback :: proc "c" (ogs_client: rawptr) {
    (^OGSClient)(ogs_client).connection_status = .Failed
}
