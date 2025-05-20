package socketio

import "core:c"

SIO_Client :: distinct rawptr
SIO_Socket :: distinct rawptr
SIO_Message :: distinct rawptr

Message_Type :: enum c.int {
    NULL = 0,
    STRING,
    INTEGER,
    DOUBLE,
    BOOLEAN,
    ARRAY,
    OBJECT,
    BINARY,
}

Connect_Callback :: #type proc "c" (user_data: rawptr)
Close_Callback :: #type proc "c" (user_data: rawptr)
Event_Callback :: #type proc "c" (event: cstring, msg: SIO_Message, user_data: rawptr)
Fail_Callback :: #type proc "c" (user_data: rawptr)
Reconnect_Callback :: #type proc "c" (attempt: c.uint, delay: c.uint, user_data: rawptr)
Socket_Listener_Callback :: #type proc "c" (nsp: cstring, user_data: rawptr)
Error_Callback :: #type proc "c" (error: cstring, user_data: rawptr)

foreign import sio "system:socketio.a"

@(link_prefix="sio_")
foreign sio {
    message_create_null :: proc "c" () -> SIO_Message ---
    message_create_string :: proc "c" (str: cstring) -> SIO_Message ---
    message_create_integer :: proc "c" (value: i64) -> SIO_Message ---
    message_create_double :: proc "c" (value: f64) -> SIO_Message ---
    message_create_boolean :: proc "c" (value: c.int) -> SIO_Message ---
    message_create_array :: proc "c" () -> SIO_Message ---
    message_create_object :: proc "c" () -> SIO_Message ---

    message_destroy :: proc "c" (msg: SIO_Message) ---
    message_get_type :: proc "c" (msg: SIO_Message) -> Message_Type ---
    message_get_string :: proc "c" (msg: SIO_Message) -> cstring ---
    message_get_integer :: proc "c" (msg: SIO_Message) -> i64 ---
    message_get_double :: proc "c" (msg: SIO_Message) -> f64 ---
    message_get_boolean :: proc "c" (msg: SIO_Message) -> c.int ---

    message_array_push :: proc "c" (array: SIO_Message, msg: SIO_Message) ---
    message_array_size :: proc "c" (array: SIO_Message) -> c.size_t ---
    message_array_get :: proc "c" (array: SIO_Message, index: c.size_t) -> SIO_Message ---

    message_object_set :: proc "c" (obj: SIO_Message, key: cstring, msg: SIO_Message) ---
    message_object_get :: proc "c" (obj: SIO_Message, key: cstring) -> SIO_Message ---
    message_object_has :: proc "c" (obj: SIO_Message, key: cstring) -> c.int ---

    client_create :: proc "c" () -> SIO_Client ---
    client_destroy :: proc "c" (client: SIO_Client) ---
    client_connect :: proc "c" (client: SIO_Client, uri: cstring) ---
    client_close :: proc "c" (client: SIO_Client) ---
    client_sync_close :: proc "c" (client: SIO_Client) ---

    client_set_open_listener :: proc "c" (client: SIO_Client, cb: Connect_Callback, user_data: rawptr) ---
    client_set_fail_listener :: proc "c" (client: SIO_Client, cb: Fail_Callback, user_data: rawptr) ---
    client_set_close_listener :: proc "c" (client: SIO_Client, cb: Close_Callback, user_data: rawptr) ---
    client_set_reconnect_listener :: proc "c" (client: SIO_Client, cb: Reconnect_Callback, user_data: rawptr) ---
    client_set_socket_open_listener :: proc "c" (client: SIO_Client, cb: Socket_Listener_Callback, user_data: rawptr) ---
    client_set_socket_close_listener :: proc "c" (client: SIO_Client, cb: Socket_Listener_Callback, user_data: rawptr) ---

    client_get_socket :: proc "c" (client: SIO_Client, nsp: cstring = "") -> SIO_Socket ---

    socket_destroy :: proc "c" (socket: SIO_Socket) ---
    socket_emit :: proc "c" (socket: SIO_Socket, event: cstring, msg: SIO_Message) ---
    socket_on :: proc "c" (socket: SIO_Socket, event: cstring, cb: Event_Callback, user_data: rawptr) ---
    socket_off :: proc "c" (socket: SIO_Socket, event: cstring) ---
}
