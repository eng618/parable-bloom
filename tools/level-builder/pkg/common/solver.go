package common

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// Solver provides solvability checking for levels.
type Solver struct {
	level *model.Level
}

// NewSolver creates a new solver for a level.
func NewSolver(level *model.Level) *Solver {
	return &Solver{level: level}
}

// IsSolvableGreedy checks solvability using a fast greedy algorithm.
func (s *Solver) IsSolvableGreedy() bool {
	vines := s.level.Vines
	vineCount := len(vines)
	if vineCount == 0 {
		return true
	}

	w := s.level.GetGridWidth()
	gridArea := w * s.level.GetGridHeight()

	// Pre-build vine data
	vineIndices := make([][]int, vineCount)
	for i, v := range vines {
		indices := make([]int, len(v.OrderedPath))
		for j, p := range v.OrderedPath {
			indices[j] = p.Y*w + p.X
		}
		vineIndices[i] = indices
	}

	// Active vines tracking
	activeVines := make([]bool, vineCount)
	for i := 0; i < vineCount; i++ {
		activeVines[i] = true
	}
	activeCount := vineCount

	// Occupied buffer
	occupied := make([]bool, gridArea)

	for activeCount > 0 {
		foundClearable := false

		// Build occupied set from active vines
		for i := 0; i < gridArea; i++ {
			occupied[i] = false
		}
		for i := 0; i < vineCount; i++ {
			if activeVines[i] {
				for _, idx := range vineIndices[i] {
					occupied[idx] = true
				}
			}
		}

		// Try to find a clearable vine
		// Optimization: could iterate only active vines, but iterating all is simpler for now
		for i := 0; i < vineCount; i++ {
			if !activeVines[i] {
				continue
			}

			if s.canVineClearFast(&vines[i], occupied, vineIndices[i], w) {
				activeVines[i] = false
				activeCount--
				foundClearable = true
				// Restart loop to reflect new empty space immediately?
				// Greedy Strategy: remove one, then re-evaluate.
				// For LIFO check, removing one by one is correct.
				break
			}
		}

		if !foundClearable {
			return false
		}
	}

	return true
}

// IsSolvableBFS checks solvability using a thorough BFS algorithm.
func (s *Solver) IsSolvableBFS() bool {
	vines := s.level.Vines
	vineCount := len(vines)
	if vineCount == 0 {
		return true
	}

	w := s.level.GetGridWidth()
	gridArea := w * s.level.GetGridHeight()

	// Pre-build vine data
	vineIndices := make([][]int, vineCount)
	for i, v := range vines {
		indices := make([]int, len(v.OrderedPath))
		for j, p := range v.OrderedPath {
			indices[j] = p.Y*w + p.X
		}
		vineIndices[i] = indices
	}

	initialMask := int64((1 << uint(vineCount)) - 1)
	if vineCount == 64 {
		initialMask = -1
	}

	queue := []int64{initialMask}
	visited := make(map[int64]bool)
	visited[initialMask] = true

	occupied := make([]bool, gridArea)

	for len(queue) > 0 {
		mask := queue[0]
		queue = queue[1:]

		if mask == 0 {
			return true
		}

		// Build occupied set
		for i := 0; i < gridArea; i++ {
			occupied[i] = false
		}
		for i := 0; i < vineCount; i++ {
			if (mask & (1 << uint64(i))) != 0 {
				for _, idx := range vineIndices[i] {
					occupied[idx] = true
				}
			}
		}

		// Try removing each clearable vine
		for i := 0; i < vineCount; i++ {
			if (mask & (1 << uint64(i))) == 0 {
				continue
			}

			if s.canVineClearFast(&vines[i], occupied, vineIndices[i], w) {
				next := mask & ^(1 << uint64(i))
				if !visited[next] {
					visited[next] = true
					queue = append(queue, next)
				}
			}
		}
	}

	return false
}

func (s *Solver) canVineClearFast(vine *model.Vine, occupied []bool, selfIndices []int, w int) bool {
	if len(vine.OrderedPath) == 0 {
		return false
	}

	delta := HeadDirections[vine.HeadDirection]
	dx, dy := delta[0], delta[1]
	if dx == 0 && dy == 0 {
		return false
	}

	h := s.level.GetGridHeight()

	// Current positions (as indices)
	positions := make([]int, len(selfIndices))
	copy(positions, selfIndices)

	maxSteps := w + h + len(positions)
	for step := 0; step < maxSteps; step++ {
		headIdx := positions[0]
		hx, hy := headIdx%w, headIdx/w
		nx, ny := hx+dx, hy+dy

		if nx < 0 || nx >= w || ny < 0 || ny >= h {
			return true
		}

		nextIdx := ny*w + nx
		if occupied[nextIdx] {
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

		for i := len(positions) - 1; i > 0; i-- {
			positions[i] = positions[i-1]
		}
		positions[0] = nextIdx
	}

	return false
}

// canVineClear is a compatibility wrapper for tests
func (s *Solver) canVineClear(vine *model.Vine, occupiedCells map[string]bool) bool {
	w := s.level.GetGridWidth()
	h := s.level.GetGridHeight()
	occupied := make([]bool, w*h)
	for k := range occupiedCells {
		var x, y int
		_, _ = fmt.Sscanf(k, "%d,%d", &x, &y)
		if x >= 0 && x < w && y >= 0 && y < h {
			occupied[y*w+x] = true
		}
	}

	indices := make([]int, len(vine.OrderedPath))
	for i, p := range vine.OrderedPath {
		indices[i] = p.Y*w + p.X
	}

	return s.canVineClearFast(vine, occupied, indices, w)
}
