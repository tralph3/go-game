package main

import "core:os/os2"
import "core:os"
import "core:fmt"
import "core:strings"
import pt "core:path/filepath"
import "core:time"

BUILD_PATH: string :   #config(BUILD_PATH, "build")
SOCKETIO_TAG: string : #config(SOCKETIO_TAG, "3.1.0")
DEBUG: bool :          #config(DEBUG, false)

when ODIN_OS == .Windows {
    SWITCH_CHAR :: "/"
} else {
    SWITCH_CHAR :: "-"
}

SOCKETIO_PATH :: BUILD_PATH + "/socketio-client"

when ODIN_OS == .Windows {
    SOCKETIO_LIB_NAME :: "libsocketio.lib"
} else when ODIN_OS == .Darwin {
    SOCKETIO_LIB_NAME :: "libsocketio.a"
} else {
    SOCKETIO_LIB_NAME :: "socketio.a"
}

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
           SOCKETIO_PATH,
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
           "-C", SOCKETIO_PATH,
           "checkout", SOCKETIO_TAG,
    )

    if !run_cmd(&cmd, silent=true) {
        return false
    }

    if err := os2.copy_file(pt.join({SOCKETIO_PATH, "src", "sio_c_wrapper.cpp"}), "sio_c_wrapper.cpp"); err != nil { return false }
    if err := os2.copy_file(pt.join({SOCKETIO_PATH, "src", "sio_c_wrapper.h"}), "sio_c_wrapper.h"); err != nil { return false }

    return true
}

compile_socketio_cpp :: proc () -> (ok: bool) {
    if !os2.is_directory(SOCKETIO_PATH) {
        if !download_socketio_cpp() { return false }
        if !configure_socketio_cpp() { return false }
    }

    cmd: Command

    when ODIN_OS == .Windows {
        // no explicit c++11 mode, in theory it is the default
        append(&cmd, "cl", "/c", "/EHsc")
    }

    when ODIN_OS != .Windows {
        append(&cmd, "g++", "--std=c++11", "-c")
    }

    append(&cmd, pt.join({ "src", "sio_c_wrapper.cpp" }))
    append(&cmd, pt.join({ "src", "sio_client.cpp" }))
    append(&cmd, pt.join({ "src", "internal", "sio_client_impl.cpp" }))
    append(&cmd, pt.join({ "src", "internal", "sio_packet.cpp" }))
    append(&cmd, pt.join({ "src", "sio_socket.cpp" }))

    append(&cmd, SWITCH_CHAR + "Ilib/asio/asio/include")
    append(&cmd, SWITCH_CHAR + "Ilib/websocketpp")
    append(&cmd, SWITCH_CHAR + "Ilib/rapidjson/include")

    when ODIN_OS == .Darwin {
        append(&cmd, "-I/opt/homebrew/opt/openssl/include")
    }

    when ODIN_OS == .Windows {
        // TODO: I should probably define a flag that tells me I'm in
        // the GitHub actions environment, and only add this include
        // path there. On a regular Windows installation, I guess the
        // user can add the OpenSSL include paths by environment
        // variables? Not sure.
        append(&cmd, "/I..\\..\\vcpkg\\installed\\x64-windows-static\\include")
    }

    append(&cmd, SWITCH_CHAR + "DBOOST_DATE_TIME_NO_LIB")
    append(&cmd, SWITCH_CHAR + "DBOOST_REGEX_NO_LIB")
    append(&cmd, SWITCH_CHAR + "DASIO_STANDALONE")

    append(&cmd, SWITCH_CHAR + "D_WEBSOCKETPP_CPP11_STL_")
    append(&cmd, SWITCH_CHAR + "D_WEBSOCKETPP_CPP11_FUNCTIONAL_")
    append(&cmd, SWITCH_CHAR + "D_WEBSOCKETPP_CPP11_TYPE_TRAITS_")
    append(&cmd, SWITCH_CHAR + "D_WEBSOCKETPP_CPP11_TYPE_CHRONO_")
    append(&cmd, SWITCH_CHAR + "DSIO_TLS")

    when ODIN_OS != .Windows {
        append(&cmd, "-fPIC")
    }

    run_cmd(&cmd, work_dir=SOCKETIO_PATH) or_return

    clear(&cmd)

    append(&cmd, "ar", "rcs")

    append(&cmd, BUILD_PATH + "/" + SOCKETIO_LIB_NAME)

    append(&cmd, pt.join({ SOCKETIO_PATH, "sio_c_wrapper.o" }))
    append(&cmd, pt.join({ SOCKETIO_PATH, "sio_client.o" }))
    append(&cmd, pt.join({ SOCKETIO_PATH, "sio_client_impl.o" }))
    append(&cmd, pt.join({ SOCKETIO_PATH, "sio_packet.o" }))
    append(&cmd, pt.join({ SOCKETIO_PATH, "sio_socket.o" }))

    when ODIN_OS == .Windows {
        clear(&cmd)

        append(&cmd, "lib")
        append(&cmd, fmt.tprintf("/out:%s", BUILD_PATH + "/" + SOCKETIO_LIB_NAME))

        append(&cmd, pt.join({ SOCKETIO_PATH, "sio_c_wrapper.obj" }))
        append(&cmd, pt.join({ SOCKETIO_PATH, "sio_client.obj" }))
        append(&cmd, pt.join({ SOCKETIO_PATH, "sio_client_impl.obj" }))
        append(&cmd, pt.join({ SOCKETIO_PATH, "sio_packet.obj" }))
        append(&cmd, pt.join({ SOCKETIO_PATH, "sio_socket.obj" }))
    }

    return run_cmd(&cmd)
}

