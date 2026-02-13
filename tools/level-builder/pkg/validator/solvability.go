package validator

import (
	"container/heap"
	"fmt"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// IsSolvable performs a bounded-search solvability check for a level. It uses an exact BFS for
// up to 24 vines (optionally A*) and a lightweight heuristic for larger levels.
//
// SolvabilityStats now contains extra instrumentation useful for experiments and diagnostics.
const DefaultAStarWeight = 10

type SolvabilityStats struct {
	Solver         string `json:"solver"`
	StatesExplored int    `json:"states_explored"`
	GaveUp         bool   `json:"gave_up"`
}

// IsSolvable is the backward-compatible helper that calls the options-aware solver
// with default settings (no A*; heuristic for large levels).
func IsSolvable(lvl model.Level, maxStates int) (bool, SolvabilityStats, error) {
	// Default to A* for small vine counts; heuristic for larger levels.
	return IsSolvableWithOptions(lvl, maxStates, true, DefaultAStarWeight)
}

// IsSolvableWithOptions selects an appropriate solver (exact, A*, or heuristic) and returns
// instrumentation stats. A* is used for small vine counts when requested.
func IsSolvableWithOptions(lvl model.Level, maxStates int, useAstar bool, astarWeight int) (bool, SolvabilityStats, error) {
	vineCount := len(lvl.Vines)
	if vineCount == 0 {
		return true, SolvabilityStats{Solver: "none", StatesExplored: 0, GaveUp: false}, nil
	}
	if vineCount >= 64 {
		// Use unlimited greedy solver for large levels
		solver := common.NewSolver(&lvl)
		if solver.IsSolvableGreedy() {
			return true, SolvabilityStats{Solver: "greedy-unlimited", StatesExplored: 0, GaveUp: false}, nil
		}
		// If greedy fails, report failure (though it might still be solvable)
		return false, SolvabilityStats{Solver: "greedy-unlimited", GaveUp: true}, fmt.Errorf("greedy solver failed for %d vines", vineCount)
	}
	if vineCount <= 24 {
		if useAstar {
			ok, states := isSolvableExactAStarWithStats(lvl, maxStates, astarWeight)
			stats := SolvabilityStats{Solver: "exact-astar", StatesExplored: states, GaveUp: states >= maxStates}
			return ok, stats, nil
		}
		ok, states := isSolvableExactWithStats(lvl, maxStates)
		stats := SolvabilityStats{Solver: "exact", StatesExplored: states, GaveUp: states >= maxStates}
		return ok, stats, nil
	}

	ok, states := isSolvableHeuristicWithStats(lvl, maxStates)
	stats := SolvabilityStats{Solver: "heuristic", StatesExplored: states, GaveUp: states >= maxStates}
	return ok, stats, nil
}

// IsSolvableWithStats reports whether the given level is solvable within the provided maxStates limit.
// It delegates to the options-aware solver and populates a LevelStat suitable for JSON output.
func IsSolvableWithStats(lvl model.Level, maxStates int, useAstar bool, astarWeight int) (bool, LevelStat, error) {
	ok, stats, err := IsSolvableWithOptions(lvl, maxStates, useAstar, astarWeight)
	stat := LevelStat{}
	if stats.Solver != "" {
		stat.Solver = stats.Solver
	}
	stat.StatesExplored = stats.StatesExplored
	stat.GaveUp = stats.GaveUp
	stat.MaxStates = maxStates
	return ok, stat, err
}

// isSolvableExactWithStats returns whether the level is solvable and the number of states explored.
func isSolvableExactWithStats(lvl model.Level, maxStates int) (bool, int) {
	vines := lvl.Vines
	vineCount := len(vines)
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	gridArea := w * h

	// Build vine indices map
	vineIndices := make([][]int, vineCount)
	for i, v := range vines {
		indices := make([]int, len(v.OrderedPath))
		for j, p := range v.OrderedPath {
			indices[j] = p.Y*w + p.X
		}
		vineIndices[i] = indices
	}

	fullMask := (uint64(1) << uint(vineCount)) - 1
	visited := make(map[uint64]bool)
	queue := make([]uint64, 0, 1024)
	queue = append(queue, fullMask)
	visited[fullMask] = true
	states := 0

	// Reusable occupancy buffer
	occupied := make([]bool, gridArea)

	for len(queue) > 0 {
		if states >= maxStates {
			return false, states
		}

		mask := queue[0]
		queue = queue[1:]
		states++
		if mask == 0 {
			return true, states
		}

		// Update occupancy bitset with active vines (masked cells are ignored - they are passible)
		for i := 0; i < gridArea; i++ {
			occupied[i] = false
		}
		for i := 0; i < vineCount; i++ {
			if (mask & (uint64(1) << uint(i))) != 0 {
				for _, idx := range vineIndices[i] {
					occupied[idx] = true
				}
			}
		}

		for i := 0; i < vineCount; i++ {
			if (mask & (uint64(1) << uint(i))) == 0 {
				continue
			}
			if canVineClearFast(lvl, i, occupied, vineIndices[i]) {
				next := mask & ^(uint64(1) << uint(i))
				if !visited[next] {
					visited[next] = true
					queue = append(queue, next)
				}
			}
		}
	}

	return false, states
}

func canVineClearFast(lvl model.Level, vineIndex int, occupiedAll []bool, selfIndices []int) bool {
	v := lvl.Vines[vineIndex]
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	dx, dy := directionDelta(v.HeadDirection)

	// Current positions (as indices)
	positions := make([]int, len(selfIndices))
	copy(positions, selfIndices)

	maxDist := w + h + len(positions)
	for step := 0; step < maxDist; step++ {
		// Calculate next head position
		headIdx := positions[0]
		hx, hy := headIdx%w, headIdx/w
		nx, ny := hx+dx, hy+dy

		// Check head exit
		if nx < 0 || nx >= w || ny < 0 || ny >= h {
			return true
		}

		nextIdx := ny*w + nx
		// Check collision with others (ignoring self)
		if occupiedAll[nextIdx] {
			collidesWithSelf := false
			for _, si := range positions {
				if si == nextIdx {
					collidesWithSelf = true
					break
				}
			}
			if !collidesWithSelf {
				return false
			}
		}

		// Shift body
		for i := len(positions) - 1; i > 0; i-- {
			positions[i] = positions[i-1]
		}
		positions[0] = nextIdx
	}
	return false
}

// isSolvableHeuristicWithStats uses a best-first search with a simple unblocking heuristic
func isSolvableHeuristicWithStats(lvl model.Level, maxStates int) (bool, int) {
	vines := lvl.Vines
	vineCount := len(vines)
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	gridArea := w * h

	// Precompute vine indices
	vineIndices := make([][]int, vineCount)
	for i, v := range vines {
		indices := make([]int, len(v.OrderedPath))
		for j, p := range v.OrderedPath {
			indices[j] = p.Y*w + p.X
		}
		vineIndices[i] = indices
	}

	// Precompute blocking relationships
	blocking := make([][]bool, vineCount)
	for i := range blocking {
		blocking[i] = make([]bool, vineCount)
	}
	for i := 0; i < vineCount; i++ {
		for j := 0; j < vineCount; j++ {
			if i == j {
				continue
			}
			if doesVineBlockVineFast(vines[i], vines[j], lvl.GridSize) {
				blocking[i][j] = true
			}
		}
	}

	visited := make(map[uint64]bool)
	pq := &priorityQueueMask{}
	heap.Init(pq)

	var fullMask uint64
	if vineCount >= 64 {
		fullMask = ^uint64(0)
	} else {
		fullMask = (uint64(1) << uint(vineCount)) - 1
	}

	heap.Push(pq, &maskItem{mask: fullMask, priority: 0})
	visited[fullMask] = true
	states := 0
	occupied := make([]bool, gridArea)

	for pq.Len() > 0 && states < maxStates {
		item := heap.Pop(pq).(*maskItem)
		mask := item.mask
		states++

		if mask == 0 {
			return true, states
		}

		// Update occupancy with active vines (masked cells are passible)
		for idx := 0; idx < gridArea; idx++ {
			occupied[idx] = false
		}
		for i := 0; i < vineCount; i++ {
			if (mask & (uint64(1) << uint(i))) != 0 {
				for _, idx := range vineIndices[i] {
					occupied[idx] = true
				}
			}
		}

		movable := determineMovableVinesFast(lvl, mask, occupied, vineIndices)
		if len(movable) == 0 {
			continue
		}

		// Sort movable by number of vines they unblock
		sort.Slice(movable, func(a, b int) bool {
			aCount, bCount := 0, 0
			for k := 0; k < vineCount; k++ {
				if (mask & (uint64(1) << uint(k))) != 0 {
					if blocking[movable[a]][k] {
						aCount++
					}
					if blocking[movable[b]][k] {
						bCount++
					}
				}
			}
			return aCount > bCount
		})

		for _, i := range movable {
			next := mask & ^(uint64(1) << uint(i))
			if !visited[next] {
				visited[next] = true
				// Priority: fewer vines remaining is better
				priority := countSetBits64(next)
				heap.Push(pq, &maskItem{mask: next, priority: priority})
			}
		}
	}

	return false, states
}

func countSetBits64(n uint64) int {
	count := 0
	for n != 0 {
		n &= (n - 1)
		count++
	}
	return count
}

type maskItem struct {
	mask     uint64
	priority int
}

type priorityQueueMask []*maskItem

func (pq priorityQueueMask) Len() int           { return len(pq) }
func (pq priorityQueueMask) Less(i, j int) bool { return pq[i].priority < pq[j].priority }
func (pq priorityQueueMask) Swap(i, j int)      { pq[i], pq[j] = pq[j], pq[i] }
func (pq *priorityQueueMask) Push(x interface{}) {
	*pq = append(*pq, x.(*maskItem))
}

func (pq *priorityQueueMask) Pop() interface{} {
	old := *pq
	n := len(old)
	item := old[n-1]
	*pq = old[0 : n-1]
	return item
}

func determineMovableVinesFast(lvl model.Level, mask uint64, occupied []bool, vineIndices [][]int) []int {
	vines := lvl.Vines
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	movable := make([]int, 0, 8)
	for i := 0; i < len(vines); i++ {
		if (mask & (uint64(1) << uint(i))) == 0 {
			continue
		}
		v := vines[i]
		head := v.OrderedPath[0]
		dx, dy := directionDelta(v.HeadDirection)
		nx, ny := head.X+dx, head.Y+dy

		if nx < 0 || nx >= w || ny < 0 || ny >= h {
			movable = append(movable, i)
			continue
		}

		idx := ny*w + nx
		if !occupied[idx] {
			movable = append(movable, i)
		}
	}
	return movable
}

func doesVineBlockVineFast(blocker, blocked model.Vine, gridSize []int) bool {
	if len(blocked.OrderedPath) == 0 {
		return false
	}
	w, h := gridSize[0], gridSize[1]
	head := blocked.OrderedPath[0]
	dx, dy := directionDelta(blocked.HeadDirection)
	nx, ny := head.X+dx, head.Y+dy
	if nx < 0 || nx >= w || ny < 0 || ny >= h {
		return false // can exit, not blocked
	}
	blockIdx := ny*w + nx
	for _, p := range blocker.OrderedPath {
		if p.Y*w+p.X == blockIdx {
			return true
		}
	}
	return false
}

func directionDelta(dir string) (int, int) {
	switch dir {
	case "right":
		return 1, 0
	case "left":
		return -1, 0
	case "up":
		return 0, 1
	case "down":
		return 0, -1
	default:
		return 0, 0
	}
}
