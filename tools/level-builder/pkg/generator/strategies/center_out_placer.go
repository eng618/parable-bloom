package strategies

import (
	"fmt"
	"math"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// CenterOutPlacer implements a center-out vine placement strategy with LIFO solvability guarantee.
// Key insight: if each vine has a clear exit path when placed, solving in reverse order is always valid.
// This eliminates expensive A* solver checks entirely.
type CenterOutPlacer struct{}

// PlaceVines places vines from center outward, guaranteeing each has a clear exit at placement time.
// Returns vines that can be solved in LIFO order (last placed = first cleared).
func (p *CenterOutPlacer) PlaceVines(config config.GenerationConfig, rng *rand.Rand, stats *config.GenerationStats) ([]model.Vine, map[string]string, error) {
	w, h := config.GridWidth, config.GridHeight
	totalCells := w * h
	occupied := make(map[string]string)

	// Calculate target lengths based on difficulty
	targetLengths := p.calculateVineLengths(config, rng)
	common.Verbose("Target vine lengths: %v", targetLengths)

	var vines []model.Vine
	var coverage float64

	// Phase 1: Place vines from center outward with LIFO guarantee
	for _, targetLen := range targetLengths {
		// Use dynamic ID based on current placed vines to avoid duplicates
		vineID := fmt.Sprintf("vine_%d", len(vines)+1)

		vine, newOccupied, err := p.placeVineWithExitGuarantee(
			vineID, targetLen, w, h, occupied, rng, stats,
		)
		if err != nil {
			common.Verbose("Could not place vine %s: %v", vineID, err)

			// Delegate to AttemptLocalBacktrack (modularized)
			vineRecovered, _, updatedVines, updatedOccupied, btErr := AttemptLocalBacktrack(vines, occupied, vineID, targetLen, p, w, h, rng, config, stats)
			if btErr != nil {
				common.Verbose("Local backtracking failed for %s: %v", vineID, btErr)
				continue
			}

			// Use recovered vine and updated state
			vines = updatedVines
			occupied = updatedOccupied
			vine = vineRecovered
		}

		// Merge newly-occupied cells from a successful placement into the global occupied map
		for k, v := range newOccupied {
			occupied[k] = v
		}

		// Avoid double-appending if recovered state already includes the vine
		exists := false
		for _, v := range vines {
			if v.ID == vine.ID {
				exists = true
				break
			}
		}
		if !exists {
			vines = append(vines, vine)
		}

		// Update coverage and early exit if we've achieved target coverage
		coverage = float64(len(occupied)) / float64(totalCells)
		if coverage >= config.MinCoverage {
			common.Verbose("Achieved target coverage %.1f%%, stopping placement", coverage*100)
			break
		}
	}

	// Phase 2: Fill remaining gaps with 2-cell filler vines (LIFO guaranteed)
	coverage = float64(len(occupied)) / float64(totalCells)
	if coverage < config.MinCoverage {
		common.Verbose("Coverage %.1f%% below target %.1f%%, adding filler vines...", coverage*100, config.MinCoverage*100)
		fillerVines, fillerOccupied := p.createFillerVines(vines, occupied, w, h, config.MinCoverage, rng)
		vines = append(vines, fillerVines...)
		for k, v := range fillerOccupied {
			occupied[k] = v
		}
		coverage = float64(len(occupied)) / float64(totalCells)
	}

	// Final coverage report
	common.Verbose("Final coverage: %d/%d cells (%.1f%%)", len(occupied), totalCells, coverage*100)

	if len(vines) < 2 {
		return nil, nil, fmt.Errorf("insufficient vines placed: %d (need at least 2)", len(vines))
	}

	return vines, occupied, nil
}

// placeVineWithExitGuarantee places a single vine with guaranteed clear exit path (LIFO principle)
func (p *CenterOutPlacer) placeVineWithExitGuarantee(
	vineID string,
	targetLen int,
	w, h int,
	occupied map[string]string,
	rng *rand.Rand,
	stats *config.GenerationStats,
) (model.Vine, map[string]string, error) {
	const maxAttempts = 100

	for attempt := 0; attempt < maxAttempts; attempt++ {
		if stats != nil {
			stats.PlacementAttempts++
		}
		// Choose seed cell (center-biased)
		seed := p.chooseCenterSeed(w, h, occupied, rng)
		if seed == nil {
			continue
		}

		// Choose head direction toward nearest edge
		headDir := common.ChooseExitDirection(*seed, w, h)

		// CRITICAL: Verify exit path is clear BEFORE growing
		if !common.IsExitPathClear(*seed, headDir, w, h, occupied) {
			// Try other directions
			headDir = p.findClearExitDirection(*seed, w, h, occupied)
			if headDir == "" {
				continue // No clear exit from this seed
			}
		}

		// Grow body opposite to head direction (toward center)
		vine, localOccupied := p.growVineBody(vineID, *seed, headDir, targetLen, w, h, occupied, rng)
		if vine.ID != "" && len(vine.OrderedPath) >= 2 {
			return vine, localOccupied, nil
		}
	}

	return model.Vine{}, nil, fmt.Errorf("could not place vine with clear exit after %d attempts", maxAttempts)
}

// chooseCenterSeed selects a seed cell biased toward the grid center
func (p *CenterOutPlacer) chooseCenterSeed(w, h int, occupied map[string]string, rng *rand.Rand) *model.Point {
	centerX, centerY := float64(w)/2.0, float64(h)/2.0

	// Collect all empty cells with at least one free neighbor
	var candidates []model.Point
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if _, occ := occupied[key]; occ {
				continue
			}
			if !p.hasFreeNeighbor(x, y, w, h, occupied) {
				continue
			}
			candidates = append(candidates, model.Point{X: x, Y: y})
		}
	}

	if len(candidates) == 0 {
		return nil
	}

	// Sort by distance from center (closest first)
	sort.Slice(candidates, func(i, j int) bool {
		distI := math.Abs(float64(candidates[i].X)-centerX) + math.Abs(float64(candidates[i].Y)-centerY)
		distJ := math.Abs(float64(candidates[j].X)-centerX) + math.Abs(float64(candidates[j].Y)-centerY)
		return distI < distJ
	})

	// Pick from closest N candidates with some randomness (prevents deterministic patterns)
	topN := len(candidates) / 4
	if topN < 5 {
		topN = 5
	}
	if topN > len(candidates) {
		topN = len(candidates)
	}

	return &candidates[rng.Intn(topN)]
}

