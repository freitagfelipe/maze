package maze

import "core:math/rand"
import "core:container/queue"
import "vendor:raylib"
import "../dsu"
import "../consts"

MatrixPos :: struct {
    row: i32,
    column: i32,
}

get_grid_idx_from_pos :: proc(row: i32, column: i32) -> i32 {
    return row * consts.GRID_COLUMNS + column
}

CellType :: enum {
    Floor,
    Wall,
    // These below are essentially `CellType::Floor` but with different colors.
    NotProcessedFloor,
    StartFloor,
    EndFloor,
}

Maze :: struct {
    maze: [consts.GRID_SIZE]CellType,
    start: MatrixPos,
    end: MatrixPos,
    set: dsu.Dsu,
    cell_pos_to_set_key: [consts.GRID_SIZE]i32,
    random_maze_walls: queue.Queue(MatrixPos),
}

@(private)
get_all_maze_walls_pos_shuffled :: proc() -> queue.Queue(MatrixPos) {
    random_pos := make([dynamic]MatrixPos, 0, consts.GRID_SIZE)
    defer delete(random_pos)

    for row_idx in 1..<consts.GRID_ROWS - 1 {
        for column_idx in 1..<consts.GRID_COLUMNS - 1 {
            if row_idx % 2 == 1 && column_idx % 2 == 1 {
                continue
            }

            if row_idx % 2 == 0 && column_idx % 2 == 0 {
                continue
            }

            append(
                &random_pos,
                MatrixPos {
                    row = i32(row_idx),
                    column = i32(column_idx),
                },
            )
        }
    }

    for i := len(random_pos) - 1; i > 0; i -= 1 {
        j := rand.int31() % i32(i + 1)

        random_pos[i], random_pos[j] = random_pos[j], random_pos[i]
    }

    q: queue.Queue(MatrixPos)

    queue.init(&q, len(random_pos))

    for pos in random_pos {
        queue.push_back(&q, pos)
    }
    
    return q
}

new :: proc() -> (self: Maze) {
    dsu_size := 0

    for row_idx in 1..<consts.GRID_ROWS - 1 {
        for column_idx in 1..<consts.GRID_COLUMNS - 1 {
            if row_idx % 2 == 1 && column_idx % 2 == 1 {
                dsu_size += 1

                continue
            }
        }
    }

    self = Maze {
        set = dsu.new(dsu_size),
        start = MatrixPos {
            row = 0,
            column = 1,
        },
        end = MatrixPos {
            row = consts.GRID_ROWS - 1,
            column = consts.GRID_COLUMNS - 2,
        },
        random_maze_walls = get_all_maze_walls_pos_shuffled(),
    }

    set_key := 0

    for row_idx in 0..<consts.GRID_ROWS {
        for column_idx in 0..<consts.GRID_COLUMNS {
            grid_cell_idx := get_grid_idx_from_pos(i32(row_idx), i32(column_idx))

            self.cell_pos_to_set_key[grid_cell_idx] = -1

            cell_type := CellType.Wall

            if row_idx % 2 == 1 && column_idx % 2 == 1 {
                cell_type = CellType.NotProcessedFloor

                self.cell_pos_to_set_key[grid_cell_idx] = i32(set_key)

                set_key += 1
            }

            self.maze[grid_cell_idx] = cell_type
        }
    }

    start_pos_idx := self.start.row * consts.GRID_COLUMNS + self.start.column
    end_pos_idx := self.end.row * consts.GRID_COLUMNS + self.end.column

    self.maze[start_pos_idx] = CellType.StartFloor
    self.maze[end_pos_idx] = CellType.EndFloor

    return
}

// Returns `true` if there are still updates to be made.
update :: proc(self: ^Maze) -> bool {
    wall_pos, pop_success := queue.pop_front_safe(&self.random_maze_walls)

    assert(pop_success)

    wall_row, wall_column := wall_pos.row, wall_pos.column
    wall_grid_idx := get_grid_idx_from_pos(wall_pos.row, wall_pos.column)

    // It is a vertical wall.
    if wall_row % 2 == 1 && wall_column % 2 == 0 {
        left_grid_cell_idx := get_grid_idx_from_pos(wall_row, wall_column - 1)
        right_grid_cell_idx := get_grid_idx_from_pos(wall_row, wall_column + 1)

        // These idx accesses below are safe because we never get the border walls.
        left_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[left_grid_cell_idx])
        right_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[right_grid_cell_idx])

        if left_cell_key != right_cell_key {
            dsu.join(&self.set, left_cell_key, right_cell_key)

            self.maze[wall_grid_idx] = CellType.Floor
            
            assert(
                self.maze[left_grid_cell_idx] != CellType.Wall &&
                self.maze[right_grid_cell_idx] != CellType.Wall
            )

            self.maze[left_grid_cell_idx] = CellType.Floor
            self.maze[right_grid_cell_idx] = CellType.Floor
        }
    }

    // It is a horizontal wall.
    if wall_row % 2 == 0 && wall_column % 2 == 1 {
        above_grid_cell_idx := get_grid_idx_from_pos(wall_row - 1, wall_column)
        below_grid_cell_idx := get_grid_idx_from_pos(wall_row + 1, wall_column)

        // These idx accesses below are safe because we never get the border walls.
        above_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[above_grid_cell_idx])
        below_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[below_grid_cell_idx])

        if above_cell_key != below_cell_key {
            dsu.join(&self.set, above_cell_key, below_cell_key)

            self.maze[wall_grid_idx] = CellType.Floor

            assert(
                self.maze[above_grid_cell_idx] != CellType.Wall &&
                self.maze[below_grid_cell_idx] != CellType.Wall
            )

            self.maze[above_grid_cell_idx] = CellType.Floor
            self.maze[below_grid_cell_idx] = CellType.Floor
        }
    }

    first_key_weight := dsu.key_group_weight(&self.set, 0)

    return queue.len(self.random_maze_walls) != 0 && first_key_weight < i32(self.set.size)
}

drop :: proc(self: ^Maze) {
    dsu.drop(&self.set)
    queue.destroy(&self.random_maze_walls)
}

draw :: proc(self: Maze) {
    for row_idx in 0..<consts.GRID_ROWS {
        for column_idx in 0..<consts.GRID_COLUMNS {
            color: raylib.Color

            grid_cell_idx := get_grid_idx_from_pos(i32(row_idx), i32(column_idx))

            switch self.maze[grid_cell_idx] {
            case .Floor: color = raylib.WHITE
            case .NotProcessedFloor, .Wall: color = raylib.BLACK
            case .StartFloor: color = raylib.BLUE
            case .EndFloor: color = raylib.GREEN
            }

            raylib.DrawRectangle(
                i32(column_idx * consts.SQUARE_SIZE),
                i32(row_idx * consts.SQUARE_SIZE),
                consts.SQUARE_SIZE,
                consts.SQUARE_SIZE,
                color,
            )
        }
    }
}

