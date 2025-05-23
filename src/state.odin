package main

import "base:runtime"

GLOBAL_STATE := struct {
    board: BoardObject,
    player: Player,
    assets: Assets,

    ctx: runtime.Context,
} {}