// findClearExitDirection finds any direction with a clear exit path
func (p *CenterOutPlacer) findClearExitDirection(pos model.Point, w, h int, occupied map[string]string) string {
	// Try directions in order of shortest path to edge
	type dirDist struct {
		dir  string
		dist int
	}

	dirs := []dirDist{
		{common.DirLeft, pos.X},
		{common.DirRight, w - 1 - pos.X},
		{common.DirDown, pos.Y},
		{common.DirUp, h - 1 - pos.Y},
	}

	sort.Slice(dirs, func(i, j int) bool {
		return dirs[i].dist < dirs[j].dist
	})

	for _, d := range dirs {
		if common.IsExitPathClear(pos, d.dir, w, h, occupied) {
			return d.dir
		}
	}

	return "" // No clear exit
}

// growVineBody grows the vine body opposite to head direction
func (p *CenterOutPlacer) growVineBody(
	vineID string,
	head model.Point,
	headDir string,
	targetLen int,
	w, h int,
	globalOccupied map[string]string,
	rng *rand.Rand,
) (model.Vine, map[string]string) {
	localOccupied := make(map[string]string)
	path := []model.Point{head}
	localOccupied[fmt.Sprintf("%d,%d", head.X, head.Y)] = vineID

	// Place neck (must be opposite to head direction)
	growDir := common.OppositeDirection(headDir)
	neck, neckValid := p.placeNeck(head, growDir, w, h, globalOccupied)
	if !neckValid {
		return model.Vine{}, nil
	}

	path = append(path, neck)
	localOccupied[fmt.Sprintf("%d,%d", neck.X, neck.Y)] = vineID

	// Grow remaining body segments
	ctx := &growContext{
		w: w, h: h,
		globalOccupied: globalOccupied,
		localOccupied:  localOccupied,
		vineID:         vineID,
		rng:            rng,
	}
	path = p.growRemainingBody(path, neck, growDir, targetLen, ctx)

	if len(path) < 2 {
		return model.Vine{}, nil
	}

	return model.Vine{
		ID:            vineID,
		HeadDirection: headDir,
		OrderedPath:   path,
	}, localOccupied
}

