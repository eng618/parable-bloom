package gen2

import (
	"fmt"
	"math"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// CircuitBoardPlacer implements VinePlacementStrategy for circuit-board aesthetics
type CircuitBoardPlacer struct{}

// PlaceVines places vines with circuit-board-like winding patterns
func (p *CircuitBoardPlacer) PlaceVines(config GenerationConfig, rng *rand.Rand, stats *GenerationStats) ([]model.Vine, map[string]string, error) {
	w, h := config.GridWidth, config.GridHeight
	totalCells := w * h
	targetCells := int(float64(totalCells) * config.MinCoverage) // Use configurable coverage target

	occupied := make(map[string]string)
	vines := make([]model.Vine, 0, config.VineCount)

	// Calculate target lengths for each vine
	totalLength := 0
	lengths := p.calculateVineLengths(config, rng)
	for _, l := range lengths {
		totalLength += l
	}

	common.Verbose("Target total cells: %d, planned total length: %d", targetCells, totalLength)

	// Place vines one by one
	for i, targetLen := range lengths {
		vineID := fmt.Sprintf("v%d", i+1)

		// Try to place vine with circuit-board growth
		vine, newOccupied, err := p.growCircuitVine(
			vineID, targetLen, w, h, occupied, config, rng,
		)
		if err != nil {
			return nil, nil, fmt.Errorf("failed to place vine %s: %w", vineID, err)
		}

		// Add to collections
		vines = append(vines, vine)
		for k, v := range newOccupied {
			occupied[k] = v
		}

		common.Verbose("Placed vine %s with %d segments", vineID, len(vine.OrderedPath))
	}

	// Verify we have enough coverage
	occupiedCount := len(occupied)
	coverage := float64(occupiedCount) / float64(totalCells)
	common.Verbose("Final coverage: %d/%d cells (%.1f%%)", occupiedCount, totalCells, coverage*100)

	if coverage < config.MinCoverage { // Use configurable minimum coverage
		return nil, nil, fmt.Errorf("insufficient coverage: %.1f%% (need ≥%.0f%%)", coverage*100, config.MinCoverage*100)
	}

	return vines, occupied, nil
}

// calculateVineLengths computes target lengths for circuit-board vines
func (p *CircuitBoardPlacer) calculateVineLengths(config GenerationConfig, rng *rand.Rand) []int {
	totalCells := config.GridWidth * config.GridHeight
	avgLength := totalCells / config.VineCount

	// For circuit boards, create longer vines to achieve better coverage
	// This creates more filling capacity while maintaining winding aesthetics
	minLength := int(math.Max(5, float64(avgLength)*0.8))
	maxLength := int(math.Min(float64(totalCells)/8, float64(avgLength)*2.0))

	lengths := make([]int, config.VineCount)
	for i := range lengths {
		// Bias toward longer lengths for better coverage
		length := minLength + rng.Intn(maxLength-minLength+1)
		if length > maxLength {
			length = maxLength
		}
		if length < minLength {
			length = minLength
		}
		lengths[i] = length
	}

	// Adjust to exactly fill the grid (within reason)
	totalLength := 0
	for _, l := range lengths {
		totalLength += l
	}

	// Distribute any deficit/surplus
	delta := totalCells - totalLength
	if delta != 0 {
		adjustments := int(math.Abs(float64(delta)))
		for i := 0; i < adjustments; i++ {
			idx := i % config.VineCount
			if delta > 0 {
				if lengths[idx] < maxLength {
					lengths[idx]++
					delta--
				}
			} else {
				if lengths[idx] > minLength {
					lengths[idx]--
					delta++
				}
			}
		}
	}

	return lengths
}

// growCircuitVine grows a single vine with circuit-board aesthetics
func (p *CircuitBoardPlacer) growCircuitVine(
	vineID string,
	targetLen int,
	w, h int,
	occupied map[string]string,
	config GenerationConfig,
	rng *rand.Rand,
) (model.Vine, map[string]string, error) {

	// Choose starting position biased toward edges (circuit board style)
	seed := p.chooseCircuitSeed(w, h, occupied, rng)

	// Start the vine
	path := []model.Point{seed}
	localOccupied := make(map[string]string)
	localOccupied[fmt.Sprintf("%d,%d", seed.X, seed.Y)] = vineID

	// Grow the vine with circuit-board logic
	for len(path) < targetLen {
		current := path[len(path)-1]

		// Get available neighbors
		neighbors := p.getAvailableNeighbors(current, w, h, occupied, localOccupied)
		if len(neighbors) == 0 {
			// Stuck - this is normal for circuit boards, just return what we have
			break
		}

		// Choose next segment with circuit-board preferences
		next := p.chooseCircuitSegment(current, path, neighbors, w, h, rng)

		// Add to path
		path = append(path, next)
		localOccupied[fmt.Sprintf("%d,%d", next.X, next.Y)] = vineID
	}

	// Validate minimum length
	if len(path) < 2 {
		return model.Vine{}, nil, fmt.Errorf("vine too short: %d segments", len(path))
	}

	// Determine final head direction based on first two segments
	headDirection := p.calculateHeadDirection(path)

	vine := model.Vine{
		ID:            vineID,
		HeadDirection: headDirection,
		OrderedPath:   path,
	}

	return vine, localOccupied, nil
}

// chooseCircuitSeed chooses a starting position biased toward grid edges
func (p *CircuitBoardPlacer) chooseCircuitSeed(w, h int, occupied map[string]string, rng *rand.Rand) model.Point {
	// Try edge positions first (circuit board style)
	edgeCandidates := []model.Point{}

	// Helper to check if a position has at least one unoccupied neighbor
	hasUnoccupiedNeighbor := func(x, y int) bool {
		deltas := []model.Point{
			{X: 0, Y: -1}, {X: 0, Y: 1}, {X: -1, Y: 0}, {X: 1, Y: 0},
		}
		for _, d := range deltas {
			nx, ny := x+d.X, y+d.Y
			if nx >= 0 && nx < w && ny >= 0 && ny < h {
				_, occupied := occupied[fmt.Sprintf("%d,%d", nx, ny)]
				if !occupied {
					return true
				}
			}
		}
		return false
	}

	// Top and bottom edges
	for x := 0; x < w; x++ {
		key0 := fmt.Sprintf("%d,%d", x, 0)
		_, occupied0 := occupied[key0]
		if !occupied0 && hasUnoccupiedNeighbor(x, 0) {
			edgeCandidates = append(edgeCandidates, model.Point{X: x, Y: 0})
		}
		keyH := fmt.Sprintf("%d,%d", x, h-1)
		_, occupiedH := occupied[keyH]
		if !occupiedH && hasUnoccupiedNeighbor(x, h-1) {
			edgeCandidates = append(edgeCandidates, model.Point{X: x, Y: h - 1})
		}
	}

	// Left and right edges (excluding corners already added)
	for y := 1; y < h-1; y++ {
		keyL := fmt.Sprintf("%d,%d", 0, y)
		_, occupiedL := occupied[keyL]
		if !occupiedL && hasUnoccupiedNeighbor(0, y) {
			edgeCandidates = append(edgeCandidates, model.Point{X: 0, Y: y})
		}
		keyR := fmt.Sprintf("%d,%d", w-1, y)
		_, occupiedR := occupied[keyR]
		if !occupiedR && hasUnoccupiedNeighbor(w-1, y) {
			edgeCandidates = append(edgeCandidates, model.Point{X: w - 1, Y: y})
		}
	}

	// Prefer edges, but fall back to anywhere if needed
	if len(edgeCandidates) > 0 {
		return edgeCandidates[rng.Intn(len(edgeCandidates))]
	}

	// Fallback: any empty cell with unoccupied neighbors
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			_, isOccupied := occupied[key]
			if !isOccupied && hasUnoccupiedNeighbor(x, y) {
				return model.Point{X: x, Y: y}
			}
		}
	}

	panic("no empty cells with neighbors available") // Should not happen
}

