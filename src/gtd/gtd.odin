package gtd

import "core:os/os2"
import "core:io"

GTDClientType :: enum {
    PACHI,
}

GTDClient :: struct {
    type: GTDClientType,
}

gtd_client_new :: proc (type: GTDClientType, path: string) -> GTDClient {
    client := GTDClient {
        type = type,
    }

    _, _ = os2.process_start({
        command = { path },
        stdout = os2.pipe(),
        stdin = os2.pipe(),
    })
}
