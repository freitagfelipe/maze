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
    neighborhood_processing_step: int,
    dfs_step: DfsNodeStep,
}

Dfs :: struct {
    start: maze.MatrixPos,
    end: maze.MatrixPos,
    node_info: map[maze.MatrixPos]Node,
    stack: [dynamic]maze.MatrixPos,
    // Holds the draw of the algorithm's general steps.
    main_texture: raylib.RenderTexture2D,
    // For drawing purposes only.
    path_end: maze.MatrixPos,
}

new :: proc(start, end: maze.MatrixPos) -> (self: Dfs) {
    self = Dfs {
        start = start,
        end = end,
        node_info = make(map[maze.MatrixPos]Node),
        stack = make([dynamic]maze.MatrixPos),
        main_texture = raylib.LoadRenderTexture(consts.SCREEN_WIDTH, consts.SCREEN_HEIGHT),
        path_end = start,
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
) -> bool {
    assert(len(self.stack) != 0)

    node_pos := self.stack[len(self.stack) - 1]
    node, node_exists := &self.node_info[node_pos]

    assert(node_exists)

    if node.pos == self.end {
        self.path_end = self.end

        return false
    }

    step := node.neighborhood_processing_step

    maybe_next_node_pos: Maybe(maze.MatrixPos)
    available_directions := maze.AVAILABLE_DIRECTIONS

    for direction in available_directions[step:] {
        node.neighborhood_processing_step += 1;

        neighbor_pos := node.pos + direction

        if !maze.is_pos_in_bounds(neighbor_pos) {
            continue
        }

        // Already being processed or totally visited.
        if neighbor_pos in self.node_info {
            continue
        }

        grid_cell_idx := maze.get_grid_idx_from_pos(neighbor_pos)

        if m[grid_cell_idx] == maze.CellType.Wall {
            continue
        }

        maybe_next_node_pos = neighbor_pos

        break
    }

    next_node_pos, next_node_pos_exists := maybe_next_node_pos.?

    if int(step) == len(available_directions) || !next_node_pos_exists {
        raylib.BeginTextureMode(self.main_texture)

        raylib.DrawRectangle(
            i32(node.pos[1] * consts.SQUARE_SIZE),
            i32((consts.GRID_ROWS - node.pos[0] - 1) * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.RED,
        )

        raylib.EndTextureMode()

        pop(&self.stack)

        node.dfs_step = .Processed

        self.path_end = node.parent_pos

        return len(self.stack) != 0
    }

    append(&self.stack, next_node_pos)

    self.node_info[next_node_pos] = Node {
        pos = next_node_pos,
        parent_pos = node.pos,
        neighborhood_processing_step = 0,
        dfs_step = .Processing,
    }

    self.path_end = next_node_pos

    return len(self.stack) != 0
}

drop :: proc(self: ^Dfs) {
    delete(self.node_info)
    delete(self.stack)
    raylib.UnloadRenderTexture(self.main_texture)
}

draw :: proc(self: ^Dfs) {
    raylib.DrawTexture(self.main_texture.texture, 0, 0, raylib.WHITE)

    current_pos := self.path_end

    for current_pos != {-1, -1} {
        node, node_exists := self.node_info[current_pos]

        assert(node_exists)
        assert(node.dfs_step == .Processing)

        raylib.DrawRectangle(
            i32(current_pos[1] * consts.SQUARE_SIZE),
            i32(current_pos[0] * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.GREEN,
        )
        
        current_pos = node.parent_pos
    }
}
