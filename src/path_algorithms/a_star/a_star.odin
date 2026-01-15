package a_star

import "core:fmt"
import "base:runtime"
import "core:math"
import "core:container/priority_queue"
import "vendor:raylib"
import "../../consts"
import "../../maze"

@(private)
available_pos :: proc(pos: maze.MatrixPos) -> [dynamic]maze.MatrixPos {
    directions := make([dynamic]maze.MatrixPos)

    if pos.row - 1 > 0 {
        append(&directions, maze.MatrixPos{pos.row - 1, pos.column})
    }

    if pos.row + 1 < consts.GRID_ROWS {
        append(&directions, maze.MatrixPos{pos.row + 1, pos.column})
    }

    if pos.column - 1 > 0 {
        append(&directions, maze.MatrixPos{pos.row, pos.column - 1})
    }

    if pos.column + 1 < consts.GRID_COLUMNS {
        append(&directions, maze.MatrixPos{pos.row, pos.column + 1})
    }

    return directions
}

@(private)
h :: proc(pos, end: maze.MatrixPos) -> i32 {
    return math.abs(end.row - pos.row) + math.abs(end.column - pos.column)
}

Node :: struct {
    pos: maze.MatrixPos,
    parent_pos: maze.MatrixPos,
    g: i32,
    h: i32,
}

@(private)
get_score :: proc(self: Node) -> i32 {
    return self.g + self.h
}

AStar :: struct {
    start: maze.MatrixPos,
    end: maze.MatrixPos,
    open_set: priority_queue.Priority_Queue(Node),
    closed_set: map[maze.MatrixPos]maze.MatrixPos,
    // Holds the draw of the algorithm's general steps.
    main_texture: raylib.RenderTexture2D,
}

new :: proc(start, end: maze.MatrixPos) -> (self: AStar, error: runtime.Allocator_Error) {
    using consts

    self = AStar {
        start = start,
        end = end,
        closed_set = make(map[maze.MatrixPos]maze.MatrixPos),
        main_texture = raylib.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT),
    }

    ord_fn :: proc(a, b: Node) -> bool {
        return get_score(a) < get_score(b)
    }

    swap_fn :: proc(items: []Node, a, b: int) {
        items[a], items[b] = items[b], items[a]
    }
    
    priority_queue.init(
        &self.open_set,
        ord_fn,
        swap_fn,
    ) or_return

    priority_queue.push(
        &self.open_set,
        Node {
            pos = start,
            parent_pos = {-1, -1},
            g = 0,
            h = h(start, end)
        }
    ) or_return

    return
}

update :: proc(
    self: ^AStar,
    m: [consts.GRID_ROWS * consts.GRID_COLUMNS]maze.CellType,
) -> (bool, maze.MatrixPos, runtime.Allocator_Error) {
    assert(priority_queue.len(self.open_set) != 0)

    // Node that has the smaller `g`.
    node := priority_queue.pop(&self.open_set)

    if node.pos == self.end {
        self.closed_set[self.end] = node.parent_pos

        return false, self.end, .None
    }

    if _, ok := self.closed_set[node.pos]; ok {
        return priority_queue.len(self.open_set) != 0, node.pos, .None
    }

    raylib.BeginTextureMode(self.main_texture)

    self.closed_set[node.pos] = node.parent_pos

    raylib.DrawRectangle(
        i32(node.pos.column * consts.SQUARE_SIZE),
        i32((consts.GRID_ROWS - node.pos.row - 1) * consts.SQUARE_SIZE),
        consts.SQUARE_SIZE,
        consts.SQUARE_SIZE,
        raylib.RED
    )

    available_positions := available_pos(node.pos)
    defer delete(available_positions)

    for available_position in available_positions {
        available_position_grid_cell_idx := maze.get_grid_idx_from_pos(available_position.row, available_position.column)

        if m[available_position_grid_cell_idx] == maze.CellType.Wall {
            continue
        }
        
        if e, ok := self.closed_set[available_position]; ok {
            continue
        }
        
        priority_queue.push(
            &self.open_set,
            Node {
                pos = available_position,
                parent_pos = node.pos,
                g = node.g + 1,
                h = h(available_position, self.end),
            }
        )

        raylib.DrawRectangle(
            i32(available_position.column * consts.SQUARE_SIZE),
            i32((consts.GRID_ROWS - available_position.row - 1) * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.ORANGE
        )
    }

    raylib.EndTextureMode()

    return priority_queue.len(self.open_set) != 0, node.pos, .None
}

drop :: proc(self: ^AStar) {
    priority_queue.destroy(&self.open_set)
    delete(self.closed_set)
    raylib.UnloadRenderTexture(self.main_texture)
}

draw :: proc(self: ^AStar, last_iterated_node_pos: maze.MatrixPos) {
    raylib.DrawTexture(self.main_texture.texture, 0, 0, raylib.WHITE)

    current_pos := last_iterated_node_pos

    for current_pos != {-1, -1} {
        raylib.DrawRectangle(
            i32(current_pos.column * consts.SQUARE_SIZE),
            i32(current_pos.row * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.GREEN,
        )
        
        current_pos = self.closed_set[current_pos]
    }
}

