package maze

import "core:math/rand"
import "vendor:raylib"
import "../dsu"
import "../consts"

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
    set: dsu.Dsu,
    cell_pos_to_set_key: [consts.GRID_SIZE]i32,
    random_maze_wall_indices: [dynamic][2]i32,
    random_maze_wall_indices_idx: i32,
}

new :: proc() -> (self: Maze) {
    using consts

    random_maze_indices := make([dynamic][2]i32, 0, GRID_SIZE)
    dsu_size := 0

    for row_idx in 1..<GRID_ROWS - 1 {
        for column_idx in 1..<GRID_COLUMNS - 1 {
            if row_idx % 2 == 1 && column_idx % 2 == 1 {
                dsu_size += 1

                continue
            }

            if row_idx % 2 == 0 && column_idx % 2 == 0 {
                continue
            }

            append(&random_maze_indices, [2]i32{i32(row_idx), i32(column_idx)})
        }
    }

    for i := len(random_maze_indices) - 1; i > 0; i -= 1 {
        j := rand.int31() % i32(i + 1)

        random_maze_indices[i], random_maze_indices[j] = random_maze_indices[j], random_maze_indices[i]
    }

    self = Maze {
        set = dsu.new(dsu_size),
        random_maze_wall_indices = random_maze_indices,
    }

    set_key := 0

    for row_idx in 0..<GRID_ROWS {
        for column_idx in 0..<GRID_COLUMNS {
            self.cell_pos_to_set_key[row_idx * GRID_COLUMNS + column_idx] = -1

            cell_type := CellType.Wall

            if row_idx % 2 == 1 && column_idx % 2 == 1 {
                cell_type = CellType.NotProcessedFloor

                self.cell_pos_to_set_key[row_idx * GRID_COLUMNS + column_idx] = i32(set_key)

                set_key += 1
            }

            self.maze[row_idx * GRID_COLUMNS + column_idx] = cell_type
        }
    }

    self.maze[1] = CellType.StartFloor
    self.maze[(GRID_ROWS - 1) * GRID_COLUMNS + GRID_COLUMNS - 2] = CellType.EndFloor

    return
}

// Returns `true` if there are still updates to be made.
update :: proc(self: ^Maze) -> bool {
    using consts

    wall_pos := self.random_maze_wall_indices[self.random_maze_wall_indices_idx]
    wall_row_idx := wall_pos[0]
    wall_column_idx := wall_pos[1]

    // It is a vertical wall.
    if wall_row_idx % 2 == 1 && wall_column_idx % 2 == 0 {
        left_cell_idx := wall_row_idx * GRID_COLUMNS + wall_column_idx - 1
        right_cell_idx := wall_row_idx * GRID_COLUMNS + wall_column_idx + 1

        // These idx accesses below are safe because we never get the border walls.
        left_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[left_cell_idx])
        right_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[right_cell_idx])

        if left_cell_key != right_cell_key {
            dsu.join(&self.set, left_cell_key, right_cell_key)

            self.maze[wall_row_idx * GRID_COLUMNS + wall_column_idx] = CellType.Floor
            
            assert(self.maze[left_cell_idx] != CellType.Wall && self.maze[right_cell_idx] != CellType.Wall)

            self.maze[left_cell_idx] = CellType.Floor
            self.maze[right_cell_idx] = CellType.Floor
        }
    }

    // It is a horizontal wall.
    if wall_row_idx % 2 == 0 && wall_column_idx % 2 == 1 {
        above_cell_idx := (wall_row_idx - 1) * GRID_COLUMNS + wall_column_idx
        below_cell_idx := (wall_row_idx + 1) * GRID_COLUMNS + wall_column_idx

        // These idx accesses below are safe because we never get the border walls.
        above_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[above_cell_idx])
        below_cell_key := dsu.find(&self.set, self.cell_pos_to_set_key[below_cell_idx])

        if above_cell_key != below_cell_key {
            dsu.join(&self.set, above_cell_key, below_cell_key)

            self.maze[wall_row_idx * GRID_COLUMNS + wall_column_idx] = CellType.Floor

            assert(self.maze[above_cell_idx] != CellType.Wall && self.maze[below_cell_idx] != CellType.Wall)

            self.maze[above_cell_idx] = CellType.Floor
            self.maze[below_cell_idx] = CellType.Floor
        }
    }

    self.random_maze_wall_indices_idx += 1
    
    first_key_weight := dsu.key_group_weight(&self.set, 0)

    return int(self.random_maze_wall_indices_idx) < len(self.random_maze_wall_indices) && first_key_weight < i32(self.set.size)
}

drop :: proc(self: ^Maze) {
    dsu.drop(&self.set)
}

draw :: proc(self: Maze) {
    using consts

    for row_idx in 0..<GRID_ROWS {
        for column_idx in 0..<GRID_COLUMNS {
            color: raylib.Color

            switch self.maze[row_idx * GRID_COLUMNS + column_idx] {
            case .Floor: color = raylib.WHITE
            case .NotProcessedFloor, .Wall: color = raylib.BLACK
            case .StartFloor: color = raylib.GREEN
            case .EndFloor: color = raylib.RED
            }

            raylib.DrawRectangle(
                i32(column_idx * SQUARE_SIZE),
                i32(row_idx * SQUARE_SIZE),
                SQUARE_SIZE,
                SQUARE_SIZE,
                color,
            )
        }
    }
}
