package main

import "core:mem"
import "gtp"
import "core:strings"
import "core:fmt"

MoveCommand :: proc (controller: ^BoardController, x, y: u32)
PassCommand :: proc (controller: ^BoardController)
ResignCommand :: proc (controller: ^BoardController)

CONTROLLER_LOCAL_COMMANDS :: BoardControllerCommands{
    move = proc (controller: ^BoardController, x, y: u32) {
        board_set(controller.board, x, y)

        if controller.side == .WHITE {
            controller.side = .BLACK
        } else {
            controller.side = .WHITE
        }
    }
}

CONTROLLER_GTP_COMMANDS :: BoardControllerCommands{
    move = proc (controller: ^BoardController, x, y: u32) {
        board_set(controller.board, x, y)
        gtp.client_make_move(controller.client.(^gtp.GTPClient), x, y, controller.side)
    }
}

ControllerClientType :: enum {
    LOCAL,
    GTP,
    OGS,
}

BoardControllerCommands :: struct {
    move: MoveCommand,
    pass: PassCommand,
    resign: ResignCommand,
}

BoardController :: struct {
    object: ^BoardWorldObject,
    board: ^Board,
    side: gtp.Side,
    commands: BoardControllerCommands,
    client: union {
        ^gtp.GTPClient,
        ^OGSSession,
    },
}

board_controller_new :: proc (board_size: u32, board_transform: WorldTransform) -> (board_controller: ^BoardController, ok: bool) {
    board_controller = new(BoardController)

    if board, err := board_new(board_size); err != nil {
        return
    } else {
        board_controller.board = board
    }

    board_controller.object = world_board_world_object_new() or_return
    board_controller.object.transform = board_transform

    board_controller.side = .BLACK

    ok = true
    return
}

board_configure_client_type :: proc (controller: ^BoardController, type: ControllerClientType) {
    switch type {
    case .LOCAL:
        controller.commands = CONTROLLER_LOCAL_COMMANDS
    case .GTP:
        controller.commands = CONTROLLER_GTP_COMMANDS
        client, _ := gtp.client_new(PachiDefault)
        client.user_data = controller
        controller.client = client
        gtp.client_configure(client, controller.board.size, controller.board.komi, proc (command, response: string, user_data: rawptr) {
            defer delete(command)

            controller := (^BoardController)(user_data)

            if strings.starts_with(command, gtp.COMMAND_GENMOVE) {
                coord := gtp.gtp_coord_to_number(response, controller.board.size)
                board_set(controller.board, coord.x, coord.y)
            }
        })
    case .OGS:
    }
}

board_controller_free_all :: proc () {
    for controller in GLOBAL_STATE.board_controllers {
        board_controller_free(controller)
    }
}

board_controller_free :: proc (controller: ^BoardController) {
    world_board_world_object_free(controller.object)
    board_delete(controller.board)

    switch c in controller.client {
    case ^gtp.GTPClient:
        gtp.client_delete(controller.client.(^gtp.GTPClient))
    case ^OGSSession:
        ogs_session_destroy(controller.client.(^OGSSession))
    }

    free(controller)
}
