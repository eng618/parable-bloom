package utils

import (
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// ChooseExitDirection picks a head direction that points toward the nearest grid edge.
// This dramatically improves solvability by ensuring vines can exit the grid.
func ChooseExitDirection(seed model.Point, gridSize []int, dirBalance map[string]float64, rng *rand.Rand) string {
	width, height := gridSize[0], gridSize[1]
	x, y := seed.X, seed.Y

	// Calculate distances to each edge
	distToLeft := x
	distToRight := width - x - 1
	distToBottom := y
	distToTop := height - y - 1

	// Build weighted choices based on edge proximity
	// Closer edges get higher weights
	weights := make(map[string]float64)

	// Inverse distance weighting (closer = higher weight)
	// Add 1 to avoid division by zero for seeds on edges
	weights["left"] = 1.0 / float64(distToLeft+1)
	weights["right"] = 1.0 / float64(distToRight+1)
	weights["down"] = 1.0 / float64(distToBottom+1)
	weights["up"] = 1.0 / float64(distToTop+1)

	// Apply dirBalance preferences (if any)
	for dir, balance := range dirBalance {
		if w, exists := weights[dir]; exists {
			weights[dir] = w * balance
		}
	}

	// Weighted random selection
	totalWeight := 0.0
	for _, w := range weights {
		totalWeight += w
	}

	if totalWeight == 0 {
		// Fallback to random direction
		directions := []string{"right", "left", "up", "down"}
		return directions[rng.Intn(len(directions))]
	}

	roll := rng.Float64() * totalWeight
	cumulative := 0.0

	for dir, weight := range weights {
		cumulative += weight
		if roll < cumulative {
			return dir
		}
	}

	// Should never reach here, but return closest edge as fallback
	if distToLeft <= distToRight && distToLeft <= distToTop && distToLeft <= distToBottom {
		return "left"
	} else if distToRight <= distToTop && distToRight <= distToBottom {
		return "right"
	} else if distToBottom <= distToTop {
		return "down"
	}
	return "up"
}

// DeltaForDirection returns the (dx, dy) movement vector for a direction string.
func DeltaForDirection(dir string) (int, int) {
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

// OppositeDirection returns the reverse of a direction.
func OppositeDirection(dir string) string {
	switch dir {
	case "right":
		return "left"
	case "left":
		return "right"
	case "up":
		return "down"
	case "down":
		return "up"
	default:
		return ""
	}
}

// DistanceToNearestEdge calculates the minimum distance from a point to any grid edge.
func DistanceToNearestEdge(pos model.Point, gridSize []int) int {
	width, height := gridSize[0], gridSize[1]
	x, y := pos.X, pos.Y

	distToLeft := x
	distToRight := width - x - 1
	distToBottom := y
	distToTop := height - y - 1

	minDist := distToLeft
	if distToRight < minDist {
		minDist = distToRight
	}
	if distToBottom < minDist {
		minDist = distToBottom
	}
	if distToTop < minDist {
		minDist = distToTop
	}

	return minDist
}

// IsNearEdge returns true if the point is within the specified distance from any edge.
func IsNearEdge(pos model.Point, gridSize []int, edgeDistance int) bool {
	return DistanceToNearestEdge(pos, gridSize) <= edgeDistance
}

// PickEdgeSeed selects a random seed point near the grid edges.
// This is useful for placing clearable "anchor" vines.
func PickEdgeSeed(occupied map[string]bool, gridSize []int, edgeDistance int, rng *rand.Rand) (model.Point, bool) {
	width, height := gridSize[0], gridSize[1]

	var candidates []model.Point
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			pt := model.Point{X: x, Y: y}
			key := common.PointKey(pt)

			if !occupied[key] && IsNearEdge(pt, gridSize, edgeDistance) {
				candidates = append(candidates, pt)
			}
		}
	}

	if len(candidates) == 0 {
		return model.Point{}, false
	}

	return candidates[rng.Intn(len(candidates))], true
}
