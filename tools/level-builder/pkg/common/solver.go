package common

import (
	"fmt"
	"sort"
)

// Solver provides solvability checking for levels.
type Solver struct {
	level *Level
}

// NewSolver creates a new solver for a level.
func NewSolver(level *Level) *Solver {
	return &Solver{level: level}
}

// IsSolvableGreedy checks solvability using a fast greedy algorithm.
// This is used during level generation for speed.
func (s *Solver) IsSolvableGreedy() bool {
	if len(s.level.Vines) == 0 {
		return true
	}

	currentVines := make([]Vine, len(s.level.Vines))
	copy(currentVines, s.level.Vines)

	occupied := make(map[string]bool)
	for _, vine := range currentVines {
		for _, pt := range vine.OrderedPath {
			occupied[fmt.Sprintf("%d,%d", pt.X, pt.Y)] = true
		}
	}

	// Greedy removal: repeatedly find and remove clearable vines
	maxIterations := len(currentVines) * 2
	iterations := 0

	for len(currentVines) > 0 && iterations < maxIterations {
		iterations++
		foundClearable := false

		for i, vine := range currentVines {
			if s.canVineClear(&vine, occupied) {
				// Remove this vine from occupied
				for _, pt := range vine.OrderedPath {
					delete(occupied, fmt.Sprintf("%d,%d", pt.X, pt.Y))
				}
				// Remove vine from list
				currentVines = append(currentVines[:i], currentVines[i+1:]...)
				foundClearable = true
				break
			}
		}

		if !foundClearable {
			// Deadlock: no clearable vines
			return false
		}
	}

	return len(currentVines) == 0
}

// IsSolvableBFS checks solvability using a thorough BFS algorithm.
// This is the gold standard for validation but slower.
func (s *Solver) IsSolvableBFS() bool {
	if len(s.level.Vines) == 0 {
		return true
	}

	// BFS state: set of remaining vine IDs
	initialState := make(map[string]bool)
	for _, vine := range s.level.Vines {
		initialState[vine.ID] = true
	}

	queue := []map[string]bool{initialState}
	visited := make(map[string]bool)
	visited[stateKey(initialState)] = true

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]

		if len(current) == 0 {
			return true // All vines cleared
		}

		// Try removing each clearable vine
		vines := s.getVinesForIDs(current)
		occupied := s.buildOccupiedMap(vines)

		for _, vine := range vines {
			if s.canVineClear(&vine, occupied) {
				// Create new state without this vine
				next := make(map[string]bool)
				for id := range current {
					if id != vine.ID {
						next[id] = true
					}
				}

				key := stateKey(next)
				if !visited[key] {
					visited[key] = true
					queue = append(queue, next)
				}
			}
		}
	}

	return false
}

// canVineClear checks if a vine can move and eventually exit the grid.
// This properly simulates snake-like movement where each segment follows the previous one.
func (s *Solver) canVineClear(vine *Vine, occupiedCells map[string]bool) bool {
	if len(vine.OrderedPath) == 0 {
		return false
	}

	delta := HeadDirections[vine.HeadDirection]
	if delta[0] == 0 && delta[1] == 0 {
		return false
	}

	// Build a map of this vine's own cells so we can exclude them from collision checks
	selfCells := make(map[string]bool)
	for _, pt := range vine.OrderedPath {
		selfCells[fmt.Sprintf("%d,%d", pt.X, pt.Y)] = true
	}

	// Start with current positions
	positions := make([]Point, len(vine.OrderedPath))
	copy(positions, vine.OrderedPath)

	// Simulate movement for up to (width + height + path length) steps
	maxSteps := s.level.GetGridWidth() + s.level.GetGridHeight() + len(vine.OrderedPath) + 10

	for step := 0; step < maxSteps; step++ {
		// Simulate one step of snake-like movement
		newPositions := simulateVineMovement(positions, delta)

		// Check for self-overlap in the new positions
		seen := make(map[string]bool)
		for _, pos := range newPositions {
			key := fmt.Sprintf("%d,%d", pos.X, pos.Y)
			if seen[key] {
				// Self-overlap after movement - impossible configuration
				return false
			}
			seen[key] = true

			// Check if this position collides with another vine
			// (exclude cells that were originally occupied by this vine)
			if occupiedCells[key] && !selfCells[key] {
				// Blocked by another vine
				return false
			}
		}

		// Check if head has exited the grid (vine successfully clears)
		head := newPositions[0]
		if head.X < 0 || head.X >= s.level.GetGridWidth() ||
			head.Y < 0 || head.Y >= s.level.GetGridHeight() {
			return true
		}

		// Update positions for next iteration
		positions = newPositions
	}

	// Timed out without clearing - assume blocked
	return false
}

// simulateVineMovement simulates one step of snake-like movement.
// The head moves in the given direction, and each segment moves to where the previous segment was.
func simulateVineMovement(positions []Point, delta [2]int) []Point {
	if len(positions) == 0 {
		return positions
	}

	newPositions := make([]Point, len(positions))

	// New head position
	head := positions[0]
	newPositions[0] = Point{X: head.X + delta[0], Y: head.Y + delta[1]}

	// Each other segment moves to where the previous segment was
	for i := 1; i < len(positions); i++ {
		newPositions[i] = positions[i-1]
	}

	return newPositions
}

// buildOccupiedMap creates a map of occupied cells from vines.
func (s *Solver) buildOccupiedMap(vines []Vine) map[string]bool {
	occupied := make(map[string]bool)
	for _, vine := range vines {
		for _, pt := range vine.OrderedPath {
			occupied[fmt.Sprintf("%d,%d", pt.X, pt.Y)] = true
		}
	}
	return occupied
}

// getVinesForIDs returns vine objects for given IDs.
func (s *Solver) getVinesForIDs(ids map[string]bool) []Vine {
	var result []Vine
	for _, vine := range s.level.Vines {
		if ids[vine.ID] {
			result = append(result, vine)
		}
	}
	return result
}

// stateKey creates a unique, deterministic key for a state (set of vine IDs).
func stateKey(state map[string]bool) string {
	ids := make([]string, 0, len(state))
	for id := range state {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	key := ""
	for _, id := range ids {
		key += id + ","
	}
	return key
}