// placeNeck places the neck segment opposite to head direction
func (p *CenterOutPlacer) placeNeck(head model.Point, growDir string, w, h int, globalOccupied map[string]string) (model.Point, bool) {
	dx, dy := common.DeltaForDirection(growDir)
	neck := model.Point{X: head.X + dx, Y: head.Y + dy}

	if neck.X < 0 || neck.X >= w || neck.Y < 0 || neck.Y >= h {
		return model.Point{}, false
	}

	neckKey := fmt.Sprintf("%d,%d", neck.X, neck.Y)
	if _, occupied := globalOccupied[neckKey]; occupied {
		return model.Point{}, false
	}

	return neck, true
}

// growContext holds state for vine body growth
type growContext struct {
	w, h           int
	globalOccupied map[string]string
	localOccupied  map[string]string
	vineID         string
	rng            *rand.Rand
}

// growRemainingBody continues vine growth after head and neck are placed
func (p *CenterOutPlacer) growRemainingBody(
	path []model.Point,
	current model.Point,
	growDir string,
	targetLen int,
	ctx *growContext,
) []model.Point {
	for len(path) < targetLen {
		next := p.chooseNextGrowthCell(current, growDir, ctx)
		if next == nil {
			break
		}
		path = append(path, *next)
		ctx.localOccupied[fmt.Sprintf("%d,%d", next.X, next.Y)] = ctx.vineID
		current = *next
	}
	return path
}

// chooseNextGrowthCell picks the next cell for vine growth
func (p *CenterOutPlacer) chooseNextGrowthCell(
	current model.Point,
	preferredDir string,
	ctx *growContext,
) *model.Point {
	neighbors := p.getAvailableNeighbors(current, ctx.w, ctx.h, ctx.globalOccupied, ctx.localOccupied)
	if len(neighbors) == 0 {
		return nil
	}

	// Score neighbors: prefer growth direction, allow turns
	type scored struct {
		pt    model.Point
		score float64
	}

	var scoredNeighbors []scored

	// Baseline verification: Count reachable cells before move
	// This is expensive but necessary for high coverage
	baselineReachable := p.countReachableEmptyCells(ctx.w, ctx.h, ctx.globalOccupied, ctx.localOccupied)

	for _, n := range neighbors {
		// Verify this move doesn't disconnect the grid
		// Temporarily mark n as occupied
		ctx.localOccupied[fmt.Sprintf("%d,%d", n.X, n.Y)] = ctx.vineID
		newReachable := p.countReachableEmptyCells(ctx.w, ctx.h, ctx.globalOccupied, ctx.localOccupied)
		delete(ctx.localOccupied, fmt.Sprintf("%d,%d", n.X, n.Y))

		// If we lose more than 1 reachable cell (the one we just took), we caused a disconnect
		if newReachable < baselineReachable-1 {
			continue // Skip this move, it creates an island
		}

		dir := common.DirectionFromPoints(current, n)
		score := 0.0

		if dir == preferredDir {
			score += 1.5 // Balanced preference for forward growth
		}
		for _, perpDir := range common.PerpendicularDirections(preferredDir) {
			if dir == perpDir {
				score += 1.5 // Balanced preference for turns
				break
			}
		}

		// Check immediate neighbor availability (freeCount)
		nNeighbors := p.getAvailableNeighbors(n, ctx.w, ctx.h, ctx.globalOccupied, ctx.localOccupied)
		freeCount := len(nNeighbors)
		score += float64(freeCount) * 0.8

		score += ctx.rng.Float64() * 0.5 // Randomness

		scoredNeighbors = append(scoredNeighbors, scored{pt: n, score: score})
	}

	sort.Slice(scoredNeighbors, func(i, j int) bool {
		return scoredNeighbors[i].score > scoredNeighbors[j].score
	})

	// Weighted selection
	if len(scoredNeighbors) > 1 && ctx.rng.Float64() < 0.8 {
		return &scoredNeighbors[0].pt
	}
	if len(scoredNeighbors) > 0 {
		return &scoredNeighbors[ctx.rng.Intn(len(scoredNeighbors))].pt
	}
	return nil
}

