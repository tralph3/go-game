package main

import sio "socketio"
import "core:strings"
import "core:fmt"
import "base:runtime"
import "http"
import "http/client"
import "core:encoding/json"

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
    client.Error,
    client.Body_Error,
    json.Marshal_Error,
    json.Unmarshal_Error,
    IncorrectUserOrPasswordError,
    UnknownError,
}

IncorrectUserOrPasswordError :: struct {}
UnknownError :: struct {}

ogs_login :: proc (username, password: string) -> (^OGSSession, LoginError) {
    if strings.trim_space(username) == "" || strings.trim_space(password) == "" {
        return nil, IncorrectUserOrPasswordError {}
    }

    req: client.Request
	client.request_init(&req, .Post)
	defer client.request_destroy(&req)

    // cant decide if inline structure definition is gross or genius
	data := struct { username, password: string } {
        username,
        password,
    }
	if err := client.with_json(&req, data); err != nil {
		return nil, err
	}

	res, err := client.request(&req, LOGIN_ENDPOINT)
	if err != nil {
		return nil, err
	}
	defer client.response_destroy(&res)

    if res.status == .Forbidden {
        return nil, IncorrectUserOrPasswordError {}
    } else if res.status != .OK {
        return nil, UnknownError {}
    }

	body, was_allocation, body_err := client.response_body(&res)
	if body_err != nil {
		return nil, body_err
	}
	defer client.body_destroy(body, was_allocation)

    ogs_session := new(OGSSession)

    for cookie in res.cookies {
        if cookie.name == "csrftoken" {
            ogs_session.credentials.csrf_token = cookie.value
        } else if cookie.name == "sessionid" {
            ogs_session.credentials.session_id = cookie.value
        }
    }

    jwt_struct := struct { user_jwt: string } {}
    if err := json.unmarshal(transmute([]u8) (body.(string)), &jwt_struct); err != nil {
        free(ogs_session)
        return nil, err
    }

    ogs_session.credentials.jwt = jwt_struct.user_jwt

    ogs_configure_socketio_client(ogs_session)

    return ogs_session, nil
}

ogs_configure_socketio_client :: proc (session: ^OGSSession) {
    session.sio_session.client = sio.client_create()

    sio.client_set_open_listener(session.sio_session.client, ogs_open_connection_callback, session)
    sio.client_set_close_listener(session.sio_session.client, ogs_close_connection_callback, session)
    sio.client_set_fail_listener(session.sio_session.client, ogs_fail_connection_callback, session)

    sio.client_connect(session.sio_session.client, OGS_URL)

    session.sio_session.socket = sio.client_get_socket(session.sio_session.client)

    msg := sio.message_create_object()
    defer sio.message_destroy(msg)

    cs_jwt := strings.clone_to_cstring(session.credentials.jwt)
    defer delete(cs_jwt)

    sio.message_object_set(msg, "jwt", sio.message_create_string(cs_jwt))

    sio.socket_emit(session.sio_session.socket, "authenticate", msg)
}

@(private="file")
ogs_open_connection_callback :: proc "c" (session: rawptr) {
    context = runtime.default_context()
    fmt.println("Connected!")
}

@(private="file")
ogs_close_connection_callback :: proc "c" (session: rawptr) {
}

@(private="file")
ogs_fail_connection_callback :: proc "c" (session: rawptr) {
}

@(private="file")
ogs_configure_authenticated_request :: proc (session: ^OGSSession) -> client.Request {
    req: client.Request
    client.request_init(&req)

    http.headers_set(&req.headers, "Referer", OGS_URL)

    cookie_str := fmt.tprintf("csrftoken=%s; sessionid=%s",
                              session.credentials.csrf_token, session.credentials.session_id)
    http.headers_set(&req.headers, "Cookie", cookie_str)

    http.headers_set(&req.headers, "X-CSRFToken", session.credentials.csrf_token)

    http.headers_set_content_type_mime(&req.headers, .Json)

    return req
}
