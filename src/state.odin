package main

import "base:runtime"

GLOBAL_STATE := struct {
    player: Player,
    assets: Assets,
    objects: [dynamic]WorldObject,
    board_objects: [dynamic]BoardWorldObject,
    room_object: RoomWorldObject,

    ctx: runtime.Context,
} {}

state_free :: proc () {
    delete(GLOBAL_STATE.objects)
    delete(GLOBAL_STATE.board_objects)
}
