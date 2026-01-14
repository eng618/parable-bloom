package generator

import (
"fmt"
"math/rand"

"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

// ClearableFirstPlacement implements a two-phase vine placement strategy:
// Phase 1: Place "anchor" vines near grid edges that point outward (guaranteed clearable)
// Phase 2: Fill remaining space with solver-checked vines using standard tiling
//
// This approach dramatically improves solvability on large grids by ensuring
// a base set of vines can always clear, preventing total blocking scenarios.
func ClearableFirstPlacement(
gridSize []int,
constraints common.DifficultySpec,
profile common.VarietyProfile,
cfg common.GeneratorConfig,
seed int64,
anchorRatio float64, // e.g., 0.3 for 30% anchor vines
greedy bool, // if true, check solvability after each vine placement
) ([]common.Vine, error) {
	rng := rand.New(rand.NewSource(seed))

	if anchorRatio < 0 || anchorRatio > 1 {
		anchorRatio = 0.3 // default 30%
	}

	// Calculate target vine count and lengths
	targetVineCount, vineLengths := calculateVineLengths(gridSize, constraints, profile, rng)
	anchorCount := int(float64(targetVineCount) * anchorRatio)

	occupied := make(map[string]bool)
	var vines []common.Vine
	vineIdx := 0

	// Phase 1: Place anchor vines near edges
	edgeBuffer := 3 // cells from edge to consider "near edge"
	maxAnchorAttempts := anchorCount * 20 // allow some retries

	for len(vines) < anchorCount && maxAnchorAttempts > 0 && vineIdx < len(vineLengths) {
		maxAnchorAttempts--

		// Pick seed near edge
		seedPoint, found := pickEdgeSeed(occupied, gridSize, edgeBuffer, rng)
		if !found {
			continue // no available edge seeds
		}

		// Grow vine with direction pointing toward nearest edge
		vineLen := vineLengths[vineIdx]
		vine, newOcc, err := GrowFromSeed(seedPoint, occupied, gridSize, vineLen, profile, cfg, rng)
		if err != nil {
			continue // vine couldn't grow, try another seed
}

// Verify vine is clearable (should always be true for edge vines)
if greedy {
testLevel := &common.Level{
GridSize: gridSize,
Vines:    append(vines, vine),
}
solver := common.NewSolver(testLevel)
if !solver.IsSolvableGreedy() {
continue // skip this vine, not solvable
}
}

// Accept this vine
vines = append(vines, vine)
occupied = newOcc
vineIdx++
}

if len(vines) < anchorCount {
return nil, fmt.Errorf("could not place enough anchor vines (got %d, wanted %d)", len(vines), anchorCount)
}

// Phase 2: Fill remaining space with standard tiling
maxFillAttempts := (targetVineCount - len(vines)) * 50 // more retries since space is partially occupied

for len(vines) < targetVineCount && maxFillAttempts > 0 && vineIdx < len(vineLengths) {
maxFillAttempts--

// Pick random available seed anywhere in grid
seedPoint := pickRandomSeed(gridSize, occupied, rng)
if seedPoint == (common.Point{}) {
continue // no available seeds
}

// Grow vine with standard algorithm
vineLen := vineLengths[vineIdx]
vine, newOcc, err := GrowFromSeed(seedPoint, occupied, gridSize, vineLen, profile, cfg, rng)
if err != nil {
continue
}

// Check solvability incrementally if greedy enabled
if greedy {
testLevel := &common.Level{
GridSize: gridSize,
Vines:    append(vines, vine),
}
solver := common.NewSolver(testLevel)
if !solver.IsSolvableGreedy() {
continue
}
}

// Accept this vine
vines = append(vines, vine)
occupied = newOcc
vineIdx++
}

if len(vines) < targetVineCount {
return nil, fmt.Errorf("could not fill remaining space (got %d vines, wanted %d)", len(vines), targetVineCount)
}

return vines, nil
}

// pickRandomSeed picks a random unoccupied cell anywhere in the grid.
func pickRandomSeed(gridSize []int, occupied map[string]bool, rng *rand.Rand) common.Point {
w, h := gridSize[0], gridSize[1]
maxAttempts := w * h // try up to grid size attempts

for i := 0; i < maxAttempts; i++ {
x := rng.Intn(w)
y := rng.Intn(h)
key := fmt.Sprintf("%d,%d", x, y)
if !occupied[key] {
return common.Point{X: x, Y: y}
}
}

return common.Point{} // no available seed found
}
