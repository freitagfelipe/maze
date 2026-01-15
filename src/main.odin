package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:raylib"
import "consts"
import "maze"
import "path_algorithms/a_star"

PathAlgorithm :: enum {
    AStar,
}

AppState :: enum {
    GeneratingMaze,
    MazeGenerated,
    SolvingMaze,
    MazeSolved,
}

App :: struct {
    state: AppState,
    paused: bool,
    started_solving: bool,
    maze: maze.Maze,
    path_algorithm: PathAlgorithm,
    a_star: Maybe(a_star.AStar),
}

keyboard_input_handler :: proc(app: ^App) {
    #partial switch app.state {
    case .GeneratingMaze:
        #partial switch raylib.GetKeyPressed() {
        case raylib.KeyboardKey.P:
            if app.paused {
                raylib.SetWindowTitle("Maze - Generating")
            } else {
                raylib.SetWindowTitle("Maze - Generating (paused)")
            }

            app.paused = !app.paused
        }
    case .MazeGenerated:
        #partial switch raylib.GetKeyPressed() {
        case raylib.KeyboardKey.ONE: app.path_algorithm = PathAlgorithm.AStar
        case raylib.KeyboardKey.ENTER:
            app.state = AppState.SolvingMaze

            raylib.SetWindowTitle("Maze - Solving")
            raylib.SetTargetFPS(consts.TARGET_SOLVING_FPS)
        }
    case .SolvingMaze:
        #partial switch raylib.GetKeyPressed() {
        case raylib.KeyboardKey.P:
            if app.paused {
                raylib.SetWindowTitle("Maze - Solving")
            } else {
                raylib.SetWindowTitle("Maze - Solving (paused)")
            }

            app.paused = !app.paused
        }
    }
}

generating_maze_screen :: proc(app: ^App) {
    keyboard_input_handler(app)

    raylib.BeginDrawing()

    raylib.ClearBackground(raylib.BLACK)

    maze.draw(app.maze)

    raylib.EndDrawing()

    if app.paused {
        return
    }

    any_updates_left := maze.update(&app.maze)

    if !any_updates_left {
        app.state = AppState.MazeGenerated

        raylib.SetWindowTitle("Maze - Generated")
    }
}

generated_maze_screen :: proc(app: ^App) {
    keyboard_input_handler(app)

    raylib.BeginDrawing()

    raylib.ClearBackground(raylib.BLACK)

    maze.draw(app.maze)

    raylib.EndDrawing()
}

solving_maze_screen :: proc(app: ^App) -> runtime.Allocator_Error {
    switch app.path_algorithm {
    case .AStar:
        app.a_star = a_star.new(app.maze.start, app.maze.end) or_return
    }

    for !raylib.WindowShouldClose() {
        raylib.BeginDrawing()

        raylib.ClearBackground(raylib.BLACK)

        maze.draw(app.maze)

        any_updates_left: bool

        switch app.path_algorithm {
        case .AStar:
            algorithm, ok := &app.a_star.?

            if !ok {
                fmt.println("A* should be initialized at this point")

                os.exit(1)
            }

            last_iterated_node_pos: maze.MatrixPos

            if !app.paused {
                any_updates_left, last_iterated_node_pos = a_star.update(algorithm, app.maze.maze) or_return
            }

            a_star.draw(algorithm, last_iterated_node_pos)
        }

        if !any_updates_left {
            app.state = AppState.MazeSolved

            raylib.SetWindowTitle("Maze - Solved")

            break
        }

        raylib.EndDrawing()
    }

    return .None
}

maze_solved_screen :: proc(app: ^App) {
    raylib.BeginDrawing()

    raylib.ClearBackground(raylib.BLACK)

    maze.draw(app.maze)

    switch app.path_algorithm {
    case .AStar:
        algorithm, ok := &app.a_star.?

        if !ok {
            fmt.println("A* should be initialized at this point")

            os.exit(1)
        }

        a_star.draw(algorithm, app.maze.end)
    }

    raylib.EndDrawing()
}

main :: proc() {
    raylib.InitWindow(
        consts.SCREEN_WIDTH,
        consts.SCREEN_HEIGHT,
        "Maze - Generating"
    )
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(consts.TARGET_GENERAING_MAZE_FPS)
    
    app := App {
        state = AppState.GeneratingMaze,
        maze = maze.new()
    }
    defer maze.drop(&app.maze)
    defer if algorithm, ok := app.a_star.?; ok {
        a_star.drop(&algorithm)
    }

    for !raylib.WindowShouldClose() {
        switch app.state {
        case .GeneratingMaze: generating_maze_screen(&app)
        case .MazeGenerated: generated_maze_screen(&app)
        case .SolvingMaze:
            if err := solving_maze_screen(&app); err != nil {
                fmt.println("Allocator_Error on solving maze")

                os.exit(1)
            }
        case .MazeSolved: maze_solved_screen(&app)
        }
    }
}
