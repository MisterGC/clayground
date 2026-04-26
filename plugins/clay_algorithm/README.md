# Clay Algorithm Plugin

The Clay Algorithm plugin provides computational algorithm components
for use in games and simulations. It has zero Clayground dependencies
and serves as a foundation layer.

## Getting Started

```qml
import Clayground.Algorithm
```

## Components

- **GridPathfinder** - A* pathfinding on a 2D grid with binary heap,
  supporting diagonal movement and incremental cell updates.

## Usage Example

### Grid Pathfinding

```qml
import Clayground.Algorithm

GridPathfinder {
    id: pathfinder
    columns: 50
    rows: 50
    diagonal: true
    walkableData: levelTileData  // flat array: 0 = walkable, 1+ = blocked
}

// Compute a path
// var path = pathfinder.findPath(0, 0, 49, 49)
// Returns: [{x:0, y:0}, {x:1, y:1}, ...] or [] if unreachable
```

### Incremental Updates

```qml
// Block a single cell
pathfinder.setWalkable(10, 5, false)

// Unblock it
pathfinder.setWalkable(10, 5, true)
```

## API Reference

### GridPathfinder Properties

| Property | Type | Description |
|----------|------|-------------|
| `columns` | int | Number of grid columns (default: 10) |
| `rows` | int | Number of grid rows (default: 10) |
| `walkableData` | var | Flat array indexed `[y * columns + x]`, 0 = walkable |
| `diagonal` | bool | Allow diagonal movement (default: false) |

### GridPathfinder Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `findPath(startX, startY, endX, endY)` | list | A* shortest path as `[{x, y}, ...]` |
| `setWalkable(x, y, walkable)` | void | Update a single cell |
