package gen2

import (
	"fmt"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// DirectionFirstPlacer implements VinePlacementStrategy using direction-first growth.
// This approach picks the exit direction first (toward nearest edge), then grows
// the vine body backward from the head, ensuring solvability-friendly layouts.
type DirectionFirstPlacer struct{}

// PlacementResult contains the result of a placement operation
type PlacementResult struct {
	Vines     []model.Vine
	Occupied  map[string]string
	Coverage  float64
	VineStats VinePlacementStats
}

// VinePlacementStats contains statistics about vine placement
type VinePlacementStats struct {
	TotalAttempts   int
	ExtensionPasses int
	FillerVines     int
}

// PlaceVines places vines using direction-first strategy with extension passes
func (p *DirectionFirstPlacer) PlaceVines(config GenerationConfig, rng *rand.Rand, stats *GenerationStats) ([]model.Vine, map[string]string, error) {
	w, h := config.GridWidth, config.GridHeight
	totalCells := w * h

	occupied := make(map[string]string)
	vines := make([]model.Vine, 0, config.VineCount)

	// Calculate target lengths based on difficulty
	lengths := p.calculateVineLengths(config, rng)

	common.Verbose("Placing %d vines with direction-first strategy", config.VineCount)

	// Phase 1: Place initial vines using direction-first growth
	for _, targetLen := range lengths {
		// Use dynamic ID based on current placed vines to avoid duplicates
		vineID := fmt.Sprintf("vine_%d", len(vines)+1)

		vine, newOccupied, err := p.growDirectionFirstVine(
			vineID, targetLen, w, h, occupied, rng,
		)
		if err != nil {
			// If we can't place a vine, log and continue
			common.Verbose("Could not place vine %s: %v", vineID, err)
			continue
		}

		vines = append(vines, vine)
		for k, v := range newOccupied {
			occupied[k] = v
		}

		common.Verbose("Placed vine %s with %d segments (target: %d)", vineID, len(vine.OrderedPath), targetLen)
	}

	// Phase 2: Extend existing vines that have room to grow
	coverage := float64(len(occupied)) / float64(totalCells)
	if coverage < config.MinCoverage {
		common.Verbose("Coverage %.1f%% below target %.1f%%, attempting extensions...", coverage*100, config.MinCoverage*100)
		vines, occupied = p.extendVines(vines, occupied, w, h, config.MinCoverage, rng)
		coverage = float64(len(occupied)) / float64(totalCells)
	}

	// Phase 3: Fill gaps with small filler vines (minimum 2 cells)
	if coverage < config.MinCoverage {
		common.Verbose("Coverage %.1f%% still below target, adding filler vines...", coverage*100)
		fillerVines, fillerOccupied := p.createFillerVines(vines, occupied, w, h, config.MinCoverage, rng)
		vines = append(vines, fillerVines...)
		for k, v := range fillerOccupied {
			occupied[k] = v
		}
		coverage = float64(len(occupied)) / float64(totalCells)
	}

	// Final coverage check
	occupiedCount := len(occupied)
	common.Verbose("Final coverage: %d/%d cells (%.1f%%)", occupiedCount, totalCells, coverage*100)

	if coverage < config.MinCoverage {
		return nil, nil, fmt.Errorf("insufficient coverage: %.1f%% (need ≥%.0f%%)", coverage*100, config.MinCoverage*100)
	}

	return vines, occupied, nil
}

// calculateVineLengths computes target lengths based on difficulty specs
func (p *DirectionFirstPlacer) calculateVineLengths(config GenerationConfig, rng *rand.Rand) []int {
	totalCells := config.GridWidth * config.GridHeight

	// Target total cells to fill based on coverage
	targetCells := int(float64(totalCells) * config.MinCoverage)

	// Average length per vine
	avgLength := targetCells / config.VineCount
	if avgLength < 2 {
		avgLength = 2 // Minimum length
	}

	// Create variety in lengths (some short, some long)
	minLength := 2 // Hard minimum
	maxLength := avgLength * 2
	if maxLength > totalCells/4 {
		maxLength = totalCells / 4
	}
	if maxLength < 3 {
		maxLength = 3
	}

	lengths := make([]int, config.VineCount)
	totalPlanned := 0

	for i := range lengths {
		// Distribute lengths with some variety
		base := minLength + rng.Intn(maxLength-minLength+1)
		lengths[i] = base
		totalPlanned += base
	}

	// Adjust to approximately hit target coverage
	for totalPlanned < targetCells && len(lengths) > 0 {
		idx := rng.Intn(len(lengths))
		if lengths[idx] < maxLength {
			lengths[idx]++
			totalPlanned++
		}
	}

	return lengths
}

// growDirectionFirstVine grows a vine using direction-first strategy:
// 1. Pick a seed cell
// 2. Choose head direction toward nearest edge (guarantees exit path)
// 3. Grow body backward from head
func (p *DirectionFirstPlacer) growDirectionFirstVine(
	vineID string,
	targetLen int,
	w, h int,
	occupied map[string]string,
	rng *rand.Rand,
) (model.Vine, map[string]string, error) {

	// Try multiple seeds to find one that works
	maxSeedAttempts := 20
	for attempt := 0; attempt < maxSeedAttempts; attempt++ {
		seed := p.chooseSeed(w, h, occupied, rng)
		if seed == nil {
			continue
		}

		// Determine head direction toward nearest edge
		headDirection := common.ChooseExitDirection(*seed, w, h)

		// The head is at the seed position
		// We grow the body BACKWARD (opposite to head direction)
		growDir := common.OppositeDirection(headDirection)

		// Start path with head
		path := []model.Point{*seed}
		localOccupied := make(map[string]string)
		localOccupied[fmt.Sprintf("%d,%d", seed.X, seed.Y)] = vineID

		// Grow the vine body
		for len(path) < targetLen {
			current := path[len(path)-1]

			// Get available neighbors, preferring the grow direction
			next := p.chooseNextCell(current, growDir, path, w, h, occupied, localOccupied, rng)
			if next == nil {
				break // Can't grow further
			}

			path = append(path, *next)
			localOccupied[fmt.Sprintf("%d,%d", next.X, next.Y)] = vineID
		}

		// Validate minimum length (2 cells)
		if len(path) < 2 {
			continue // Try another seed
		}

		vine := model.Vine{
			ID:            vineID,
			HeadDirection: headDirection,
			OrderedPath:   path,
		}

		return vine, localOccupied, nil
	}

	return model.Vine{}, nil, fmt.Errorf("could not find valid seed position after %d attempts", maxSeedAttempts)
}

// isEdgeCell returns true if the cell is on the edge of the grid
func isEdgeCell(x, y, w, h int) bool {
	return x == 0 || x == w-1 || y == 0 || y == h-1
}

// isCandidateCell checks if a cell is available and has a free neighbor
func (p *DirectionFirstPlacer) isCandidateCell(x, y, w, h int, occupied map[string]string) bool {
	key := fmt.Sprintf("%d,%d", x, y)
	if _, isOccupied := occupied[key]; isOccupied {
		return false
	}
	return p.hasFreeNeighbor(x, y, w, h, occupied)
}

// collectCandidateCells collects empty cells with free neighbors, categorized as edge or interior
func (p *DirectionFirstPlacer) collectCandidateCells(w, h int, occupied map[string]string) (edge, interior []model.Point) {
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if !p.isCandidateCell(x, y, w, h, occupied) {
				continue
			}
			pt := model.Point{X: x, Y: y}
			if isEdgeCell(x, y, w, h) {
				edge = append(edge, pt)
			} else {
				interior = append(interior, pt)
			}
		}
	}
	return edge, interior
}