// countReachableEmptyCells returns the number of empty cells reachable from the edge
func (p *CenterOutPlacer) countReachableEmptyCells(w, h int, globalOccupied, localOccupied map[string]string) int {
	queue := []model.Point{}
	visited := make(map[string]bool)

	// Add all empty edge cells to queue
	for x := 0; x < w; x++ {
		p1, p2 := model.Point{X: x, Y: 0}, model.Point{X: x, Y: h - 1}
		if !p.isOccupied(p1, globalOccupied, localOccupied) {
			queue = append(queue, p1)
			visited[fmt.Sprintf("%d,%d", x, 0)] = true
		}
		if !p.isOccupied(p2, globalOccupied, localOccupied) {
			queue = append(queue, p2)
			visited[fmt.Sprintf("%d,%d", x, h-1)] = true
		}
	}
	for y := 1; y < h-1; y++ {
		p1, p2 := model.Point{X: 0, Y: y}, model.Point{X: w - 1, Y: y}
		if !p.isOccupied(p1, globalOccupied, localOccupied) {
			queue = append(queue, p1)
			visited[fmt.Sprintf("0,%d", y)] = true
		}
		if !p.isOccupied(p2, globalOccupied, localOccupied) {
			queue = append(queue, p2)
			visited[fmt.Sprintf("%d,%d", w-1, y)] = true
		}
	}

	count := 0
	deltas := []struct{ dx, dy int }{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}

	for len(queue) > 0 {
		curr := queue[0]
		queue = queue[1:]
		count++

		for _, d := range deltas {
			nx, ny := curr.X+d.dx, curr.Y+d.dy
			if nx >= 0 && nx < w && ny >= 0 && ny < h {
				key := fmt.Sprintf("%d,%d", nx, ny)
				if !visited[key] && !p.isOccupied(model.Point{X: nx, Y: ny}, globalOccupied, localOccupied) {
					visited[key] = true
					queue = append(queue, model.Point{X: nx, Y: ny})
				}
			}
		}
	}
	return count
}

func (p *CenterOutPlacer) isOccupied(pt model.Point, global, local map[string]string) bool {
	key := fmt.Sprintf("%d,%d", pt.X, pt.Y)
	_, g := global[key]
	_, l := local[key]
	return g || l
}

