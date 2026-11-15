package strategies

import (
	"fmt"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// DirectionFirstPlacer implements VinePlacementStrategy using direction-first growth.
// This approach picks the exit direction first (toward nearest edge), then grows
// the vine body backward from the head, ensuring solvability-friendly layouts.
type DirectionFirstPlacer struct {
	turnMix      float64
	freeHeadBias float64
	minAccept    int
	vineTarget   int
	dirCounts    map[string]int
}

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
func (p *DirectionFirstPlacer) PlaceVines(config config.GenerationConfig, rng *rand.Rand, stats *config.GenerationStats) ([]model.Vine, map[string]string, error) {
	p.turnMix = config.Profile.TurnMix
	p.freeHeadBias = config.Profile.FreeHeadBias
	if p.freeHeadBias <= 0 {
		p.freeHeadBias = 1
	}
	p.minAccept = lengthFloorFor(config.Difficulty)
	p.vineTarget = config.VineCount
	if p.vineTarget < 8 {
		p.vineTarget = 8
	}
	p.dirCounts = map[string]int{"up": 0, "down": 0, "left": 0, "right": 0}
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
		p.dirCounts[vine.HeadDirection]++
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

	// Phase 3: Fill gaps with small filler vines (minimum 2 cells).
	// Skip this once a tier has a length floor. Pairs pull the average
	// under the band; the pipeline extends tails and masks the rest.
	if coverage < config.MinCoverage && p.minAccept <= 2 {
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

	// Aim at MinCoverage. Accept the design floor so a shortfall still
	// reaches the pipeline. Below the floor, keep the vines when there
	// are enough for the pipeline to recover.
	floor := occupancyFloor(config.Difficulty, config.MinCoverage)
	if coverage < floor {
		err := fmt.Errorf("insufficient coverage: %.1f%% (need ≥%.0f%%)", coverage*100, floor*100)
		if len(vines) >= 2 {
			return vines, occupied, err
		}
		return nil, nil, err
	}

	return vines, occupied, nil
}

// occupancyFloor is the hard minimum a placer may treat as success.
// MinCoverage is the aim. The pipeline fills and masks the gap between them.
func occupancyFloor(difficulty string, aim float64) float64 {
	spec, ok := config.DifficultySpecs[difficulty]
	if !ok || spec.MinGridOccupancy <= 0 || spec.MinGridOccupancy >= aim {
		return aim
	}
	return spec.MinGridOccupancy
}

// lengthFloorFor is the shortest vine a tier may keep. Lengths of 3 and
// below count as short vines in the generation contract.
func lengthFloorFor(difficulty string) int {
	spec, ok := config.DifficultySpecs[difficulty]
	if !ok || spec.AvgLengthRange[0] < 6 {
		return 2
	}
	floor := spec.AvgLengthRange[0] - 2
	if floor < 4 {
		floor = 4
	}
	return floor
}

// calculateVineLengths computes target lengths based on difficulty specs
func (p *DirectionFirstPlacer) calculateVineLengths(config config.GenerationConfig, rng *rand.Rand) []int {
	totalCells := config.GridWidth * config.GridHeight

	// Target total cells to fill based on coverage
	targetCells := int(float64(totalCells) * config.MinCoverage)

	// Average length per vine
	avgLength := targetCells / config.VineCount
	minLength := lengthFloorFor(config.Difficulty)
	if avgLength < minLength {
		avgLength = minLength
	}
	maxLength := avgLength * 2
	if maxLength > totalCells/4 {
		maxLength = totalCells / 4
	}
	if maxLength < minLength {
		maxLength = minLength
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

		headDirection := p.chooseHeadDirection(*seed, w, h, rng)

		// The head is at the seed position
		// We grow the body BACKWARD (opposite to head direction)
		growDir := common.OppositeDirection(headDirection)

		// Start path with head
		path := []model.Point{*seed}
		localOccupied := make(map[string]string)
		localOccupied[common.PointKey(*seed)] = vineID

		// Grow the vine body
		for len(path) < targetLen {
			current := path[len(path)-1]

			var next *model.Point
			if len(path) == 1 {
				// CRITICAL: The first growth step (neck) MUST be in the grow direction
				// to match the chosen headDirection.
				dx, dy := common.DeltaForDirection(growDir)
				cand := model.Point{X: current.X + dx, Y: current.Y + dy}
				if cand.X >= 0 && cand.X < w && cand.Y >= 0 && cand.Y < h {
					key := common.PointKey(cand)
					if _, globallyOcc := occupied[key]; !globallyOcc {
						next = &cand
					}
				}
			} else {
				// Subsequent segments can turn
				next = p.chooseNextCell(current, growDir, path, w, h, occupied, localOccupied, rng)
			}

			if next == nil {
				break // Can't grow further
			}

			path = append(path, *next)
			localOccupied[common.PointKey(*next)] = vineID
		}

		// Reject vines under the tier length floor. A short accept fills
		// the board with pairs and the average never reaches the band.
		need := p.minAccept
		if need < 2 {
			need = 2
		}
		if len(path) < need {
			continue
		}

		vine := model.Vine{
			ID:            vineID,
			HeadDirection: headDirection,
			OrderedPath:   path,
		}
		if vineSelfBlocks(vine, w, h) {
			continue
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
	key := common.PointKey(model.Point{X: x, Y: y})
	if _, isOccupied := occupied[key]; isOccupied {
		return false
	}
	return p.hasFreeNeighbor(x, y, w, h, occupied)
}

// collectCandidateCells collects empty cells with free neighbors, categorized as corner, edge or interior
func (p *DirectionFirstPlacer) collectCandidateCells(w, h int, occupied map[string]string) (corner, edge, interior []model.Point) {
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if !p.isCandidateCell(x, y, w, h, occupied) {
				continue
			}
			pt := model.Point{X: x, Y: y}
			if p.isCornerCell(x, y, w, h) {
				corner = append(corner, pt)
			} else if isEdgeCell(x, y, w, h) {
				edge = append(edge, pt)
			} else {
				interior = append(interior, pt)
			}
		}
	}
	return corner, edge, interior
}

func (p *DirectionFirstPlacer) chooseHeadDirection(seed model.Point, w, h int, rng *rand.Rand) string {
	if dir := directionDeficit(p.dirCounts, p.vineTarget); dir != "" {
		return dir
	}
	if p.freeHeadBias >= 1 || rng.Float64() < p.freeHeadBias {
		return common.ChooseExitDirection(seed, w, h)
	}
	return common.FarthestExitDirection(seed, w, h)
}

// chooseSeed finds a suitable starting cell for a new vine
func (p *DirectionFirstPlacer) chooseSeed(w, h int, occupied map[string]string, rng *rand.Rand) *model.Point {
	// Openers pin a missing direction to its edge so the head is free.
	// Later slots only steer the direction, leaving the ray blocked.
	if p.freeHeadBias >= 0.5 {
		if dir := directionDeficit(p.dirCounts, p.vineTarget); dir != "" {
			if seed := p.seedForDirection(dir, w, h, occupied, rng); seed != nil {
				return seed
			}
		}
	}
	cornerCandidates, edgeCandidates, interiorCandidates := p.collectCandidateCells(w, h, occupied)

	// Prefer corners (90% chance if available)
	if len(cornerCandidates) > 0 && rng.Float64() < 0.9 {
		return &cornerCandidates[rng.Intn(len(cornerCandidates))]
	}

	// Then prefer edges (80% chance if available)
	if len(edgeCandidates) > 0 && (len(interiorCandidates) == 0 || rng.Float64() < 0.8) {
		return &edgeCandidates[rng.Intn(len(edgeCandidates))]
	}

	if len(interiorCandidates) > 0 {
		return &interiorCandidates[rng.Intn(len(interiorCandidates))]
	}

	// Fallback to any available if preferences failed but candidates exist (e.g. only corners left but rng > 0.9)
	if len(cornerCandidates) > 0 {
		return &cornerCandidates[rng.Intn(len(cornerCandidates))]
	}

	return nil
}

func (p *DirectionFirstPlacer) seedForDirection(dir string, w, h int, occupied map[string]string, rng *rand.Rand) *model.Point {
	occ := make(map[string]bool, len(occupied))
	for k := range occupied {
		occ[k] = true
	}
	pt, ok := pickDirectionalSeed(occ, []int{w, h}, dir, rng)
	if !ok {
		return nil
	}
	return &pt
}

func (p *DirectionFirstPlacer) isCornerCell(x, y, w, h int) bool {
	return (x == 0 || x == w-1) && (y == 0 || y == h-1)
}

// hasFreeNeighbor checks if a cell has at least one unoccupied orthogonal neighbor
func (p *DirectionFirstPlacer) hasFreeNeighbor(x, y, w, h int, occupied map[string]string) bool {
	deltas := []struct{ dx, dy int }{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
	for _, d := range deltas {
		nx, ny := x+d.dx, y+d.dy
		if nx >= 0 && nx < w && ny >= 0 && ny < h {
			key := common.PointKey(model.Point{X: nx, Y: ny})
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

	straightBonus := 1.5
	turnBonus := 1.5
	if p.turnMix > 0 {
		straightBonus = 2.0 * (1 - p.turnMix)
		turnBonus = 2.0 * p.turnMix
	}

	// Prefer the growth direction (opposite to head)
	if dir == preferredDir {
		score += straightBonus
	}

	// Turn preference. A higher TurnMix winds the vine instead of running straight.
	for _, perpDir := range common.PerpendicularDirections(preferredDir) {
		if dir == perpDir {
			score += turnBonus
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
			key := common.PointKey(model.Point{X: nx, Y: ny})
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

			// Add to vine path only when the ray stays clear of this vine
			// and the board is still greedy-solvable.
			vine.OrderedPath = append(vine.OrderedPath, next)
			key := common.PointKey(next)
			occupied[key] = vine.ID
			if vineSelfBlocks(*vine, w, h) || !greedySolvable(result, w, h) {
				vine.OrderedPath = vine.OrderedPath[:len(vine.OrderedPath)-1]
				delete(occupied, key)
				continue
			}
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
			fillerOccupied[common.PointKey(*seed)] = "skip"
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
		common.PointKey(*seed):    vineID,
		common.PointKey(neighbor): vineID,
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
			key := common.PointKey(model.Point{X: x, Y: y})
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
