package a_star

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:container/priority_queue"
import "vendor:raylib"
import "../../consts"
import "../../maze"

@(private)
h :: proc(pos, end: maze.MatrixPos) -> i32 {
    return i32(math.abs(end[0] - pos[0]) + math.abs(end[1] - pos[1]))
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
    // For drawing purposes only.
    path_end: maze.MatrixPos,
}

new :: proc(start, end: maze.MatrixPos) -> (self: AStar, error: runtime.Allocator_Error) {
    self = AStar {
        start = start,
        end = end,
        closed_set = make(map[maze.MatrixPos]maze.MatrixPos),
        main_texture = raylib.LoadRenderTexture(consts.SCREEN_WIDTH, consts.SCREEN_HEIGHT),
        path_end = start,
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
        priority_queue.default_swap_proc(Node),
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
) -> (bool, runtime.Allocator_Error) {
    assert(priority_queue.len(self.open_set) != 0)

    // Node that has the smaller `g`.
    node := priority_queue.pop(&self.open_set)

    if node.pos == self.end {
        self.closed_set[self.end] = node.parent_pos
        self.path_end = self.end

        return false, .None
    }

    if _, ok := self.closed_set[node.pos]; ok {
        self.path_end = node.pos

        return priority_queue.len(self.open_set) != 0, .None
    }

    raylib.BeginTextureMode(self.main_texture)

    self.closed_set[node.pos] = node.parent_pos

    raylib.DrawRectangle(
        i32(node.pos[1] * consts.SQUARE_SIZE),
        i32((consts.GRID_ROWS - node.pos[0] - 1) * consts.SQUARE_SIZE),
        consts.SQUARE_SIZE,
        consts.SQUARE_SIZE,
        raylib.RED
    )

    available_directions := maze.AVAILABLE_DIRECTIONS

    for direction in available_directions {
        neighbor_pos := node.pos + direction

        grid_cell_idx := maze.get_grid_idx_from_pos(neighbor_pos)

        if !maze.is_pos_in_bounds(neighbor_pos) {
            continue
        }

        if m[grid_cell_idx] == maze.CellType.Wall {
            continue
        }

        if neighbor_pos in self.closed_set {
            continue
        }

        priority_queue.push(
            &self.open_set,
            Node {
                pos = neighbor_pos,
                parent_pos = node.pos,
                g = node.g + 1,
                h = h(neighbor_pos, self.end),
            }
        )

        raylib.DrawRectangle(
            i32(neighbor_pos[1] * consts.SQUARE_SIZE),
            i32((consts.GRID_ROWS - neighbor_pos[0] - 1) * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.ORANGE
        )
    }

    raylib.EndTextureMode()
    
    self.path_end = node.pos

    return priority_queue.len(self.open_set) != 0, .None
}

drop :: proc(self: ^AStar) {
    priority_queue.destroy(&self.open_set)
    delete(self.closed_set)
    raylib.UnloadRenderTexture(self.main_texture)
}

draw :: proc(self: ^AStar) {
    @(static)
    number_of_lookup_failures := 0


    raylib.DrawTexture(self.main_texture.texture, 0, 0, raylib.WHITE)

    current_pos := self.path_end

    for current_pos != {-1, -1} {
        raylib.DrawRectangle(
            i32(current_pos[1] * consts.SQUARE_SIZE),
            i32(current_pos[0] * consts.SQUARE_SIZE),
            consts.SQUARE_SIZE,
            consts.SQUARE_SIZE,
            raylib.GREEN,
        )

        // This should happen only on the first iteration.
        if !(current_pos in self.closed_set) {
            number_of_lookup_failures += 1

            fmt.eprintln(current_pos, "Not found in closed set")
            
            if number_of_lookup_failures > 1 {
                panic("More than one lookup failure happened")
            }

            break
        }
        
        current_pos = self.closed_set[current_pos]
    }
}

