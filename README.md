# Maze

Simulates maze generation using [Kruskal’s algorithm](https://cp-algorithms.com/graph/mst_kruskal.html) combined with [Disjoint Set Union](https://cp-algorithms.com/data_structures/disjoint_set_union.html), and solves the maze using either [A*](https://en.wikipedia.org/wiki/A*_search_algorithm) or [Depth-First Search (DFS)](https://cp-algorithms.com/graph/depth-first-search.html).

## Made with

- Odin (dev-2026-01)
- Raylib (v5.5)

## How to Use

The simulator runs through four main stages:

1. Generating Maze
2. Maze Generated
3. Solving Maze
4. Maze Solved

You can interact with the simulator during the first three stages. Available actions depend on the current stage:

1. Generating Maze
    - Press P to pause the generation
2. Maze Generated
    - Press 1 to select A* as the solving algorithm  
    - Press 2 to select DFS as the solving algorithm  
    - Press ENTER to start solving the maze
3. Solving Maze
    - Press P to pause the solving process
