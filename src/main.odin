package main

import "core:math/rand"
import "vendor:raylib"
import "consts"
import "maze"

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
        case raylib.KeyboardKey.ENTER:
            app.state = AppState.SolvingMaze

            raylib.SetWindowTitle("Maze - Solving")
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

main :: proc() {
    using consts

    raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Maze - Generating")

    raylib.SetTargetFPS(TARGET_FPS)
    
    app := App {
        state = AppState.GeneratingMaze,
        maze = maze.new()
    }

    for !raylib.WindowShouldClose() {
        // TODO: remove #partial once everything is implemented.
        #partial switch app.state {
        case .GeneratingMaze: generating_maze_screen(&app)
        case .MazeGenerated: generated_maze_screen(&app)
        }
    }

    raylib.CloseWindow()

}
