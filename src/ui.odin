package main

import "core:slice"
import "core:log"
import "core:fmt"
import "core:os/os2"
import cl "clay"
import rl "vendor:raylib"

ui_error_handler :: proc "c" (error_data: cl.ErrorData) {
    context = GLOBAL_STATE.ctx

    log.errorf("UI Error: %s: %s", error_data.errorType, error_data.errorText)
}

ui_init :: proc () {
    log.info("Initilizing UI...")

    min_arena_size := cl.MinMemorySize()
    memory := make([]byte, min_arena_size)

    GLOBAL_STATE.ui_arena = cl.CreateArenaWithCapacityAndMemory(
        uint(min_arena_size), raw_data(memory))

    cl.Initialize(
        GLOBAL_STATE.ui_arena,
        { f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight()) },
        { handler = ui_error_handler }
    )

    cl.SetDebugModeEnabled(false)

    cl.SetMeasureTextFunction(measure_text, nil)
}

ui_deinit :: proc () {
    log.info("Deinitilizing UI...")

    delete(slice.from_ptr(GLOBAL_STATE.ui_arena.memory, int(GLOBAL_STATE.ui_arena.capacity)))
}

ui_update :: proc () {
    cl.SetPointerState(rl.GetMousePosition(), rl.IsMouseButtonPressed(.LEFT))
    cl.SetLayoutDimensions({ f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight()) })
}

ui_button :: proc (text: string, callback: proc ()) {
    if cl.UI()({
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingFixed(50),
            },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
        },
        backgroundColor = cl.Hovered() ? {176, 215, 255, 255} : {},
    }) {
        cl.OnHover(proc "c" (id: cl.ElementId, pointer: cl.PointerData, user_data: rawptr) {
            context = GLOBAL_STATE.ctx

            if pointer.state == .PressedThisFrame {
                (proc ())(user_data)()
            }
        }, rawptr(callback))
        cl.TextDynamic(text, &{
            textColor = {255,255,255,255},
            fontSize = 32,
        })
    }
}

ui_create_main_menu_layout :: proc () -> cl.ClayArray(cl.RenderCommand) {
    cl.BeginLayout()

    if cl.UI()({
        layout = {
            padding = { 12, 0, 0, 0 },
            sizing = {
                height = cl.SizingGrow({}),
            },
        },
    }) {
        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingFixed(300),
                    height = cl.SizingGrow({}),
                },
                childAlignment = { y = .Bottom },
                layoutDirection = .TopToBottom,
                padding = { 0, 0, 0, 28 },
            },
            backgroundColor = { 45, 49, 66, 255 },
            border = {
                color = {176, 215, 255, 255},
                width = { 3, 0, 0, 0, 0 },
            },
        }) {
            ui_button("Play Local", proc () {
                board_controller_change_type(GLOBAL_STATE.board_controllers[0], .LOCAL)
                player_change_state_roaming()
            })
            ui_button("Play AI", proc () {
                board_controller_change_type(GLOBAL_STATE.board_controllers[0], .GTP)
                player_change_state_roaming()
            })
            ui_button("Exit", proc () {
                GLOBAL_STATE.should_exit = true
            })
        }
    }

    return cl.EndLayout()
}