compile_clay :: proc () -> (ok: bool) {
    cmd: Command

    when ODIN_OS == .Windows {
        append(&cmd, "cl", "/c", "/EHsc", "/Tc")
    } else {
        append(&cmd, "gcc", "-x", "c", "-c")
    }

    append(&cmd, "clay.h")
    append(&cmd, SWITCH_CHAR + "DCLAY_IMPLEMENTATION")

    run_cmd(&cmd, work_dir="src/clay") or_return
    clear(&cmd)

    when ODIN_OS == .Windows {
        append(&cmd, "lib")
        append(&cmd, "/out:clay.lib")
        append(&cmd, "clay.obj")
    } else {
        append(&cmd, "ar", "rcs")
        append(&cmd, "clay.a")
        append(&cmd, "clay.o")
    }

    return run_cmd(&cmd, work_dir="src/clay")
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

fix_kqueue_package_name :: proc () -> (ok: bool) {
    cmd: Command

    // macos bullshit
    append(&cmd, "sed", "-i", "", "s/package kqueue/package _kqueue/", "src/http/nbio/_kqueue/kqueue.odin")

    return run_cmd(&cmd)
}


prepare :: proc () -> (ok: bool, err: NoExecutableError) {
    if os2.is_file("build") {
        os2.remove("build")
    }

    os2.make_directory("build")

    if !executable_exists("git") {
        return false, NoExecutableError { message = "Git is needed to compile this program." }
    }

    if !executable_exists("g++") && !executable_exists("cl") {
        return false, NoExecutableError { message = "g++ or MSVC is needed to compile this program."}
    }

    if !executable_exists("ar") && !executable_exists("lib") {
        return false, NoExecutableError { message = "ar or lib is needed to compile this program."}
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

    when ODIN_DEBUG {
        append(&cmd, "-debug")

        when ODIN_OS == .Linux {
            append(&cmd, "-sanitize:address")
        }
    }

    when ODIN_OS == .Windows {
        out := strings.concatenate({ out, ".exe" })
    }

    when ODIN_OS == .Windows {
        append(&cmd, fmt.tprintf("-extra-linker-flags:/LIBPATH:%s /LIBPATH:%s %s", BUILD_PATH, "vcpkg\\installed\\x64-windows-static\\lib", "libssl.lib libcrypto.lib"))
    } else {
        append(&cmd, fmt.tprintf("-extra-linker-flags:-L%s %s", BUILD_PATH, "-lstdc++ -lm -lssl -lcrypto"))
    }

    append(&cmd, fmt.tprintf("-out:%s", pt.join({ BUILD_PATH, out })))

    return cmd
}

clone_submodules :: proc () -> (ok: bool) {
    cmd: Command

    append(&cmd, "git", "submodule", "update", "--init")

    return run_cmd(&cmd, silent=true)
}

main :: proc () {
    // every 'when ODIN_OS == .Windows' makes me die a little bit
    // inside

    ok, err := prepare()
    if !ok {
        fmt.eprintfln("ERROR: %s", err.message)
        os2.exit(1)
    }

    if !os2.is_file(pt.join({ BUILD_PATH, SOCKETIO_LIB_NAME })) {
        if !compile_socketio_cpp() {
            fmt.eprintln("ERROR: Error compiling socketio-client. Aborting")
            os2.exit(1)
        }
    }

    when ODIN_OS == .Windows {
        clay_lib_name := "clay.lib"
    } else {
        clay_lib_name := "clay.a"
    }

    if !os2.is_file(fmt.tprintf("src/clay/%s", clay_lib_name)) {
        if !compile_clay() {
            fmt.eprintln("ERROR: Error compiling clay. Aborting")
            os2.exit(1)
        }
    }

    if !clone_submodules() {
        fmt.eprintln("ERROR: Failed cloning submodules")
        os2.exit(1)
    }

    when ODIN_OS == .Darwin {
        if !fix_kqueue_package_name() {
            os2.exit(1)
        }
    }

    cmd := make_build_cmd("src", "go")
    append(&cmd, "-error-pos-style:unix")

    when !ODIN_DEBUG {
        strict_style_flags(&cmd)
        optimization_flags(&cmd)
    }

    if !run_cmd(&cmd) {
        os2.exit(1)
    }
}
