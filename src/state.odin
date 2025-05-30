package main

import "base:runtime"
import "gtp"

GLOBAL_STATE := struct {
    player: Player,
    assets: Assets,
    objects: [dynamic]WorldObject,
    room_object: RoomWorldObject,

    board_controllers: [dynamic]^BoardController,

    ctx: runtime.Context,
} {}

state_free :: proc () {
    delete(GLOBAL_STATE.objects)
    delete(GLOBAL_STATE.board_controllers)
}
