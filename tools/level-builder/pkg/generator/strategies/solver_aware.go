package strategies

import (
	"fmt"
	"math"
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// SolverAwarePlacement creates vines with intelligent blocking patterns for higher difficulties.
// This is used for Nurturing, Flourishing, and Transcendent tiers where we want intentional
// complexity while maintaining solvability.
func SolverAwarePlacement(
	gridSize []int,
	constraints config.DifficultySpec,
	profile config.VarietyProfile,
	cfg config.GeneratorConfig,
	rng *rand.Rand,
) ([]model.Vine, *model.Mask, error) {
	// Start with tiling algorithm to get base vines
	vines, mask, err := TileGridIntoVines(gridSize, constraints, profile, cfg, rng)
	if err != nil {
		return nil, nil, err
	}

	// Build a temporary level to test solvability
	tempLevel := &model.Level{
		ID:       0,
		GridSize: gridSize,
		Vines:    vines,
		Mask:     mask,
	}

	// Check if already solvable
	solver := common.NewSolver(tempLevel)
	if !solver.IsSolvableGreedy() {
		return nil, nil, fmt.Errorf("initial tiling produced unsolvable level")
	}

	// For higher difficulties, try to introduce intentional blocking complexity
	// This makes puzzles more interesting by requiring careful ordering
	if shouldAddBlockingComplexity(constraints) {
		enhanced, enhanceErr := introduceBlockingComplexity(vines, gridSize, mask, rng)
		if enhanceErr == nil {
			// Validate enhanced version is still solvable
			tempLevel.Vines = enhanced
			enhancedSolver := common.NewSolver(tempLevel)
			if enhancedSolver.IsSolvableGreedy() && enhancedSolver.IsSolvableBFS() {
				vines = enhanced
			}
			// If enhanced version isn't solvable, fall back to original
		}
	}

	return vines, mask, nil
}

// shouldAddBlockingComplexity determines if we should try to add blocking patterns
// based on difficulty constraints.
func shouldAddBlockingComplexity(constraints config.DifficultySpec) bool {
	// Add complexity for difficulties with more vines (typically Nurturing+)
	return constraints.VineCountRange[0] >= 8
}

// introduceBlockingComplexity attempts to create intentional blocking relationships
// by strategically repositioning vine heads to create dependencies.
func introduceBlockingComplexity(
	vines []model.Vine,
	gridSize []int,
	mask *model.Mask,
	rng *rand.Rand,
) ([]model.Vine, error) {
	if len(vines) < 3 {
		return vines, fmt.Errorf("need at least 3 vines for blocking complexity")
	}

	// Create a copy to work with
	enhanced := make([]model.Vine, len(vines))
	copy(enhanced, vines)

	// Build occupancy map
	occupied := make(map[string]bool)
	for _, v := range enhanced {
		for _, p := range v.OrderedPath {
			occupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
		}
	}

	// Try to create a blocking chain: pick 2-3 vines and adjust their positions
	// so that one blocks another's exit path
	candidates := rng.Perm(len(enhanced))
	if len(candidates) > 5 {
		candidates = candidates[:5] // Work with up to 5 vines
	}

	attempts := 0
	maxAttempts := 50

	for attempts < maxAttempts {
		attempts++

		// Pick two vines to create a blocking relationship
		if len(candidates) < 2 {
			break
		}

		blockerIdx := candidates[0]
		blockedIdx := candidates[1]

		blocker := enhanced[blockerIdx]
		blocked := enhanced[blockedIdx]

		// Try to adjust blocker's head to be in blocked's exit path
		// Calculate where blocked vine will move
		exitPath := predictExitPath(blocked, gridSize, 5) // Look 5 steps ahead

		// Find if any of blocker's cells could be moved to block the exit path
		for _, exitCell := range exitPath {
			key := fmt.Sprintf("%d,%d", exitCell.X, exitCell.Y)
			if occupied[key] {
				continue // Already occupied
			}

			// Try to extend blocker to this position
			if canExtendVineTo(&blocker, exitCell, occupied, gridSize) {
				// Make the modification
				newPath := append(blocker.OrderedPath, exitCell)
				enhanced[blockerIdx].OrderedPath = newPath
				occupied[key] = true

				// Verify this creates a blocking relationship
				tempLevel := &model.Level{
					ID:       0,
					GridSize: gridSize,
					Vines:    enhanced,
					Mask:     mask,
				}

				solver := common.NewSolver(tempLevel)
				if solver.IsSolvableGreedy() {
					// Good! We created a blocking relationship and it's still solvable
					return enhanced, nil
				}

				// Revert if not solvable
				enhanced[blockerIdx].OrderedPath = blocker.OrderedPath
				delete(occupied, key)
			}
		}

		// Rotate candidates to try different pairs
		candidates = candidates[1:]
	}

	// If we couldn't enhance, return original
	return vines, fmt.Errorf("could not create blocking complexity")
}

// predictExitPath simulates where a vine will move over the next N steps.
func predictExitPath(vine model.Vine, gridSize []int, steps int) []model.Point {
	if len(vine.OrderedPath) == 0 {
		return nil
	}

	path := []model.Point{}
	head := vine.OrderedPath[0]

	var dx, dy int
	switch vine.HeadDirection {
	case "right":
		dx, dy = 1, 0
	case "left":
		dx, dy = -1, 0
	case "up":
		dx, dy = 0, 1
	case "down":
		dx, dy = 0, -1
	default:
		return nil
	}

	for i := 0; i < steps; i++ {
		nextX := head.X + dx*(i+1)
		nextY := head.Y + dy*(i+1)

		// Stop if we exit the grid
		if nextX < 0 || nextX >= gridSize[0] || nextY < 0 || nextY >= gridSize[1] {
			break
		}

		path = append(path, model.Point{X: nextX, Y: nextY})
	}

	return path
}

// canExtendVineTo checks if a vine can be extended to reach a target cell.
func canExtendVineTo(
	vine *model.Vine,
	target model.Point,
	occupied map[string]bool,
	gridSize []int,
) bool {
	if len(vine.OrderedPath) == 0 {
		return false
	}

	tail := vine.OrderedPath[len(vine.OrderedPath)-1]

	// Check Manhattan distance - if too far, not feasible
	dist := int(math.Abs(float64(target.X-tail.X)) + math.Abs(float64(target.Y-tail.Y)))
	if dist > 3 {
		return false // Too far to extend reasonably
	}

	// For simplicity, check if target is adjacent to tail
	if dist == 1 {
		// Adjacent, can extend directly
		return true
	}

	// Could implement pathfinding here for multi-step extensions,
	// but for now we keep it simple
	return false
}
