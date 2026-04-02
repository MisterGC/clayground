// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype GridPathfinder
    \inqmlmodule Clayground.Algorithm
    \brief A* pathfinding on a 2D grid.

    GridPathfinder computes shortest paths on a 2D grid using the A*
    algorithm with a binary heap for efficient open-set management.
    Cells can be marked as walkable or blocked, and diagonal movement
    is optionally supported.

    Example usage:
    \qml
    import Clayground.Algorithm

    GridPathfinder {
        id: pathfinder
        columns: 50
        rows: 50
        walkableData: myTileData
        diagonal: true
    }

    // Later:
    // var path = pathfinder.findPath(0, 0, 49, 49)
    \endqml
*/
QtObject {
    id: root

    /*!
        \qmlproperty int GridPathfinder::columns
        \brief Number of columns in the grid.
    */
    property int columns: 10

    /*!
        \qmlproperty int GridPathfinder::rows
        \brief Number of rows in the grid.
    */
    property int rows: 10

    /*!
        \qmlproperty var GridPathfinder::walkableData
        \brief Flat array of grid cell values. 0 means walkable, 1+ means blocked.

        The array is indexed as \c{walkableData[y * columns + x]}.
        When set, an internal copy is made so the original is not modified.
    */
    property var walkableData: []
    onWalkableDataChanged: _grid = walkableData.length > 0
                           ? Array.from(walkableData) : []

    /*!
        \qmlproperty bool GridPathfinder::diagonal
        \brief Allow diagonal movement (default: false).
    */
    property bool diagonal: false

    // Internal copy of the grid data
    property var _grid: []

    /*!
        \qmlmethod void GridPathfinder::setWalkable(int x, int y, bool walkable)
        \brief Set whether a single cell is walkable.
    */
    function setWalkable(x, y, walkable) {
        if (x < 0 || x >= columns || y < 0 || y >= rows) return;
        if (_grid.length !== columns * rows) {
            _grid = new Array(columns * rows).fill(0);
        }
        _grid[y * columns + x] = walkable ? 0 : 1;
    }

    /*!
        \qmlmethod list GridPathfinder::findPath(int startX, int startY, int endX, int endY)
        \brief Compute the shortest path between two grid cells using A*.

        Returns an array of \c{{x, y}} objects from start to end (inclusive),
        or an empty array if no path exists.
    */
    function findPath(startX, startY, endX, endY) {
        let c = columns, r = rows;
        if (startX < 0 || startX >= c || startY < 0 || startY >= r) return [];
        if (endX < 0 || endX >= c || endY < 0 || endY >= r) return [];

        let grid = _grid;
        if (grid.length !== c * r)
            grid = new Array(c * r).fill(0);

        let si = startY * c + startX;
        let ei = endY * c + endX;

        if (grid[si] !== 0 || grid[ei] !== 0) return [];
        if (si === ei) return [{x: startX, y: startY}];

        // Heuristic: octile distance for diagonal, manhattan otherwise
        let useDiag = diagonal;
        function h(idx) {
            let dx = Math.abs((idx % c) - endX);
            let dy = Math.abs(Math.floor(idx / c) - endY);
            if (useDiag) {
                let mn = Math.min(dx, dy);
                return (dx + dy) + (1.4142135 - 2) * mn;
            }
            return dx + dy;
        }

        // Neighbors
        let dirs4 = [[-1,0],[1,0],[0,-1],[0,1]];
        let dirs8 = [[-1,0],[1,0],[0,-1],[0,1],[-1,-1],[1,-1],[-1,1],[1,1]];
        let dirs = useDiag ? dirs8 : dirs4;

        // Binary heap (min-heap on f-score)
        let heapArr = [];
        let heapF = [];

        function heapPush(idx, f) {
            let pos = heapArr.length;
            heapArr.push(idx);
            heapF.push(f);
            while (pos > 0) {
                let parent = (pos - 1) >> 1;
                if (heapF[pos] < heapF[parent]) {
                    let ti = heapArr[pos]; heapArr[pos] = heapArr[parent]; heapArr[parent] = ti;
                    let tf = heapF[pos]; heapF[pos] = heapF[parent]; heapF[parent] = tf;
                    pos = parent;
                } else break;
            }
        }

        function heapPop() {
            let top = heapArr[0];
            let last = heapArr.length - 1;
            if (last > 0) {
                heapArr[0] = heapArr[last]; heapF[0] = heapF[last];
            }
            heapArr.pop(); heapF.pop();
            let pos = 0, size = heapArr.length;
            while (true) {
                let best = pos, l = 2*pos+1, ri = 2*pos+2;
                if (l < size && heapF[l] < heapF[best]) best = l;
                if (ri < size && heapF[ri] < heapF[best]) best = ri;
                if (best !== pos) {
                    let ti = heapArr[pos]; heapArr[pos] = heapArr[best]; heapArr[best] = ti;
                    let tf = heapF[pos]; heapF[pos] = heapF[best]; heapF[best] = tf;
                    pos = best;
                } else break;
            }
            return top;
        }

        let total = c * r;
        let gScore = new Float64Array(total).fill(Infinity);
        let cameFrom = new Int32Array(total).fill(-1);
        let closed = new Uint8Array(total);

        gScore[si] = 0;
        heapPush(si, h(si));

        while (heapArr.length > 0) {
            let cur = heapPop();
            if (cur === ei) {
                // Reconstruct path
                let path = [];
                let idx = ei;
                while (idx !== -1) {
                    path.push({x: idx % c, y: Math.floor(idx / c)});
                    idx = cameFrom[idx];
                }
                path.reverse();
                return path;
            }
            if (closed[cur]) continue;
            closed[cur] = 1;

            let cx = cur % c, cy = Math.floor(cur / c);
            let curG = gScore[cur];

            for (let d = 0; d < dirs.length; ++d) {
                let nx = cx + dirs[d][0], ny = cy + dirs[d][1];
                if (nx < 0 || nx >= c || ny < 0 || ny >= r) continue;
                let ni = ny * c + nx;
                if (closed[ni] || grid[ni] !== 0) continue;

                // For diagonal moves, check corner-cutting
                if (d >= 4) {
                    let ax = cy * c + nx, ay = ny * c + cx;
                    if (grid[ax] !== 0 || grid[ay] !== 0) continue;
                }

                let cost = d >= 4 ? 1.4142135 : 1;
                let ng = curG + cost;
                if (ng < gScore[ni]) {
                    gScore[ni] = ng;
                    cameFrom[ni] = cur;
                    heapPush(ni, ng + h(ni));
                }
            }
        }
        return [];
    }
}