// getAvailableNeighbors returns unoccupied orthogonal neighbors
func (p *CenterOutPlacer) getAvailableNeighbors(pos model.Point, w, h int, globalOccupied, localOccupied map[string]string) []model.Point {
	deltas := []struct{ dx, dy int }{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
	var neighbors []model.Point

	for _, d := range deltas {
		nx, ny := pos.X+d.dx, pos.Y+d.dy
		if nx >= 0 && nx < w && ny >= 0 && ny < h {
			key := fmt.Sprintf("%d,%d", nx, ny)
			_, globallyOcc := globalOccupied[key]
			_, locallyOcc := localOccupied[key]
			if !globallyOcc && !locallyOcc {
				neighbors = append(neighbors, model.Point{X: nx, Y: ny})
			}
		}
	}

	return neighbors
}

// hasFreeNeighbor checks if a cell has at least one unoccupied neighbor
func (p *CenterOutPlacer) hasFreeNeighbor(x, y, w, h int, occupied map[string]string) bool {
	deltas := []struct{ dx, dy int }{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
	for _, d := range deltas {
		nx, ny := x+d.dx, y+d.dy
		if nx >= 0 && nx < w && ny >= 0 && ny < h {
			key := fmt.Sprintf("%d,%d", nx, ny)
			if _, occ := occupied[key]; !occ {
				return true
			}
		}
	}
	return false
}

// calculateVineLengths computes target lengths based on difficulty
func (p *CenterOutPlacer) calculateVineLengths(genConfig config.GenerationConfig, rng *rand.Rand) []int {
	totalCells := genConfig.GridWidth * genConfig.GridHeight

	// Target to fill most of the grid
	targetFill := int(float64(totalCells) * genConfig.MinCoverage)

	// Get average length from difficulty specs
	avgLen := 5 // Default
	if spec, ok := config.DifficultySpecs[genConfig.Difficulty]; ok {
		avgLen = (spec.AvgLengthRange[0] + spec.AvgLengthRange[1]) / 2
	}

	// Calculate how many vines we need
	vineCount := targetFill / avgLen
	if vineCount < genConfig.VineCount {
		vineCount = genConfig.VineCount
	}

	// Generate lengths with variance
	lengths := make([]int, vineCount)
	for i := range lengths {
		variance := rng.Intn(3) - 1 // -1, 0, or +1
		length := avgLen + variance
		if length < 2 {
			length = 2
		}
		// Cap length to prevent overly long vines
		maxLen := (genConfig.GridWidth + genConfig.GridHeight) / 2
		if length > maxLen {
			length = maxLen
		}
		lengths[i] = length
	}

	return lengths
}

// createFillerVines creates 2-cell filler vines for remaining gaps
// Uses LIFO-guaranteed placement first, then falls back to non-LIFO placement
func (p *CenterOutPlacer) createFillerVines(
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

	// Phase 1: LIFO-guaranteed fillers (heads with clear exit)
	vines1, occ1, _ := p.fillWithLIFOGuarantee(fillerID, occupied, w, h, targetCells, rng)
	fillerVines = append(fillerVines, vines1...)
	for k, v := range occ1 {
		fillerOccupied[k] = v
	}

	return fillerVines, fillerOccupied
}

// fillWithLIFOGuarantee places filler vines with guaranteed clear exit paths
func (p *CenterOutPlacer) fillWithLIFOGuarantee(
	startID int,
	occupied map[string]string,
	w, h int,
	targetCells int,
	rng *rand.Rand,
) ([]model.Vine, map[string]string, int) {
	vines := []model.Vine{}
	fillerOccupied := make(map[string]string)
	fillerID := startID
	maxIterations := w * h * 3
	lastCoverage := len(occupied)

	for i := 0; i < maxIterations; i++ {
		combined := mergeOccupied(occupied, fillerOccupied)
		currentCoverage := len(combined)

		if currentCoverage >= targetCells {
			break
		}
		if i > 10 && currentCoverage == lastCoverage {
			break
		}
		lastCoverage = currentCoverage

		vine, vineOccupied := p.tryPlaceFillerVine(fmt.Sprintf("vine_%d", fillerID), w, h, combined, rng)
		if vine.ID == "" {
			vine, vineOccupied = p.tryPlaceEdgeFillerVine(fmt.Sprintf("vine_%d", fillerID), w, h, combined, rng)
		}
		if vine.ID == "" {
			break
		}

		vines = append(vines, vine)
		for k, v := range vineOccupied {
			fillerOccupied[k] = v
		}
		fillerID++
	}

	return vines, fillerOccupied, fillerID
}

// edgeCandidate represents an edge cell with its exit direction
type edgeCandidate struct {
	pt  model.Point
	dir string
}

// collectEdgeCells gathers all empty edge cells with their exit directions
func (p *CenterOutPlacer) collectEdgeCells(w, h int, occupied map[string]string) []edgeCandidate {
	var edgeCells []edgeCandidate

	// Top and bottom edges
	for x := 0; x < w; x++ {
		topKey := fmt.Sprintf("%d,%d", x, h-1)
		if _, occ := occupied[topKey]; !occ {
			edgeCells = append(edgeCells, edgeCandidate{model.Point{X: x, Y: h - 1}, "up"})
		}
		bottomKey := fmt.Sprintf("%d,%d", x, 0)
		if _, occ := occupied[bottomKey]; !occ {
			edgeCells = append(edgeCells, edgeCandidate{model.Point{X: x, Y: 0}, "down"})
		}
	}

	// Left and right edges
	for y := 0; y < h; y++ {
		leftKey := fmt.Sprintf("%d,%d", 0, y)
		if _, occ := occupied[leftKey]; !occ {
			edgeCells = append(edgeCells, edgeCandidate{model.Point{X: 0, Y: y}, "left"})
		}
		rightKey := fmt.Sprintf("%d,%d", w-1, y)
		if _, occ := occupied[rightKey]; !occ {
			edgeCells = append(edgeCells, edgeCandidate{model.Point{X: w - 1, Y: y}, "right"})
		}
	}

	return edgeCells
}

// tryPlaceEdgeFillerVine tries to place a filler vine with head at an edge
func (p *CenterOutPlacer) tryPlaceEdgeFillerVine(
	vineID string,
	w, h int,
	occupied map[string]string,
	rng *rand.Rand,
) (model.Vine, map[string]string) {
	edgeCells := p.collectEdgeCells(w, h, occupied)
	if len(edgeCells) == 0 {
		return model.Vine{}, nil
	}

	rng.Shuffle(len(edgeCells), func(i, j int) {
		edgeCells[i], edgeCells[j] = edgeCells[j], edgeCells[i]
	})

	for _, ec := range edgeCells {
		vine, vineOccupied := p.tryCreateEdgeVine(vineID, ec.pt, ec.dir, w, h, occupied)
		if vine.ID != "" {
			return vine, vineOccupied
		}
	}

	return model.Vine{}, nil
}

// tryCreateEdgeVine attempts to create a 2-cell vine from an edge cell
func (p *CenterOutPlacer) tryCreateEdgeVine(
	vineID string,
	head model.Point,
	headDir string,
	w, h int,
	occupied map[string]string,
) (model.Vine, map[string]string) {
	neckDir := common.OppositeDirection(headDir)
	dx, dy := common.DeltaForDirection(neckDir)
	neck := model.Point{X: head.X + dx, Y: head.Y + dy}

	if neck.X < 0 || neck.X >= w || neck.Y < 0 || neck.Y >= h {
		return model.Vine{}, nil
	}

	neckKey := fmt.Sprintf("%d,%d", neck.X, neck.Y)
	if _, occ := occupied[neckKey]; occ {
		return model.Vine{}, nil
	}

	headKey := fmt.Sprintf("%d,%d", head.X, head.Y)
	vineOccupied := map[string]string{
		headKey: vineID,
		neckKey: vineID,
	}

	return model.Vine{
		ID:            vineID,
		HeadDirection: headDir,
		OrderedPath:   []model.Point{head, neck},
	}, vineOccupied
}

// tryPlaceFillerVine attempts to place a single 2-cell filler vine with valid orientation
func (p *CenterOutPlacer) tryPlaceFillerVine(
	vineID string,
	w, h int,
	occupied map[string]string,
	rng *rand.Rand,
) (model.Vine, map[string]string) {
	// Find all empty cells
	var emptyCells []model.Point
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if _, occ := occupied[key]; !occ {
				emptyCells = append(emptyCells, model.Point{X: x, Y: y})
			}
		}
	}

	if len(emptyCells) < 2 {
		return model.Vine{}, nil
	}

	// Shuffle for randomness
	rng.Shuffle(len(emptyCells), func(i, j int) {
		emptyCells[i], emptyCells[j] = emptyCells[j], emptyCells[i]
	})

	// Try each empty cell as potential head
	for _, head := range emptyCells {
		// Find a free neighbor for neck
		neighbors := p.getAvailableNeighbors(head, w, h, occupied, nil)
		if len(neighbors) == 0 {
			continue
		}

		// Try each neighbor as potential neck
		for _, neck := range neighbors {
			// Calculate head direction based on head→neck vector
			// neck is at opposite of headDir
			neckDir := common.DirectionFromPoints(head, neck)
			headDir := common.OppositeDirection(neckDir)

			// Verify the head has a clear exit path
			if !common.IsExitPathClear(head, headDir, w, h, occupied) {
				continue
			}

			// Valid placement found
			headKey := fmt.Sprintf("%d,%d", head.X, head.Y)
			neckKey := fmt.Sprintf("%d,%d", neck.X, neck.Y)

			vineOccupied := map[string]string{
				headKey: vineID,
				neckKey: vineID,
			}

			return model.Vine{
				ID:            vineID,
				HeadDirection: headDir,
				OrderedPath:   []model.Point{head, neck},
			}, vineOccupied
		}
	}

	return model.Vine{}, nil
}
