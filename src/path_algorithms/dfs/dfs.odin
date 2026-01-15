package dfs

import "vendor:raylib"
import "../../consts"
import "../../maze"

DfsNodeStep :: enum {
    Unvisited,
    Processing,
    Processed,
}

Node :: struct {
    pos: maze.MatrixPos,
    parent_pos: maze.MatrixPos,
    neighborhood_processing_step: i32,
    dfs_step: DfsNodeStep,
}

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


Dfs :: struct {
    start: maze.MatrixPos,
    end: maze.MatrixPos,
    node_info: map[maze.MatrixPos]Node,
    stack: [dynamic]maze.MatrixPos,
    // Holds the draw of the algorithm's general steps.
    main_texture: raylib.RenderTexture2D,
}

new :: proc(start, end: maze.MatrixPos) -> (self: Dfs) {
    self = Dfs {
        start = start,
        end = end,
        node_info = make(map[maze.MatrixPos]Node),
        stack = make([dynamic]maze.MatrixPos),
        main_texture = raylib.LoadRenderTexture(consts.SCREEN_WIDTH, consts.SCREEN_HEIGHT),
    }

    append(&self.stack, start)

    self.node_info[start] = Node {
        pos = start,
        parent_pos =  {-1, -1},
        neighborhood_processing_step = 0,
        dfs_step = .Processing,
    }

    return
}

update :: proc(
    self: ^Dfs,
    m: [consts.GRID_ROWS * consts.GRID_COLUMNS]maze.CellType
) -> (bool, maze.MatrixPos) {
    assert(len(self.stack) != 0)

    node_pos := self.stack[len(self.stack) - 1]
    node, node_exists := &self.node_info[node_pos]

    assert(node_exists)

    if node.pos == self.end {
        return false, self.end
    }

    step := node.neighborhood_processing_step

    available_positions := available_pos(node.pos)
    defer delete(available_positions)

    maybe_next_node_pos: Maybe(maze.MatrixPos)

    for available_position in available_positions[step:] {
        node.neighborhood_processing_step += 1

        available_position_grid_cell_idx := maze.get_grid_idx_from_pos(available_position.row, available_position.column)

        if available_position in self.node_info {
            continue
        }

        if m[available_position_grid_cell_idx] == maze.CellType.Wall {
            continue
        }

        maybe_next_node_pos = available_position

        break
    }

    next_node_pos, next_node_pos_exists := maybe_next_node_pos.?

    if int(step) == len(available_positions) || !next_node_pos_exists {
        raylib.BeginTextureMode(self.main_texture)

        raylib.DrawRectangle(
            i32(node.pos.column * consts.SQUARE_SIZE),
            i32((consts.GRID_ROWS - node.pos.row - 1) * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.RED,
        )

        raylib.EndTextureMode()

        pop(&self.stack)

        node.dfs_step = .Processed

        return len(self.stack) != 0, node.parent_pos
    }

    append(&self.stack, next_node_pos)

    self.node_info[next_node_pos] = Node {
        pos = next_node_pos,
        parent_pos = node.pos,
        neighborhood_processing_step = 0,
        dfs_step = .Processing,
    }

    return len(self.stack) != 0, next_node_pos
}

drop :: proc(self: ^Dfs) {
    delete(self.node_info)
    delete(self.stack)
    raylib.UnloadRenderTexture(self.main_texture)
}

draw :: proc(self: ^Dfs, last_iterated_node_pos: maze.MatrixPos) {
    raylib.DrawTexture(self.main_texture.texture, 0, 0, raylib.WHITE)

    current_pos := last_iterated_node_pos

    for current_pos != {-1, -1} {
        node, node_exists := self.node_info[current_pos]

        assert(node_exists)
        assert(node.dfs_step == .Processing)

        raylib.DrawRectangle(
            i32(current_pos.column * consts.SQUARE_SIZE),
            i32(current_pos.row * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.GREEN,
        )
        
        current_pos = node.parent_pos
    }
}
