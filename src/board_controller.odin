package main

import "gtp"
import "core:strings"
import "core:log"
import "core:sync/chan"

MoveCommand :: proc (controller: ^BoardController, x, y: u32) -> BoardSetError
PassCommand :: proc (controller: ^BoardController)
ResignCommand :: proc (controller: ^BoardController)

CONTROLLER_NONE_COMMANDS :: BoardControllerCommands{
    move = proc (_: ^BoardController, _, _: u32) -> BoardSetError {
        return .NOT_EMPTY
    },
    pass = proc (_: ^BoardController) {},
    resign = proc (_: ^BoardController) {},
}

CONTROLLER_LOCAL_COMMANDS :: BoardControllerCommands{
    move = proc (controller: ^BoardController, x, y: u32) -> BoardSetError {
        board_set(controller.board, x, y) or_return

        if controller.side == .WHITE {
            controller.side = .BLACK
        } else {
            controller.side = .WHITE
        }

        return .NIL
    },
    pass = proc (controller: ^BoardController) {
        if controller.side == .WHITE {
            controller.side = .BLACK
        } else {
            controller.side = .WHITE
        }
    },
}

CONTROLLER_GTP_COMMANDS :: BoardControllerCommands{
    move = proc (controller: ^BoardController, x, y: u32) -> BoardSetError {
        board_set(controller.board, x, y) or_return
        gtp.client_make_move(controller.client.(^gtp.GTPClient), x, y, controller.side)

        return .NIL
    },
}

ControllerClientType :: enum {
    NONE,
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
    move_queue: chan.Chan([2]u32, .Both),
    client: union {
        ^gtp.GTPClient,
        ^OGSSession,
    },
}

board_controller_new :: proc (board_size: u32, board_transform: WorldTransform, type: ControllerClientType) -> (board_controller: ^BoardController, ok: bool) {
    board_controller = new(BoardController)

    if board, err := board_new(board_size); err != nil {
        return
    } else {
        board_controller.board = board
    }

    board_controller.object = world_board_world_object_new() or_return
    board_controller.object.transform = board_transform

    ch, err := chan.create(type_of(board_controller.move_queue), 8, context.allocator)
    if err != nil { return }
    board_controller.move_queue = ch
    board_controller.side = .BLACK

    board_configure_client_type(board_controller, type)

    ok = true
    return
}

board_configure_client_type :: proc (controller: ^BoardController, type: ControllerClientType) {
    switch type {
    case .NONE:
        controller.commands = CONTROLLER_NONE_COMMANDS
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

                chan.send(controller.move_queue, coord)
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

    chan.destroy(controller.move_queue)

    switch c in controller.client {
    case ^gtp.GTPClient:
        gtp.client_delete(controller.client.(^gtp.GTPClient))
    case ^OGSSession:
        ogs_session_destroy(controller.client.(^OGSSession))
    }

    free(controller)
}

board_controllers_make_all_pending_moves :: proc () {
    for controller in GLOBAL_STATE.board_controllers {
        move := chan.try_recv(controller.move_queue) or_continue

        board_set(controller.board, move.x, move.y)
        sound_play_random(.STONE_PLACE_1, .STONE_PLACE_LAST)
    }
}

board_controller_change_type :: proc (controller: ^BoardController, new_type: ControllerClientType) {
    new_controller, ok := board_controller_new(controller.board.size, controller.object.transform, new_type)
    if !ok {
        log.error("ERROR: Failed creating new controller")
    }

    unordered_remove(&GLOBAL_STATE.board_controllers, 0)
    append(&GLOBAL_STATE.board_controllers, new_controller)
    board_controller_free(controller)
}
