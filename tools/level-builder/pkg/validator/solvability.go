package validator

import (
	"fmt"
	"math"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// IsSolvable performs a bounded-search solvability check for a level. It uses an exact BFS for
// up to 24 vines (optionally A*) and a lightweight heuristic for larger levels.
//
// SolvabilityStats now contains extra instrumentation useful for experiments and diagnostics.
type SolvabilityStats struct {
	Solver         string `json:"solver"`
	StatesExplored int    `json:"states_explored"`
	GaveUp         bool   `json:"gave_up"`
}

// IsSolvable is the backward-compatible helper that calls the options-aware solver
// with default settings (no A*; heuristic for large levels).
func IsSolvable(lvl model.Level, maxStates int) (bool, SolvabilityStats, error) {
	// Backward-compatible helper: use default options (no A*, heuristic for large levels).
	return IsSolvableWithOptions(lvl, maxStates, false, 10)
}

// IsSolvableWithOptions selects an appropriate solver (exact, A*, or heuristic) and returns
// instrumentation stats. A* is used for small vine counts when requested.
func IsSolvableWithOptions(lvl model.Level, maxStates int, useAstar bool, astarWeight int) (bool, SolvabilityStats, error) {
	vineCount := len(lvl.Vines)
	if vineCount == 0 {
		return true, SolvabilityStats{Solver: "none", StatesExplored: 0, GaveUp: false}, nil
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

func isSolvableExact(lvl model.Level) bool {
	vines := lvl.Vines
	vineCount := len(vines)

	// Build vine cells map
	vineCells := make([]map[string]bool, vineCount)
	for i, v := range vines {
		m := map[string]bool{}
		for _, p := range v.OrderedPath {
			m[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
		}
		vineCells[i] = m
	}

	fullMask := (1 << uint(vineCount)) - 1
	visited := make(map[int]bool)
	queue := []int{fullMask}
	visited[fullMask] = true

	for len(queue) > 0 {
		mask := queue[0]
		queue = queue[1:]
		if mask == 0 {
			return true
		}

		occupiedAll := computeOccupied(mask, vineCount, vineCells)

		for i := 0; i < vineCount; i++ {
			if (mask & (1 << uint(i))) == 0 {
				continue
			}
			if canVineClearExact(lvl, i, occupiedAll, vineCells[i]) {
				next := mask & ^(1 << uint(i))
				if !visited[next] {
					visited[next] = true
					queue = append(queue, next)
				}
			}
		}
	}

	return false
}

func canVineClearExact(lvl model.Level, vineIndex int, occupiedAll map[string]bool, selfCells map[string]bool) bool {
	vine := lvl.Vines[vineIndex]
	if len(vine.OrderedPath) == 0 {
		return false
	}

	// Prepare current positions as slice of points
	positions := make([]model.Point, len(vine.OrderedPath))
	for i, p := range vine.OrderedPath {
		positions[i] = p
	}

	w := lvl.GridSize[0]
	h := lvl.GridSize[1]

	maxCheckDistance := int(math.Min(300, math.Max(10, float64(w+h+len(positions)+10))))

	for step := 0; step < maxCheckDistance; step++ {
		newPositions := simulateVineMovementFromPositions(positions, vine.HeadDirection)

		if !validateNewPositions(newPositions, occupiedAll, selfCells) {
			return false
		}

		// check head exit
		head := newPositions[0]
		if head.X < 0 || head.X >= w || head.Y < 0 || head.Y >= h {
			return true
		}

		positions = newPositions
	}

	return false
}

func validateNewPositions(newPositions []model.Point, occupiedAll map[string]bool, selfCells map[string]bool) bool {
	seen := map[string]bool{}
	for _, np := range newPositions {
		k := fmt.Sprintf("%d,%d", np.X, np.Y)

		// Self-overlap after movement is not allowed.
		if !seen[k] {
			seen[k] = true
		} else {
			return false
		}

		// Collision with any other vine.
		if occupiedAll[k] && !selfCells[k] {
			return false
		}
	}
	return true
}

func simulateVineMovementFromPositions(positions []model.Point, direction string) []model.Point {
	if len(positions) == 0 {
		return positions
	}

	head := positions[0]
	dx, dy := 0, 0
	switch direction {
	case "right":
		dx = 1
	case "left":
		dx = -1
	case "up":
		dy = 1
	case "down":
		dy = -1
	}

	newHead := model.Point{X: head.X + dx, Y: head.Y + dy}
	newPositions := make([]model.Point, 0, len(positions))
	newPositions = append(newPositions, newHead)
	for i := 1; i < len(positions); i++ {
		newPositions = append(newPositions, positions[i-1])
	}
	return newPositions
}

// Heuristic solver: simple BFS using immediate head-cell blocking as the movable criteria.
func isSolvableHeuristic(lvl model.Level, maxStates int) bool {
	ok, _ := isSolvableHeuristicWithStats(lvl, maxStates)
	return ok
}

// Exact solver that returns whether the level is solvable and the number of states explored.
func isSolvableExactWithStats(lvl model.Level, maxStates int) (bool, int) {
	vines := lvl.Vines
	vineCount := len(vines)

	// Build vine cells map
	vineCells := make([]map[string]bool, vineCount)
	for i, v := range vines {
		m := map[string]bool{}
		for _, p := range v.OrderedPath {
			m[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
		}
		vineCells[i] = m
	}

	fullMask := (1 << uint(vineCount)) - 1
	// Use a simple slice-backed queue for correctness and clarity.
	visited := make([]bool, 1<<uint(vineCount))
	queue := []int{fullMask}
	visited[fullMask] = true
	states := 0

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

		occupiedAll := computeOccupied(mask, vineCount, vineCells)

		for i := 0; i < vineCount; i++ {
			if (mask & (1 << uint(i))) == 0 {
				continue
			}
			if canVineClearExact(lvl, i, occupiedAll, vineCells[i]) {
				next := mask & ^(1 << uint(i))
				if !visited[next] {
					visited[next] = true
					queue = append(queue, next)
				}
			}
		}
	}

	return false, states
}

// Heuristic solver with stats
func isSolvableHeuristicWithStats(lvl model.Level, maxStates int) (bool, int) {
	vines := lvl.Vines
	vineCount := len(vines)

	// Precompute occupied cell sets
	vineCells := buildVineCells(lvl)

	fullMask := (1 << uint(vineCount)) - 1
	// Use slice-backed visited queue for performance
	size := 1 << uint(vineCount)
	if size <= 0 {
		size = 1
	}
	visited := make([]bool, size)
	queue := make([]int, 0, 1024)
	queue = append(queue, fullMask)
	visited[fullMask] = true
	states := 0

	for len(queue) > 0 && states < maxStates {
		mask := queue[0]
		queue = queue[1:]
		states++

		if mask == 0 {
			return true, states
		}

		occupied := computeOccupied(mask, vineCount, vineCells)

		movable := determineMovableVines(lvl, mask, occupied)

		if len(movable) == 0 {
			continue
		}

		// expansion order: prefer vines that unblock most others (simple heuristic)
		// For now, append in current order
		for _, i := range movable {
			next := mask & ^(1 << uint(i))
			if !visited[next] {
				visited[next] = true
				queue = append(queue, next)
			}
		}
	}

	return false, states
}

// Helper functions to reduce complexity
func buildVineCells(lvl model.Level) []map[string]bool {
	vines := lvl.Vines
	vineCount := len(vines)
	vineCells := make([]map[string]bool, vineCount)
	for i, v := range vines {
		m := map[string]bool{}
		for _, p := range v.OrderedPath {
			m[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
		}
		vineCells[i] = m
	}
	return vineCells
}

func computeOccupied(mask int, vineCount int, vineCells []map[string]bool) map[string]bool {
	occupied := map[string]bool{}
	for i := 0; i < vineCount; i++ {
		if (mask & (1 << uint(i))) == 0 {
			continue
		}
		for k := range vineCells[i] {
			occupied[k] = true
		}
	}
	return occupied
}

func determineMovableVines(lvl model.Level, mask int, occupied map[string]bool) []int {
	vines := lvl.Vines
	vineCount := len(vines)
	movable := make([]int, 0, 8)
	for i := 0; i < vineCount; i++ {
		if (mask & (1 << uint(i))) == 0 {
			continue
		}
		v := vines[i]
		head := v.OrderedPath[0]
		dx, dy := directionDelta(v.HeadDirection)
		nxt := fmt.Sprintf("%d,%d", head.X+dx, head.Y+dy)
		if head.X+dx < 0 || head.X+dx >= lvl.GridSize[0] || head.Y+dy < 0 || head.Y+dy >= lvl.GridSize[1] {
			movable = append(movable, i)
			continue
		}
		if !occupied[nxt] {
			movable = append(movable, i)
		}
	}
	return movable
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
