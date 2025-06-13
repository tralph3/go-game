package main

import cl "clay"
import "base:runtime"

GLOBAL_STATE := struct {
    player: Player,
    assets: Assets,
    objects: [dynamic]WorldObject,
    room_object: RoomWorldObject,

    board_controllers: [dynamic]^BoardController,

    ui_arena: cl.Arena,

    should_exit: bool,

    ctx: runtime.Context,
} {}

state_free :: proc () {
    delete(GLOBAL_STATE.objects)
    delete(GLOBAL_STATE.board_controllers)
}