// chooseInitialDirection chooses initial direction toward grid center
func (p *CircuitBoardPlacer) chooseInitialDirection(seed model.Point, w, h int, rng *rand.Rand) string {
	centerX, centerY := w/2, h/2

	// Prefer direction toward center
	dx := centerX - seed.X
	dy := centerY - seed.Y

	var preferredDirs []string

	if dx > 0 {
		preferredDirs = append(preferredDirs, "right")
	} else if dx < 0 {
		preferredDirs = append(preferredDirs, "left")
	}

	if dy > 0 {
		preferredDirs = append(preferredDirs, "up")
	} else if dy < 0 {
		preferredDirs = append(preferredDirs, "down")
	}

	if len(preferredDirs) > 0 {
		return preferredDirs[rng.Intn(len(preferredDirs))]
	}

	// Fallback to any direction
	dirs := []string{"up", "down", "left", "right"}
	return dirs[rng.Intn(len(dirs))]
}

// getAvailableNeighbors returns unoccupied neighboring cells
func (p *CircuitBoardPlacer) getAvailableNeighbors(pos model.Point, w, h int, globalOccupied, localOccupied map[string]string) []model.Point {
	deltas := []model.Point{
		{X: 0, Y: -1}, // up
		{X: 0, Y: 1},  // down
		{X: -1, Y: 0}, // left
		{X: 1, Y: 0},  // right
	}

	var neighbors []model.Point
	for _, d := range deltas {
		nx, ny := pos.X+d.X, pos.Y+d.Y
		if nx >= 0 && nx < w && ny >= 0 && ny < h {
			key := fmt.Sprintf("%d,%d", nx, ny)
			_, globallyOccupied := globalOccupied[key]
			_, locallyOccupied := localOccupied[key]
			if !globallyOccupied && !locallyOccupied {
				neighbors = append(neighbors, model.Point{X: nx, Y: ny})
			}
		}
	}

	return neighbors
}

