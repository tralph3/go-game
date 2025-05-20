package main

import "core:os/os2"
import "core:os"
import "core:fmt"
import "core:strings"
import pt "core:path/filepath"
import "core:time"

BUILD_PATH: string : "build"
SOCKETIO_TAG: string : "3.1.0"

socketio_path: string

NoExecutableError :: struct {
    message: string
}

Command :: distinct [dynamic]string

executable_exists :: proc (name: string) -> bool {
    p, err := os2.process_start({ command = { name } })
    if err != nil {
        return false
    }

    _, _ = os2.process_wait(p, time.Second * 2)

    return true
}

download_socketio_cpp :: proc () -> bool {
    cmd: Command

    append(&cmd,
           "git", "clone",
           "https://github.com/socketio/socket.io-client-cpp",
           socketio_path,
           "--recursive",
    )

    if !run_cmd(&cmd) {
        return false
    }

    return true
}

configure_socketio_cpp :: proc () -> (ok: bool) {
    cmd: Command

    append(&cmd,
           "git",
           "-C", socketio_path,
           "checkout", SOCKETIO_TAG,
    )

    if !run_cmd(&cmd, silent=true) {
        return false
    }

    if err := os2.copy_file(pt.join({socketio_path, "src", "sio_c_wrapper.cpp"}), "sio_c_wrapper.cpp"); err != nil { return false }
    if err := os2.copy_file(pt.join({socketio_path, "src", "sio_c_wrapper.h"}), "sio_c_wrapper.h"); err != nil { return false }

    return true
}

compile_socketio_cpp :: proc () -> (ok: bool) {
    if !os2.is_directory(socketio_path) {
        if !download_socketio_cpp() { return false }
        if !configure_socketio_cpp() { return false }
    }

    cmd: Command

    append(&cmd, "g++", "-c",
           "--std=c++11",

           pt.join({ "src", "sio_c_wrapper.cpp" }),
           pt.join({ "src", "sio_client.cpp" }),
           pt.join({ "src", "internal", "sio_client_impl.cpp" }),
           pt.join({ "src", "internal", "sio_packet.cpp" }),
           pt.join({ "src", "sio_socket.cpp" }),

           pt.join({ "-Ilib", "asio", "asio", "include" }),
           pt.join({ "-Ilib", "websocketpp" }),
           pt.join({ "-Ilib", "rapidjson", "include" }),

           "-DBOOST_DATE_TIME_NO_LIB",
           "-DBOOST_REGEX_NO_LIB",
           "-DASIO_STANDALONE",
           "-D_WEBSOCKETPP_CPP11_STL_",
           "-D_WEBSOCKETPP_CPP11_FUNCTIONAL_",
           "-DSIO_TLS",

           "-shared",
           "-fPIC",
          )

    if !run_cmd(&cmd, work_dir=socketio_path) {
        return false
    }

    clear(&cmd)

    append(&cmd, "ar",
           "rcs",
           pt.join({ BUILD_PATH, "socketio.a" }),

           pt.join({ socketio_path, "sio_c_wrapper.o" }),
           pt.join({ socketio_path, "sio_client.o" }),
           pt.join({ socketio_path, "sio_client_impl.o" }),
           pt.join({ socketio_path, "sio_packet.o" }),
           pt.join({ socketio_path, "sio_socket.o" }),
          )

    return run_cmd(&cmd)
}

@(require_results)
run_cmd :: proc (cmd: ^Command, silent: bool = false, work_dir: string = "") -> (ok: bool) {
    str := strings.join(cmd[:], " ")
    fmt.printfln("COMMAND: '%s'", str)
    defer delete(str)

    handle, start_error := os2.process_start({
        command = cmd[:],
        working_dir = work_dir,
        stdin = os2.stdin,
        stdout = os2.stdout if !silent else nil,
        stderr = os2.stderr if !silent else nil,
    })

    if start_error != nil {
        fmt.eprintfln("ERROR: Failed running command: '%s'", str)
        return false
    }

    state, wait_error := os2.process_wait(handle)
    if state.exit_code != 0 || wait_error != nil {
        fmt.eprintfln("ERROR: Failed running command: '%s'", str)
        return false
    }

    return true
}

prepare :: proc () -> (ok: bool, err: NoExecutableError) {
    if os2.is_file("build") {
        os2.remove("build")
    }

    if os2.is_file("build.bin") {
        os2.remove("build.bin")
    }

    if os2.is_file("src.bin") {
        os2.remove("src.bin")
    }

    os2.make_directory("build")

    socketio_path = pt.join({ BUILD_PATH, "socketio-client" })

    if !executable_exists("git") {
        return false, NoExecutableError { message = "Git is needed to compile this program." }
    }

    if !executable_exists("g++") {
        return false, NoExecutableError { message = "g++ is needed to compile this program."}
    }

    if !executable_exists("ar") {
        return false, NoExecutableError { message = "ar is needed to compile this program."}
    }

    return true, {}
}

optimization_flags :: proc (cmd: ^Command) {
    append(cmd, "-o:speed")
    append(cmd, "-disable-assert")
}

strict_style_flags :: proc (cmd: ^Command) {
    append(cmd, "-strict-style")
    append(cmd, "-vet-using-stmt")
    append(cmd, "-vet-using-param")
    append(cmd, "-vet-unused")
    append(cmd, "-vet-shadowing")
    append(cmd, "-vet-cast")
}

make_build_cmd :: proc (pkg, out: string) -> Command {
    cmd: Command
    append(&cmd, "odin")
    append(&cmd, "build")
    append(&cmd, pkg)
    append(&cmd, "-debug")
    append(&cmd, fmt.tprintf("-extra-linker-flags:-L%s %s", BUILD_PATH, "-lstdc++ -lm -static-libgcc -lssl -lcrypto"))
    append(&cmd, fmt.tprintf("-out:%s", pt.join({ BUILD_PATH, out })))

    return cmd
}

main :: proc () {
    ok, err := prepare()
    if !ok {
        fmt.eprintfln("ERROR: %s", err.message)
        return
    }

    if !os2.is_file(pt.join({ BUILD_PATH, "socketio.a" })) {
        if !compile_socketio_cpp() {
            fmt.eprintln("ERROR: Error compiling socketio-client. Aborting")
            return
        }
    }

    cmd := make_build_cmd("src", "go")
    append(&cmd, "-error-pos-style:unix")
    // strict_style_flags(&cmd)
    // optimization_flags(&cmd)

    _ = run_cmd(&cmd)
}