// chooseSeed finds a suitable starting cell for a new vine
func (p *DirectionFirstPlacer) chooseSeed(w, h int, occupied map[string]string, rng *rand.Rand) *model.Point {
	edgeCandidates, interiorCandidates := p.collectCandidateCells(w, h, occupied)

	// Prefer edges (80% chance if available)
	if len(edgeCandidates) > 0 && (len(interiorCandidates) == 0 || rng.Float64() < 0.8) {
		return &edgeCandidates[rng.Intn(len(edgeCandidates))]
	}
	if len(interiorCandidates) > 0 {
		return &interiorCandidates[rng.Intn(len(interiorCandidates))]
	}

	return nil
}

// hasFreeNeighbor checks if a cell has at least one unoccupied orthogonal neighbor
func (p *DirectionFirstPlacer) hasFreeNeighbor(x, y, w, h int, occupied map[string]string) bool {
	deltas := []struct{ dx, dy int }{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
	for _, d := range deltas {
		nx, ny := x+d.dx, y+d.dy
		if nx >= 0 && nx < w && ny >= 0 && ny < h {
			key := fmt.Sprintf("%d,%d", nx, ny)
			if _, isOccupied := occupied[key]; !isOccupied {
				return true
			}
		}
	}
	return false
}

// scoredPoint pairs a point with its selection score
type scoredPoint struct {
	point model.Point
	score float64
}

// scoreNeighbor calculates a selection score for a neighbor cell
func (p *DirectionFirstPlacer) scoreNeighbor(
	current, neighbor model.Point,
	preferredDir string,
	w, h int,
	globalOccupied, localOccupied map[string]string,
	rng *rand.Rand,
) float64 {
	score := 0.0
	dir := common.DirectionFromPoints(current, neighbor)

	// Prefer the growth direction (opposite to head)
	if dir == preferredDir {
		score += 2.0
	}

	// Allow turns with moderate preference (for winding paths)
	for _, perpDir := range common.PerpendicularDirections(preferredDir) {
		if dir == perpDir {
			score += 1.0
			break
		}
	}

	// Slight preference for cells with more free neighbors (avoids dead ends)
	freeCount := p.countFreeNeighbors(neighbor, w, h, globalOccupied, localOccupied)
	score += float64(freeCount) * 0.3

	// Add randomness to prevent deterministic patterns
	score += rng.Float64() * 0.5
	return score
}

// chooseNextCell picks the next cell for vine growth, preferring the grow direction
func (p *DirectionFirstPlacer) chooseNextCell(
	current model.Point,
	preferredDir string,
	_ []model.Point, // path kept for interface compatibility
	w, h int,
	globalOccupied, localOccupied map[string]string,
	rng *rand.Rand,
) *model.Point {
	neighbors := p.getAvailableNeighbors(current, w, h, globalOccupied, localOccupied)
	if len(neighbors) == 0 {
		return nil
	}

	scoredNeighbors := make([]scoredPoint, len(neighbors))
	for i, neighbor := range neighbors {
		scoredNeighbors[i] = scoredPoint{
			point: neighbor,
			score: p.scoreNeighbor(current, neighbor, preferredDir, w, h, globalOccupied, localOccupied, rng),
		}
	}

	sort.Slice(scoredNeighbors, func(i, j int) bool {
		return scoredNeighbors[i].score > scoredNeighbors[j].score
	})

	// Weighted random selection: higher scores more likely
	if len(scoredNeighbors) > 1 && rng.Float64() < 0.7 {
		return &scoredNeighbors[0].point
	} else if len(scoredNeighbors) > 1 {
		return &scoredNeighbors[rng.Intn(len(scoredNeighbors))].point
	}

	return &scoredNeighbors[0].point
}

// getAvailableNeighbors returns unoccupied orthogonal neighbors
func (p *DirectionFirstPlacer) getAvailableNeighbors(pos model.Point, w, h int, globalOccupied, localOccupied map[string]string) []model.Point {
	deltas := []struct{ dx, dy int }{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
	var neighbors []model.Point

	for _, d := range deltas {
		nx, ny := pos.X+d.dx, pos.Y+d.dy
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

// countFreeNeighbors counts how many free neighbors a cell has
func (p *DirectionFirstPlacer) countFreeNeighbors(pos model.Point, w, h int, globalOccupied, localOccupied map[string]string) int {
	return len(p.getAvailableNeighbors(pos, w, h, globalOccupied, localOccupied))
}

// extendVines tries to extend existing vines from their tails
func (p *DirectionFirstPlacer) extendVines(
	vines []model.Vine,
	occupied map[string]string,
	w, h int,
	targetCoverage float64,
	rng *rand.Rand,
) ([]model.Vine, map[string]string) {
	totalCells := w * h
	targetCells := int(float64(totalCells) * targetCoverage)

	// Make a mutable copy
	result := make([]model.Vine, len(vines))
	copy(result, vines)

	maxPasses := 3
	for pass := 0; pass < maxPasses; pass++ {
		if len(occupied) >= targetCells {
			break
		}

		extended := false
		for i := range result {
			if len(occupied) >= targetCells {
				break
			}

			vine := &result[i]

			// Try to extend from the tail (last point in path)
			tail := vine.OrderedPath[len(vine.OrderedPath)-1]

			// Find available neighbors for the tail
			neighbors := p.getAvailableNeighbors(tail, w, h, occupied, nil)
			if len(neighbors) == 0 {
				continue
			}

			// Pick a random neighbor
			next := neighbors[rng.Intn(len(neighbors))]

			// Add to vine path
			vine.OrderedPath = append(vine.OrderedPath, next)
			key := fmt.Sprintf("%d,%d", next.X, next.Y)
			occupied[key] = vine.ID
			extended = true
		}

		if !extended {
			break // No progress, stop
		}
	}

	return result, occupied
}

// mergeOccupied combines two occupied maps into a new map
func mergeOccupied(a, b map[string]string) map[string]string {
	merged := make(map[string]string, len(a)+len(b))
	for k, v := range a {
		merged[k] = v
	}
	for k, v := range b {
		merged[k] = v
	}
	return merged
}

// createFillerVines creates small vines to fill remaining gaps (minimum 2 cells)
func (p *DirectionFirstPlacer) createFillerVines(
	existingVines []model.Vine,
	occupied map[string]string,
	w, h int,
	targetCoverage float64,
	rng *rand.Rand,
) ([]model.Vine, map[string]string) {
	targetCells := int(float64(w*h) * targetCoverage)
	fillerVines := []model.Vine{}
	fillerOccupied := make(map[string]string)
	// Compute next filler ID by scanning existing vine IDs to avoid collisions
	fillerID := 1
	for _, ev := range existingVines {
		var idx int
		if n, err := fmt.Sscanf(ev.ID, "vine_%d", &idx); n == 1 && err == nil {
			if idx >= fillerID {
				fillerID = idx + 1
			}
		}
	}

	for len(occupied)+len(fillerOccupied) < targetCells {
		seed := p.findFillerSeed(w, h, occupied, fillerOccupied, rng)
		if seed == nil {
			break
		}

		combined := mergeOccupied(occupied, fillerOccupied)
		neighbors := p.getAvailableNeighbors(*seed, w, h, combined, nil)
		if len(neighbors) == 0 {
			fillerOccupied[fmt.Sprintf("%d,%d", seed.X, seed.Y)] = "skip"
			continue
		}

		vine, newOccupied := p.buildFillerVine(seed, neighbors, fillerID, rng)
		fillerVines = append(fillerVines, vine)
		for k, v := range newOccupied {
			fillerOccupied[k] = v
		}
		fillerID++
	}

	// Remove skip markers
	for k, v := range fillerOccupied {
		if v == "skip" {
			delete(fillerOccupied, k)
		}
	}
	return fillerVines, fillerOccupied
}

// buildFillerVine creates a 2-cell filler vine from a seed and its neighbors
func (p *DirectionFirstPlacer) buildFillerVine(
	seed *model.Point,
	neighbors []model.Point,
	fillerID int,
	rng *rand.Rand,
) (model.Vine, map[string]string) {
	neighbor := neighbors[rng.Intn(len(neighbors))]
	headDir := common.DirectionFromPoints(neighbor, *seed)
	if headDir == "" {
		headDir = common.DirUp
	}

	vineID := fmt.Sprintf("vine_%d", fillerID)
	vine := model.Vine{
		ID:            vineID,
		HeadDirection: headDir,
		OrderedPath:   []model.Point{*seed, neighbor},
	}

	newOccupied := map[string]string{
		fmt.Sprintf("%d,%d", seed.X, seed.Y):         vineID,
		fmt.Sprintf("%d,%d", neighbor.X, neighbor.Y): vineID,
	}
	return vine, newOccupied
}

// findFillerSeed finds an empty cell that can form a 2-cell filler vine
func (p *DirectionFirstPlacer) findFillerSeed(w, h int, occupied, fillerOccupied map[string]string, rng *rand.Rand) *model.Point {
	combined := mergeOccupied(occupied, fillerOccupied)
	candidates := p.collectFillerCandidates(w, h, combined)
	if len(candidates) == 0 {
		return nil
	}
	return &candidates[rng.Intn(len(candidates))]
}

// collectFillerCandidates gathers all empty cells that have at least one free neighbor
func (p *DirectionFirstPlacer) collectFillerCandidates(w, h int, combined map[string]string) []model.Point {
	var candidates []model.Point
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if _, occ := combined[key]; occ {
				continue
			}
			neighbors := p.getAvailableNeighbors(model.Point{X: x, Y: y}, w, h, combined, nil)
			if len(neighbors) > 0 {
				candidates = append(candidates, model.Point{X: x, Y: y})
			}
		}
	}
	return candidates
}