// chooseCircuitSegment chooses the next segment with circuit-board preferences
func (p *CircuitBoardPlacer) chooseCircuitSegment(
	current model.Point,
	path []model.Point,
	neighbors []model.Point,
	w, h int,
	rng *rand.Rand,
) model.Point {

	if len(neighbors) == 1 {
		return neighbors[0]
	}

	// Score each neighbor for circuit-board aesthetics
	type scoredNeighbor struct {
		point model.Point
		score float64
	}

	scored := make([]scoredNeighbor, len(neighbors))
	for i, neighbor := range neighbors {
		score := 0.0

		// Prefer turns over straight continuation (circuit board winding)
		// But become much more flexible when vine is short or we need coverage
		if len(path) >= 2 {
			prev := path[len(path)-2]
			currDir := p.getDirection(prev, current)
			nextDir := p.getDirection(current, neighbor)

			if currDir != nextDir {
				score += 1.0 // Reduced bonus for turns
			} else {
				// Much reduced penalty for straight lines
				score -= 0.2 // Very light penalty
			}
		}

		// Prefer moving toward center (circuit boards route inward)
		centerX, centerY := float64(w)/2, float64(h)/2
		currDist := math.Abs(float64(current.X)-centerX) + math.Abs(float64(current.Y)-centerY)
		nextDist := math.Abs(float64(neighbor.X)-centerX) + math.Abs(float64(neighbor.Y)-centerY)

		if nextDist < currDist {
			score += 0.5 // Reduced bonus for moving toward center
		}

		// Small edge preference (but not too strong)
		edgeDist := p.getEdgeDistance(neighbor, w, h)
		score += edgeDist * 0.05

		// Add randomness to prevent deterministic patterns
		score += rng.Float64() * 0.3

		scored[i] = scoredNeighbor{point: neighbor, score: score}
	}

	// Sort by score descending
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].score > scored[j].score
	})

	// Much more flexible selection to allow better coverage
	randVal := rng.Float64()
	if randVal < 0.3 && len(scored) > 0 { // More likely to pick best
		return scored[0].point
	} else if randVal < 0.6 && len(scored) > 1 { // More likely to pick second best
		return scored[1].point
	} else if len(scored) > 2 {
		return scored[2].point
	}

	return scored[0].point
}

// getDirection returns the direction from a to b
func (p *CircuitBoardPlacer) getDirection(a, b model.Point) string {
	dx := b.X - a.X
	dy := b.Y - a.Y

	if dx == 1 && dy == 0 {
		return "right"
	} else if dx == -1 && dy == 0 {
		return "left"
	} else if dx == 0 && dy == 1 {
		return "up"
	} else if dx == 0 && dy == -1 {
		return "down"
	}

	return "unknown"
}

// getEdgeDistance returns manhattan distance to nearest edge
func (p *CircuitBoardPlacer) getEdgeDistance(pos model.Point, w, h int) float64 {
	distances := []float64{
		float64(pos.X),         // left edge
		float64(w - 1 - pos.X), // right edge
		float64(pos.Y),         // top edge
		float64(h - 1 - pos.Y), // bottom edge
	}

	minDist := distances[0]
	for _, d := range distances[1:] {
		if d < minDist {
			minDist = d
		}
	}

	return minDist
}

// calculateHeadDirection determines head direction from the first two segments
func (p *CircuitBoardPlacer) calculateHeadDirection(path []model.Point) string {
	if len(path) < 2 {
		return "up" // fallback
	}

	head := path[0]
	neck := path[1]

	dx := head.X - neck.X
	dy := head.Y - neck.Y

	if dx == 1 && dy == 0 {
		return "right"
	} else if dx == -1 && dy == 0 {
		return "left"
	} else if dx == 0 && dy == 1 {
		return "up"
	} else if dx == 0 && dy == -1 {
		return "down"
	}

	return "up" // fallback
}
