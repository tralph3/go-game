package main

import sio "socketio"
import "core:strings"
import "core:fmt"
// import "http"
// import "http/client"
import "core:encoding/json"
import "core:strconv"

OGS_URL :: "https://online-go.com"

LOGIN_ENDPOINT :: OGS_URL + "/api/v0/login"

SIOSession :: struct {
    client: sio.Client,
    socket: sio.Socket,
}

OGSAPICredentials :: struct {
    csrf_token: string,
    session_id: string,
    jwt: string,
}

OGSSession :: struct {
    sio_session: SIOSession,
    credentials: OGSAPICredentials,
    board: ^Board,
}

LoginError :: union {
    // client.Error,
    // client.Body_Error,
    json.Marshal_Error,
    json.Unmarshal_Error,
    IncorrectUserOrPasswordError,
    UnknownError,
}

IncorrectUserOrPasswordError :: struct {}
UnknownError :: struct {}

// ogs_login :: proc (username, password: string) -> (^OGSSession, LoginError) {
//     if strings.trim_space(username) == "" || strings.trim_space(password) == "" {
//         return nil, IncorrectUserOrPasswordError {}
//     }

//     req: client.Request
// 	client.request_init(&req, .Post)
// 	defer client.request_destroy(&req)

//     // cant decide if inline structure definition is gross or genius
// 	data := struct { username, password: string } {
//         username,
//         password,
//     }
// 	if err := client.with_json(&req, data); err != nil {
// 		return nil, err
// 	}

// 	res, err := client.request(&req, LOGIN_ENDPOINT)
// 	if err != nil {
// 		return nil, err
// 	}
// 	defer client.response_destroy(&res)

//     if res.status == .Forbidden {
//         return nil, IncorrectUserOrPasswordError {}
//     } else if res.status != .OK {
//         return nil, UnknownError {}
//     }

// 	body, was_allocation, body_err := client.response_body(&res)
// 	if body_err != nil {
// 		return nil, body_err
// 	}
// 	defer client.body_destroy(body, was_allocation)

//     ogs_session := new(OGSSession)

//     for cookie in res.cookies {
//         if cookie.name == "csrftoken" {
//             ogs_session.credentials.csrf_token = cookie.value
//         } else if cookie.name == "sessionid" {
//             ogs_session.credentials.session_id = cookie.value
//         }
//     }

//     jwt_struct := struct { user_jwt: string } {}
//     if err := json.unmarshal(transmute([]u8) (body.(string)), &jwt_struct); err != nil {
//         ogs_session_destroy(ogs_session)
//         return nil, err
//     }

//     ogs_session.credentials.jwt = jwt_struct.user_jwt

//     ogs_configure_socketio_client(ogs_session)

//     return ogs_session, nil
// }

// ogs_session_destroy :: proc (session: ^OGSSession) {
//     if session.sio_session.socket != nil {
//         sio.socket_destroy(session.sio_session.socket)
//     }

//     if session.sio_session.client != nil {
//         sio.client_destroy(session.sio_session.client)
//     }

//     delete(session.credentials.jwt)

//     free(session)
// }

// ogs_configure_socketio_client :: proc (session: ^OGSSession) {
//     session.sio_session.client = sio.client_create()

//     sio.client_set_open_listener(session.sio_session.client, ogs_open_connection_callback, session)
//     sio.client_set_close_listener(session.sio_session.client, ogs_close_connection_callback, session)
//     sio.client_set_fail_listener(session.sio_session.client, ogs_fail_connection_callback, session)

//     sio.client_connect(session.sio_session.client, OGS_URL)

//     session.sio_session.socket = sio.client_get_socket(session.sio_session.client)

//     msg := sio.message_create_object()
//     defer sio.message_destroy(msg)

//     cs_jwt := strings.clone_to_cstring(session.credentials.jwt)
//     defer delete(cs_jwt)

//     sio.message_object_set(msg, "jwt", sio.message_create_string(cs_jwt))

//     sio.socket_emit(session.sio_session.socket, "authenticate", msg)
// }

// ogs_game_connect :: proc (session: ^OGSSession, game_id: i64) {
//     msg := sio.message_create_object()
//     defer sio.message_destroy(msg)

//     sio.socket_on(
//         session.sio_session.socket,
//         fmt.ctprintf("game/%d/gamedata", game_id),
//         ogs_on_game_connect,
//         session)

//     sio.socket_on(
//         session.sio_session.socket,
//         fmt.ctprintf("game/%d/move", game_id),
//         ogs_on_game_move,
//         session)

//     sio.message_object_set(msg, "game_id", sio.message_create_integer(game_id))
//     sio.message_object_set(msg, "chat", sio.message_create_boolean(0))

//     sio.socket_emit(session.sio_session.socket, "game/connect", msg)
// }

// ogs_game_move :: proc (session: ^OGSSession, game_id: i64, x, y: u32) {
//     if err := board_set(session.board, x, y); err != nil {
//         return
//     }

//     msg := sio.message_create_object()
//     defer sio.message_destroy(msg)

//     move := board_get_sgf_coordinate_cstring(x, y)
//     sio.message_object_set(msg, "game_id", sio.message_create_integer(game_id))
//     sio.message_object_set(msg, "move", sio.message_create_string(move))

//     sio.socket_emit(session.sio_session.socket, "game/move", msg)
// }

// ogs_on_game_move :: proc "c" (event: cstring, msg: sio.Message, session: rawptr) {
//     context = GLOBAL_STATE.ctx

//     move_array := sio.message_object_get(msg, "move")
//     x := u32(sio.message_get_integer(sio.message_array_get(move_array, 0)))
//     y := u32(sio.message_get_integer(sio.message_array_get(move_array, 1)))

//     board_set((^OGSSession)(session).board, x, y)

//     sio.message_destroy(msg)
// }

// ogs_on_game_connect :: proc "c" (event: cstring, msg: sio.Message, session: rawptr) {

// }

// @(private="file")
// ogs_open_connection_callback :: proc "c" (session: rawptr) {
// }

// @(private="file")
// ogs_close_connection_callback :: proc "c" (session: rawptr) {
// }

// @(private="file")
// ogs_fail_connection_callback :: proc "c" (session: rawptr) {
// }

// @(private="file")
// ogs_configure_authenticated_request :: proc (session: ^OGSSession) -> client.Request {
//     req: client.Request
//     client.request_init(&req)

//     http.headers_set(&req.headers, "Referer", OGS_URL)

//     cookie_str := fmt.tprintf("csrftoken=%s; sessionid=%s",
//                               session.credentials.csrf_token, session.credentials.session_id)
//     http.headers_set(&req.headers, "Cookie", cookie_str)

//     http.headers_set(&req.headers, "X-CSRFToken", session.credentials.csrf_token)

//     http.headers_set_content_type_mime(&req.headers, .Json)

//     return req
// }

// @(private="file")
// ogs_extract_game_id_from_event_string :: proc "contextless" (str: cstring) -> i64 {
//     context = GLOBAL_STATE.ctx

//     str := string(str)

//     start := strings.index(str, "/") + 1
//     end := strings.last_index(str, "/")

//     return i64(strconv.atoi(str[start:end]))
// }
