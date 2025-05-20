package socketio

import "core:c"

foreign import sio "system:socketio.a"

Client :: distinct rawptr
Socket :: distinct rawptr
Message :: distinct rawptr

MessageType :: enum c.int {
    NULL = 0,
    STRING,
    INTEGER,
    DOUBLE,
    BOOLEAN,
    ARRAY,
    OBJECT,
    BINARY,
}

ConnectCallback :: #type proc "c" (user_data: rawptr)
CloseCallback :: #type proc "c" (user_data: rawptr)
EventCallback :: #type proc "c" (event: cstring, msg: Message, user_data: rawptr)
FailCallback :: #type proc "c" (user_data: rawptr)
ReconnectCallback :: #type proc "c" (attempt: c.uint, delay: c.uint, user_data: rawptr)
SocketListenerCallback :: #type proc "c" (nsp: cstring, user_data: rawptr)
ErrorCallback :: #type proc "c" (error: cstring, user_data: rawptr)

@(link_prefix="sio_")
foreign sio {
    message_create_null :: proc "c" () -> Message ---
    message_create_string :: proc "c" (str: cstring) -> Message ---
    message_create_integer :: proc "c" (value: i64) -> Message ---
    message_create_double :: proc "c" (value: f64) -> Message ---
    message_create_boolean :: proc "c" (value: c.int) -> Message ---
    message_create_array :: proc "c" () -> Message ---
    message_create_object :: proc "c" () -> Message ---

    message_destroy :: proc "c" (msg: Message) ---
    message_get_type :: proc "c" (msg: Message) -> MessageType ---
    message_get_string :: proc "c" (msg: Message) -> cstring ---
    message_get_integer :: proc "c" (msg: Message) -> i64 ---
    message_get_double :: proc "c" (msg: Message) -> f64 ---
    message_get_boolean :: proc "c" (msg: Message) -> c.int ---

    message_array_push :: proc "c" (array: Message, msg: Message) ---
    message_array_size :: proc "c" (array: Message) -> c.size_t ---
    message_array_get :: proc "c" (array: Message, index: c.size_t) -> Message ---

    message_object_set :: proc "c" (obj: Message, key: cstring, msg: Message) ---
    message_object_get :: proc "c" (obj: Message, key: cstring) -> Message ---
    message_object_has :: proc "c" (obj: Message, key: cstring) -> c.int ---

    client_create :: proc "c" () -> Client ---
    client_destroy :: proc "c" (client: Client) ---
    client_connect :: proc "c" (client: Client, uri: cstring) ---
    client_close :: proc "c" (client: Client) ---
    client_sync_close :: proc "c" (client: Client) ---

    client_set_open_listener :: proc "c" (client: Client, cb: ConnectCallback, user_data: rawptr) ---
    client_set_fail_listener :: proc "c" (client: Client, cb: FailCallback, user_data: rawptr) ---
    client_set_close_listener :: proc "c" (client: Client, cb: CloseCallback, user_data: rawptr) ---
    client_set_reconnect_listener :: proc "c" (client: Client, cb: ReconnectCallback, user_data: rawptr) ---
    client_set_socket_open_listener :: proc "c" (client: Client, cb: SocketListenerCallback, user_data: rawptr) ---
    client_set_socket_close_listener :: proc "c" (client: Client, cb: SocketListenerCallback, user_data: rawptr) ---

    client_get_socket :: proc "c" (client: Client, nsp: cstring = "") -> Socket ---

    socket_destroy :: proc "c" (socket: Socket) ---
    socket_emit :: proc "c" (socket: Socket, event: cstring, msg: Message) ---
    socket_on :: proc "c" (socket: Socket, event: cstring, cb: EventCallback, user_data: rawptr) ---
    socket_off :: proc "c" (socket: Socket, event: cstring) ---
}
