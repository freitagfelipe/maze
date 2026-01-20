package main

import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:mem"
import "vendor:raylib"
import "consts"
import "maze"
import "path_algorithms/a_star"
import "path_algorithms/dfs"

PathAlgorithm :: enum {
    AStar,
    Dfs,
}

AppState :: enum {
    GeneratingMaze,
    MazeGenerated,
    SolvingMaze,
    MazeSolved,
}

App :: struct {
    state: AppState,
    is_paused: bool,
    started_solving: bool,
    maze: maze.Maze,
    path_algorithm: PathAlgorithm,
    a_star: Maybe(a_star.AStar),
    dfs: Maybe(dfs.Dfs),
}

get_window_title :: proc(app: ^App) -> string {
    // TODO: handle error
    builder := strings.builder_make() or_else panic("Alloc error")

    app_state_string: string

    switch app.state {
    case .GeneratingMaze: app_state_string = "Generating Maze"
    case .MazeGenerated: app_state_string = "Maze Generated"
    case .SolvingMaze: app_state_string = "Solving Maze"
    case .MazeSolved: app_state_string = "Maze Solved"
    }

    algorithm_string: string

    if app.state != AppState.GeneratingMaze {
        switch app.path_algorithm {
        case .AStar: algorithm_string = "- A*"
        case .Dfs: algorithm_string = "- DFS"
        }
    }

    paused_string: string

    if app.is_paused {
        paused_string = "(paused)"
    }

    window_title := fmt.sbprintf(
        &builder,
        "Maze Solver - %s %s %s",
        app_state_string,
        algorithm_string,
        paused_string,
    )

    return window_title
}

change_window_title :: proc(app: ^App) {
    new_window_title := get_window_title(app)
    defer delete(new_window_title)

    new_window_title_cstring := strings.clone_to_cstring(new_window_title)
    defer delete(new_window_title_cstring)

    raylib.SetWindowTitle(new_window_title_cstring)
}

keyboard_input_handler :: proc(app: ^App) {
    key_pressed := raylib.GetKeyPressed()
    should_change_window_title := false

    if key_pressed == raylib.KeyboardKey.P &&
       app.state != AppState.MazeGenerated &&
       app.state != AppState.MazeSolved
    {
        app.is_paused = !app.is_paused

        should_change_window_title = true
    }


    #partial switch app.state {
    case .MazeGenerated:
        #partial switch key_pressed {
        case raylib.KeyboardKey.ONE:
            app.path_algorithm = PathAlgorithm.AStar

            should_change_window_title = true
        case raylib.KeyboardKey.TWO:
            app.path_algorithm = PathAlgorithm.Dfs

            should_change_window_title = true
        case raylib.KeyboardKey.ENTER:
            app.state = AppState.SolvingMaze

            should_change_window_title = true

            raylib.SetTargetFPS(consts.TARGET_SOLVING_FPS)
        }
    }

    if should_change_window_title {
        change_window_title(app)
    }
}

generating_maze_screen :: proc(app: ^App) {
    keyboard_input_handler(app)

    raylib.BeginDrawing()

    raylib.ClearBackground(raylib.BLACK)

    maze.draw(app.maze)

    raylib.EndDrawing()

    if app.is_paused {
        return
    }

    any_updates_left := maze.update(&app.maze)

    if !any_updates_left {
        app.state = AppState.MazeGenerated

        change_window_title(app)
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
    case .Dfs:
        app.dfs = dfs.new(app.maze.start, app.maze.end)
    }

    for !raylib.WindowShouldClose() {
        keyboard_input_handler(app)

        raylib.BeginDrawing()

        raylib.ClearBackground(raylib.BLACK)

        maze.draw(app.maze)

        switch app.path_algorithm {
        case .AStar:
            algorithm := &app.a_star.? or_else panic("A* should be initialized at this point")

            a_star.draw(algorithm)
        case .Dfs:
            algorithm := &app.dfs.? or_else panic("Dfs should be initialized at this point")

            dfs.draw(algorithm)
        }

        raylib.EndDrawing()

        any_updates_left: bool

        if !app.is_paused {
            switch app.path_algorithm {
            case .AStar:
                algorithm := &app.a_star.? or_else panic("A* should be initialized at this point")

                any_updates_left = a_star.update(algorithm, app.maze.maze) or_return
            case .Dfs:
                algorithm := &app.dfs.? or_else panic("Dfs should be initialized at this point")

                any_updates_left = dfs.update(algorithm, app.maze.maze)
            }
        }

        if !app.is_paused && !any_updates_left {
            app.state = AppState.MazeSolved

            change_window_title(app)

            break
        }
    }

    return .None
}

maze_solved_screen :: proc(app: ^App) {
    raylib.BeginDrawing()

    raylib.ClearBackground(raylib.BLACK)

    maze.draw(app.maze)

    switch app.path_algorithm {
    case .AStar:
        algorithm := &app.a_star.? or_else panic("A* should be initialized at this point")

        a_star.draw(algorithm)
    case .Dfs:
        algorithm := &app.dfs.? or_else panic("Dfs should be initialized at this point")

        dfs.draw(algorithm)
    }

    raylib.EndDrawing()
}

main :: proc() {
    raylib.InitWindow(
        consts.SCREEN_WIDTH,
        consts.SCREEN_HEIGHT,
        "Maze Solver - Generating Maze"
    )
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(consts.TARGET_GENERAING_MAZE_FPS)
    
    app := App {
        state = AppState.GeneratingMaze,
        maze = maze.new(),
        path_algorithm = PathAlgorithm.AStar,
    }
    defer maze.drop(&app.maze)
    defer {
        if algorithm, ok := app.a_star.?; ok {
            a_star.drop(&algorithm)
        }

        if algorithm, ok := app.dfs.?; ok {
            dfs.drop(&algorithm)
        }
    }

    for !raylib.WindowShouldClose() {
        switch app.state {
        case .GeneratingMaze: generating_maze_screen(&app)
        case .MazeGenerated: generated_maze_screen(&app)
        case .SolvingMaze:
            if err := solving_maze_screen(&app); err != nil {
                panic("Allocator_Error on solving maze")
            }
        case .MazeSolved: maze_solved_screen(&app)
        }
    }
}
