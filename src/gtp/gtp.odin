package gtp

import "core:os/os2"
import "core:io"
import "core:slice"
import "core:fmt"
import "core:strings"

GTPClientType :: enum {
    PACHI,
}

GTPClient :: struct {
    type: GTPClientType,
    stdin_w: ^os2.File,
    stdout_r: ^os2.File,
    process: os2.Process,
}

client_new :: proc (type: GTPClientType, path: string) -> (client: GTPClient, err: os2.Error) {
    client.type = type

    stdin_r, stdin_w := os2.pipe() or_return
    stdout_r, stdout_w := os2.pipe() or_return

    client.stdin_w = stdin_w
    client.stdout_r = stdout_r

    client.process = os2.process_start({
        command = { path },
        stdout = stdout_w,
        stdin = stdin_r,
    }) or_return

    os2.close(stdout_w)
    os2.close(stdin_r)

    return
}

client_send_and_receive :: proc (client: ^GTPClient, command: string) -> (res: string) {
    os2.write(client.stdin_w, slice.bytes_from_ptr(raw_data(command), len(command)))

    buf: [1024]byte
    os2.read(client.stdout_r, buf[:])

    fmt.println(strings.string_from_ptr(raw_data(buf[:]), len(buf)))

    return
}

client_delete :: proc (client: ^GTPClient) {
    _ = os2.process_kill(client.process)
    _ = os2.process_close(client.process)

    os2.close(client.stdin_w)
    os2.close(client.stdout_r)
}
