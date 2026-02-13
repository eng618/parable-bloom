package strategies

import (
	"fmt"
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// ClearableFirstPlacement implements a two-phase vine placement strategy:
// Phase 1: Place "anchor" vines near grid edges that point outward (guaranteed clearable)
// Phase 2: Fill remaining space with solver-checked vines using standard tiling
//
// This approach dramatically improves solvability on large grids by ensuring
// a base set of vines can always clear, preventing total blocking scenarios.
func ClearableFirstPlacement(
	gridSize []int,
	constraints config.DifficultySpec,
	profile config.VarietyProfile,
	cfg config.GeneratorConfig,
	seed int64,
	anchorRatio float64, // e.g., 0.3 for 30% anchor vines
	minCoverage float64, // target coverage (e.g. 0.95)
	greedy bool, // if true, check solvability after each vine placement
) ([]model.Vine, error) {
	rng := rand.New(rand.NewSource(seed))

	if anchorRatio < 0 || anchorRatio > 1 {
		anchorRatio = 0.3 // default 30%
	}
	if minCoverage <= 0 {
		minCoverage = common.MinGridCoverage
	}

	// GREEDY-FILL ALGORITHM: Place vines until target coverage
	// No pre-calculated vine count - keep adding until grid is full
	gridArea := gridSize[0] * gridSize[1]

	// Length distribution: favor longer vines with variety
	// Min = 2 (head+neck), Max = ~20% of grid dimension (prevent one vine dominating)
	minVineLen := 2
	maxVineLen := (gridSize[0] + gridSize[1]) / 2 // e.g., 18 for 14x22 grid
	if maxVineLen < 4 {
		maxVineLen = 4
	}

	occupied := make(map[string]bool)
	var vines []model.Vine

	// Track vine length distribution to ensure variety
	lengthCounts := make(map[int]int)
	maxShortVines := gridArea / 50 // limit 2-3 cell vines to ~2% of grid

	// Phase 1: Place anchor vines near edges (30% of estimated total)
	edgeBuffer := 3
	estimatedTotalVines := gridArea / 5 // rough estimate assuming avg length ~5
	targetAnchorCount := int(float64(estimatedTotalVines) * anchorRatio)
	if targetAnchorCount < 2 {
		targetAnchorCount = 2
	}

	anchorAttempts := 0
	maxAnchorAttempts := targetAnchorCount * 100
	// Track consecutive failures to detect stalls and reseed
	anchorFailures := 0

	for len(vines) < targetAnchorCount && anchorAttempts < maxAnchorAttempts {
		anchorAttempts++
		anchorFailures++

		// Check if grid is full
		currentCells := len(occupied)
		if float64(currentCells)/float64(gridArea) >= minCoverage {
			break // target coverage achieved
		}

		remainingCells := gridArea - currentCells
		if remainingCells < minVineLen {
			break // not enough space for minimum vine
		}

		// Pick seed near edge
		seedPoint, found := utils.PickEdgeSeed(occupied, gridSize, edgeBuffer, rng)
		if !found {
			continue
		}

		// Choose vine length with variety (skewed toward longer vines)
		vineLen := chooseVineLengthSkewed(minVineLen, maxVineLen, remainingCells, lengthCounts, maxShortVines, rng)

		vine, newOcc, err := GrowFromSeed(seedPoint, occupied, gridSize, vineLen, profile, cfg, rng)
		if err != nil || len(vine.OrderedPath) < minVineLen {
			continue
		}

		// Reject short vines if we've already hit the limit (maintain variety)
		actualLen := len(vine.OrderedPath)
		if actualLen <= 3 {
			shortCount := lengthCounts[2] + lengthCounts[3]
			if shortCount >= maxShortVines {
				continue // skip this short vine
			}
		}

		// Verify solvability
		if greedy {
			testLevel := &model.Level{
				GridSize: gridSize,
				Vines:    append(vines, vine),
			}
			solver := common.NewSolver(testLevel)
			if !solver.IsSolvableGreedy() {
				continue
			}
		}

		// Accept vine - assign ID before appending
		vine.ID = fmt.Sprintf("v%d", len(vines)+1)
		vines = append(vines, vine)
		occupied = newOcc
		lengthCounts[len(vine.OrderedPath)]++
	}

	// Phase 2: Fill remaining space until target coverage
	fillAttempts := 0
	maxFillAttempts := gridArea * 2 // Reduced from *10 to prevent infinite loops
	// Track consecutive failures for fill phase
	fillFailures := 0
	maxConsecutiveFillFails := 50 // Give up after 50 straight failures

	for fillAttempts < maxFillAttempts {
		fillAttempts++
		fillFailures++

		// Early termination if too many consecutive failures
		if fillFailures >= maxConsecutiveFillFails {
			common.Verbose("⚠️  ClearableFirst: Too many consecutive failures (%d), terminating fill phase early", fillFailures)
			break
		}

		// Check if grid is full
		currentCells := len(occupied)
		if float64(currentCells)/float64(gridArea) >= minCoverage {
			break // SUCCESS: target coverage!
		}

		remainingCells := gridArea - currentCells
		if remainingCells < minVineLen {
			// Can't fit minimum vine - check if we can merge remaining into last vine
			// For now, accept near-100% if we can't fit another vine
			if remainingCells <= 1 {
				break
			}
			// If 2+ cells remain, keep trying
		}

		// Pick a seed; when stuck, prefer seeds in sparse regions
		var seedPoint model.Point
		if fillFailures > maxConsecutiveFillFails/2 {
			common.Verbose("⚠️  ClearableFirst: fill stuck (%d fails), preferring sparse seeds and reseeding", fillFailures)
			seedPoint = pickRandomSeedWithPreference(gridSize, occupied, rng)
			// Occasionally reseed RNG to try different trajectories (determinstic)
			if fillFailures > maxConsecutiveFillFails {
				rng.Seed(seed + int64(fillAttempts)*31)
				fillFailures = 0
			}
		} else {
			seedPoint = pickRandomSeed(gridSize, occupied, rng)
		}

		if seedPoint == (model.Point{}) {
			continue // no available seeds
		}

		// Relax short vine constraints if we are struggling
		effectiveMaxShort := maxShortVines
		if fillFailures > 20 {
			effectiveMaxShort = 999999 // Ignore limit
		}

		// Choose vine length with variety
		vineLen := chooseVineLengthSkewed(minVineLen, maxVineLen, remainingCells, lengthCounts, effectiveMaxShort, rng)

		vine, newOcc, err := GrowFromSeed(seedPoint, occupied, gridSize, vineLen, profile, cfg, rng)
		if err != nil || len(vine.OrderedPath) < minVineLen {
			continue
		}

		// Reject short vines if we've already hit the limit (maintain variety), unless desperate
		actualLen := len(vine.OrderedPath)
		if actualLen <= 3 {
			shortCount := lengthCounts[2] + lengthCounts[3]
			if shortCount >= effectiveMaxShort {
				continue // skip this short vine
			}
		}

		// Check solvability
		if greedy {
			testLevel := &model.Level{
				GridSize: gridSize,
				Vines:    append(vines, vine),
			}
			solver := common.NewSolver(testLevel)
			if !solver.IsSolvableGreedy() {
				continue
			}
		}

		// Accept vine - assign ID before appending
		vine.ID = fmt.Sprintf("v%d", len(vines)+1)
		vines = append(vines, vine)
		occupied = newOcc
		lengthCounts[len(vine.OrderedPath)]++
		fillFailures = 0 // Reset consecutive failure counter on success
	}

	// Phase 3: Extension - Try to fill remaining gaps by extending existing vines
	// This captures single isolated cells that are too small for new vines
	if float64(len(occupied))/float64(gridArea) < minCoverage {
		// common.Verbose("Phase 3: Extending vines to fill gaps...")
		maxExtensionPasses := 3
		for pass := 0; pass < maxExtensionPasses; pass++ {
			extended := false
			for i := range vines {
				// Early exit if target coverage met
				if float64(len(occupied))/float64(gridArea) >= minCoverage {
					break
				}

				vine := &vines[i]
				tail := vine.OrderedPath[len(vine.OrderedPath)-1]

				// Find empty neighbors of tail
				neighbors := getUnoccupiedNeighbors(tail, gridSize[0], gridSize[1], occupied)
				if len(neighbors) == 0 {
					continue
				}

				// Try each neighbor
				for _, n := range neighbors {
					// Check solvability if greedy
					if greedy {
						// Temporarily extend
						origPath := make([]model.Point, len(vine.OrderedPath))
						copy(origPath, vine.OrderedPath)
						vine.OrderedPath = append(vine.OrderedPath, n)

						// Create temp level ensuring we don't modify other state
						testLevel := &model.Level{
							GridSize: gridSize,
							Vines:    vines, // vines[i] is already modified in place
						}
						solver := common.NewSolver(testLevel)
						if !solver.IsSolvableGreedy() {
							// Revert
							vine.OrderedPath = origPath

							continue
						}
						// Keep extension
						occupied[fmt.Sprintf("%d,%d", n.X, n.Y)] = true
						lengthCounts[len(vine.OrderedPath)]++
						extended = true
						break // Only extend once per pass per vine
					} else {
						// Non-greedy: just extend
						vine.OrderedPath = append(vine.OrderedPath, n)

						// DEBUG CHECK
						if len(vine.OrderedPath) >= 2 {
							h := vine.OrderedPath[0]
							neck := vine.OrderedPath[1]
							dx := h.X - neck.X
							dy := h.Y - neck.Y
							if (dx == 0 && dy == 1 && vine.HeadDirection != "up") ||
								(dx == 0 && dy == -1 && vine.HeadDirection != "down") {
								common.Verbose("DEBUG: ClearableFirst EXTENSION BROKE DIRECTION! vine=%v head=%v neck=%v dir=%s", vine.ID, h, neck, vine.HeadDirection)
							}
						}

						occupied[fmt.Sprintf("%d,%d", n.X, n.Y)] = true
						lengthCounts[len(vine.OrderedPath)]++
						extended = true
						break
					}
				}
			}
			if !extended {
				break
			}
		}
	}

	// Verify we achieved near-target coverage
	finalCoverage := float64(len(occupied)) / float64(gridArea)
	if finalCoverage < minCoverage {
		return nil, fmt.Errorf("insufficient coverage: got %.1f%%, need %.1f%%+", finalCoverage*100, minCoverage*100)
	}

	// Quick circular-block detection before returning to avoid producing
	// levels that will fail the greedy solver repeatedly.
	{
		occupiedMap := make(map[string]string)
		for _, v := range vines {
			for _, p := range v.OrderedPath {
				occupiedMap[fmt.Sprintf("%d,%d", p.X, p.Y)] = v.ID
			}
		}

		blockingGraph := make(map[string][]string)
		for _, v := range vines {
			blockingGraph[v.ID] = []string{}
		}

		for _, a := range vines {
			for _, b := range vines {
				if a.ID == b.ID {
					continue
				}
				// compute where b's head would move
				head := b.OrderedPath[0]
				tx, ty := head.X, head.Y
				switch b.HeadDirection {
				case "right":
					tx++
				case "left":
					tx--
				case "up":
					ty++
				case "down":
					ty--
				}
				if occupiedMap[fmt.Sprintf("%d,%d", tx, ty)] == a.ID {
					blockingGraph[a.ID] = append(blockingGraph[a.ID], b.ID)
				}
			}
		}

		if common.DetectCircularBlocking(blockingGraph) {
			return nil, fmt.Errorf("placement produced circular blocking (detected before returning)")
		}
	}

	return vines, nil
}

// pickRandomSeed picks a random unoccupied cell anywhere in the grid.
func pickRandomSeed(gridSize []int, occupied map[string]bool, rng *rand.Rand) model.Point {
	w, h := gridSize[0], gridSize[1]
	maxAttempts := w * h // try up to grid size attempts

	for i := 0; i < maxAttempts; i++ {
		x := rng.Intn(w)
		y := rng.Intn(h)
		key := fmt.Sprintf("%d,%d", x, y)
		if !occupied[key] {
			return model.Point{X: x, Y: y}
		}
	}

	return model.Point{} // no available seed found
}

// pickRandomSeedWithPreference prefers seeds in locally sparse areas (more empty neighbors)
// This helps escape tight clusters where random picks keep failing.
func pickRandomSeedWithPreference(gridSize []int, occupied map[string]bool, rng *rand.Rand) model.Point {
	w, h := gridSize[0], gridSize[1]
	best := model.Point{}
	bestScore := -1

	// Sample up to 60 candidates and pick one with the most empty neighbors
	for i := 0; i < 60; i++ {
		x := rng.Intn(w)
		y := rng.Intn(h)
		key := fmt.Sprintf("%d,%d", x, y)
		if occupied[key] {
			continue
		}

		score := 0
		neighbors := [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		for _, n := range neighbors {
			nx := x + n[0]
			ny := y + n[1]
			if nx >= 0 && nx < w && ny >= 0 && ny < h {
				k := fmt.Sprintf("%d,%d", nx, ny)
				if !occupied[k] {
					score++
				}
			}
		}

		if score > bestScore {
			bestScore = score
			best = model.Point{X: x, Y: y}
			if score == 4 {
				break // optimal
			}
		}
	}

	if bestScore >= 0 {
		return best
	}

	// Fallback
	return pickRandomSeed(gridSize, occupied, rng)
}

// chooseVineLengthSkewed picks a vine length with variety and a skew toward longer vines.
// Avoids too many short vines while respecting remaining space.
func chooseVineLengthSkewed(minLen, maxLen, remainingCells int, lengthCounts map[int]int, maxShortVines int, rng *rand.Rand) int {
	// Cap by remaining space
	effectiveMax := maxLen
	if remainingCells < effectiveMax {
		effectiveMax = remainingCells
	}
	if effectiveMax < minLen {
		effectiveMax = minLen
	}

	// Limit short vines (2-3 cells) to maintain variety
	shortVineCount := lengthCounts[2] + lengthCounts[3]
	if shortVineCount >= maxShortVines && effectiveMax > 3 {
		// Force longer vine
		minLen = 4
	}

	// Weighted random: skew toward longer vines
	// Use inverse weighting: shorter lengths get lower probability
	weights := make([]int, effectiveMax-minLen+1)
	for i := range weights {
		length := minLen + i
		// Weight increases with length: weight = length
		// This makes longer vines more likely
		weights[i] = length
	}

	// Pick weighted random index
	totalWeight := 0
	for _, w := range weights {
		totalWeight += w
	}

	if totalWeight == 0 {
		return minLen
	}

	r := rng.Intn(totalWeight)
	cumulative := 0
	for i, w := range weights {
		cumulative += w
		if r < cumulative {
			return minLen + i
		}
	}

	return effectiveMax // fallback
}

// getUnoccupiedNeighbors returns orthogonal neighbors that are not in occupied map
func getUnoccupiedNeighbors(pt model.Point, w, h int, occupied map[string]bool) []model.Point {
	deltas := []struct{ dx, dy int }{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
	var neighbors []model.Point
	for _, d := range deltas {
		nx, ny := pt.X+d.dx, pt.Y+d.dy
		if nx >= 0 && nx < w && ny >= 0 && ny < h {
			if !occupied[fmt.Sprintf("%d,%d", nx, ny)] {
				neighbors = append(neighbors, model.Point{X: nx, Y: ny})
			}
		}
	}
	return neighbors
}
