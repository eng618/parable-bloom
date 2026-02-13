package strategies

import (
	"fmt"
	"math"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// calculateVineLengths computes the initial vine count and their lengths based on constraints and profile.
func calculateVineLengths(
	gridSize []int,
	constraints config.DifficultySpec,
	profile config.VarietyProfile,
	rng *rand.Rand,
) (int, []int) {
	w := gridSize[0]
	h := gridSize[1]
	total := w * h

	// Choose a target average length (middle of range)
	minLen := constraints.AvgLengthRange[0]
	maxLen := constraints.AvgLengthRange[1]
	avgLen := (minLen + maxLen) / 2
	if avgLen <= 0 {
		avgLen = 3
	}

	// Initial vine count (rounded)
	vineCount := total / avgLen
	if vineCount < constraints.VineCountRange[0] {
		vineCount = constraints.VineCountRange[0]
	}
	if vineCount > constraints.VineCountRange[1] {
		vineCount = constraints.VineCountRange[1]
	}

	// Distribute lengths to exactly fill the grid, but consider profile.LengthMix
	// IMPORTANT: Minimum vine length is 2 (head + neck)
	lengths := make([]int, vineCount)
	for i := 0; i < vineCount; i++ {
		bucket := chooseLengthBucket(profile, rng)
		switch bucket {
		case "short":
			lengths[i] = maxInt(2, avgLen-2) // min 2 cells
		case "medium":
			lengths[i] = maxInt(2, avgLen) // min 2 cells
		case "long":
			lengths[i] = maxInt(2, avgLen+2) // min 2 cells
		default:
			lengths[i] = maxInt(2, avgLen) // min 2 cells
		}
	}

	// Adjust to exactly fill total cells (respecting minimum length of 2)
	cur := 0
	for _, l := range lengths {
		cur += l
	}
	if cur != total {
		delta := total - cur
		for i := 0; i < int(math.Abs(float64(delta))); i++ {
			idx := i % vineCount
			if delta > 0 {
				lengths[idx]++
			} else if lengths[idx] > 2 { // don't shrink below 2
				lengths[idx]--
			}
		}
	}

	return vineCount, lengths
}

// growVines attempts to grow vines based on the given lengths, returning the vines and occupied map.
func growVines(
	gridSize []int,
	lengths []int,
	profile config.VarietyProfile,
	cfg config.GeneratorConfig,
	rng *rand.Rand,
) ([]model.Vine, map[string]bool, error) {
	w := gridSize[0]
	h := gridSize[1]

	occupied := make(map[string]bool)
	vines := make([]model.Vine, 0, len(lengths))

	for i := 0; i < len(lengths); i++ {
		target := lengths[i]
		// Try to grow a vine with several seed attempts
		var grown model.Vine
		var err error
		for attempt := 0; attempt < cfg.MaxSeedRetries; attempt++ {
			seed := pickSeedWithRegionBias(w, h, occupied, profile, rng)
			if seed == nil {
				break
			}
			v, newOcc, e := GrowFromSeed(*seed, occupied, gridSize, target, profile, cfg, rng)
			if e == nil {
				grown = v
				for k := range newOcc {
					occupied[k] = true
				}
				break
			}
			err = e
		}

		if grown.Length() == 0 {
			// fallback: create small single-cell vine at any empty cell
			s := pickSeedWithRegionBias(w, h, occupied, profile, rng)
			if s == nil {
				return nil, nil, fmt.Errorf("unable to find empty cell for fallback: %w", err)
			}
			id := fmt.Sprintf("v%d", len(vines)+1)
			v := model.Vine{ID: id, HeadDirection: "up", OrderedPath: []model.Point{*s}}
			vines = append(vines, v)
			occupied[fmt.Sprintf("%d,%d", s.X, s.Y)] = true
		} else {
			grown.ID = fmt.Sprintf("v%d", len(vines)+1)
			vines = append(vines, grown)
		}
	}

	return vines, occupied, nil
}

// TileGridIntoVines partitions the grid into vines according to the provided
// difficulty constraints and a variety profile. It returns vines and a mask for empty cells.
func TileGridIntoVines(
	gridSize []int,
	constraints config.DifficultySpec,
	profile config.VarietyProfile,
	cfg config.GeneratorConfig,
	rng *rand.Rand,
) ([]model.Vine, *model.Mask, error) {
	_, lengths := calculateVineLengths(gridSize, constraints, profile, rng)

	vines, occupied, err := growVines(gridSize, lengths, profile, cfg, rng)
	if err != nil {
		return nil, nil, err
	}

	// Collect empty cells for masking
	var emptyPoints []model.Point
	w := gridSize[0]
	h := gridSize[1]
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if !occupied[key] {
				emptyPoints = append(emptyPoints, model.Point{X: x, Y: y})
			}
		}
	}
	var mask *model.Mask
	if len(emptyPoints) > 0 {
		mask = &model.Mask{Mode: "hide", Points: emptyPoints}
	}

	return vines, mask, nil
}

// GrowFromSeed attempts to grow a vine starting from seed, avoiding occupied cells.
// It returns the vine and the updated occupancy map on success.
func GrowFromSeed(
	seed model.Point,
	occupied map[string]bool,
	gridSize []int,
	targetLen int,
	profile config.VarietyProfile,
	_ config.GeneratorConfig,
	rng *rand.Rand,
) (model.Vine, map[string]bool, error) {
	w := gridSize[0]
	h := gridSize[1]

	// DIRECTION-FIRST APPROACH: Choose head direction before growing vine
	// This dramatically improves solvability by ensuring vines point toward exits
	desiredHeadDir := utils.ChooseExitDirection(seed, gridSize, profile.DirBalance, rng)
	headDx, headDy := utils.DeltaForDirection(desiredHeadDir)

	// Start path with seed as the head
	path := []model.Point{seed}
	seen := map[string]bool{fmt.Sprintf("%d,%d", seed.X, seed.Y): true}
	occ := make(map[string]bool)
	for k, v := range occupied {
		occ[k] = v
	}
	occ[fmt.Sprintf("%d,%d", seed.X, seed.Y)] = true

	// Grow vine segments, preferring to grow opposite to head direction (backward growth)
	// This creates vines that naturally point toward exits
	for len(path) < targetLen {
		head := path[len(path)-1]
		neighbors := availableNeighbors(head, w, h, occ)
		if len(neighbors) == 0 {
			// Stuck - validate minimum length before returning
			if len(path) < 2 {
				return model.Vine{}, nil, fmt.Errorf("cannot grow vine: stuck after %d cells (need at least 2)", len(path))
			}
			// Return what we have so far (at least 2 cells)
			// CRITICAL: Calculate correct head direction based on actual head/neck positions
			head := path[0]
			neck := path[1]
			dx := head.X - neck.X
			dy := head.Y - neck.Y

			actualHeadDir := ""
			if dx == 1 && dy == 0 {
				actualHeadDir = "right"
			} else if dx == -1 && dy == 0 {
				actualHeadDir = "left"
			} else if dx == 0 && dy == 1 {
				actualHeadDir = "up"
			} else if dx == 0 && dy == -1 {
				actualHeadDir = "down"
			} else {
				actualHeadDir = desiredHeadDir
			}

			return model.Vine{HeadDirection: actualHeadDir, OrderedPath: path}, occ, nil
		}

		var chosen model.Point

		if len(path) == 1 {
			// First segment after head: prefer growing opposite to head direction
			// This creates the "neck" segment
			neckDx, neckDy := utils.DeltaForDirection(utils.OppositeDirection(desiredHeadDir))
			neck := model.Point{X: head.X + neckDx, Y: head.Y + neckDy}

			// Check if neck position is available
			neckAvailable := false
			for _, n := range neighbors {
				if n.X == neck.X && n.Y == neck.Y {
					neckAvailable = true
					break
				}
			}

			if neckAvailable {
				chosen = neck
			} else {
				// Neck position blocked, try adjacent cells
				// Prefer cells that don't conflict with head direction
				bestNeighbors := []model.Point{}
				for _, n := range neighbors {
					dx := n.X - head.X
					dy := n.Y - head.Y
					// Avoid growing in head direction
					if dx != headDx || dy != headDy {
						bestNeighbors = append(bestNeighbors, n)
					}
				}
				if len(bestNeighbors) > 0 {
					chosen = bestNeighbors[rng.Intn(len(bestNeighbors))]
				} else {
					chosen = neighbors[rng.Intn(len(neighbors))]
				}
			}
		} else if len(path) >= 2 {
			// Density-aware neighbor selection: prefer gap-filling and interwoven patterns
			if len(neighbors) == 1 {
				chosen = neighbors[0]
			} else {
				// Score neighbors for density and gap-filling potential
				type scoredNeighbor struct {
					point model.Point
					score float64
				}

				scored := make([]scoredNeighbor, len(neighbors))
				for i, n := range neighbors {
					scored[i] = scoredNeighbor{
						point: n,
						score: calculateDensityScore(n, occ, gridSize),
					}

					// Small bonus for continuing current direction (reduced from TurnMix logic)
					prev := path[len(path)-2]
					curr := path[len(path)-1]
					dx := curr.X - prev.X
					dy := curr.Y - prev.Y

					nextDx := n.X - curr.X
					nextDy := n.Y - curr.Y

					if dx == nextDx && dy == nextDy {
						scored[i].score += 0.5 // Small bonus for straight continuation
					}

					// Add randomness to prevent deterministic patterns
					scored[i].score += rng.Float64() * 0.3
				}

				// Sort by score descending (highest first)
				sort.Slice(scored, func(i, j int) bool {
					return scored[i].score > scored[j].score
				})

				// Weighted selection from top candidates
				// 60% chance for best, 25% for second, 15% for third
				randVal := rng.Float64()
				if randVal < 0.6 {
					chosen = scored[0].point
				} else if randVal < 0.85 && len(scored) >= 2 {
					chosen = scored[1].point
				} else if len(scored) >= 3 {
					chosen = scored[2].point
				} else {
					chosen = scored[0].point
				}
			}
		} else {
			// Fallback: random pick
			chosen = neighbors[rng.Intn(len(neighbors))]
		}

		k := fmt.Sprintf("%d,%d", chosen.X, chosen.Y)
		path = append(path, chosen)
		seen[k] = true
		occ[k] = true
	}

	// CRITICAL VALIDATION: Vines must be at least 2 cells (head + neck)
	if len(path) < 2 {
		return model.Vine{}, nil, fmt.Errorf("vine too short: got %d cells, need at least 2", len(path))
	}

	// CRITICAL FIX: Calculate the correct head direction based on actual head/neck positions
	// The head is at path[0], the neck is at path[1]
	// The direction is: vector from neck to head
	head := path[0]
	neck := path[1]
	dx := head.X - neck.X
	dy := head.Y - neck.Y

	// Convert delta to direction string
	actualHeadDir := ""
	if dx == 1 && dy == 0 {
		actualHeadDir = "right"
	} else if dx == -1 && dy == 0 {
		actualHeadDir = "left"
	} else if dx == 0 && dy == 1 {
		actualHeadDir = "up"
	} else if dx == 0 && dy == -1 {
		actualHeadDir = "down"
	} else {
		// Unexpected: head and neck not adjacent (shouldn't happen with proper growth)
		actualHeadDir = desiredHeadDir
	}

	// Check for mismatch (DEBUG)
	// if actualHeadDir == "down" && dy == 1 {
	common.Verbose("DEBUG: GrowFromSeed created: head=%v neck=%v dx=%d dy=%d dir=%s", head, neck, dx, dy, actualHeadDir)
	// }

	// Return vine with CORRECT head direction based on actual path geometry
	return model.Vine{HeadDirection: actualHeadDir, OrderedPath: path}, occ, nil
}

// calculateDensityScore evaluates how well a neighbor fills gaps and creates density.
// Higher scores indicate better gap-filling potential.
func calculateDensityScore(p model.Point, occupied map[string]bool, gridSize []int) float64 {
	w, h := gridSize[0], gridSize[1]

	// Count occupied neighbors (Manhattan distance 1)
	occupiedCount := 0
	totalPossible := 0

	deltas := []model.Point{
		{X: 1, Y: 0}, {X: -1, Y: 0}, {X: 0, Y: 1}, {X: 0, Y: -1},
	}

	for _, d := range deltas {
		nx, ny := p.X+d.X, p.Y+d.Y
		if nx >= 0 && nx < w && ny >= 0 && ny < h {
			totalPossible++
			if occupied[fmt.Sprintf("%d,%d", nx, ny)] {
				occupiedCount++
			}
		}
	}

	// Prefer cells with more occupied neighbors (fills gaps better)
	// But be less aggressive to ensure we meet occupancy requirements
	densityScore := float64(occupiedCount) / float64(totalPossible)

	// Smaller edge bonus to encourage boundary filling but not too strongly
	edgeDist := math.Min(math.Min(float64(p.X), float64(w-1-p.X)),
		math.Min(float64(p.Y), float64(h-1-p.Y)))
	edgeBonus := math.Max(0, 1.0-edgeDist/2.0)

	return densityScore*2.0 + edgeBonus
}

// availableNeighbors lists unoccupied Manhattan neighbors within grid.
func availableNeighbors(p model.Point, w, h int, occ map[string]bool) []model.Point {
	candidates := []model.Point{
		{X: p.X + 1, Y: p.Y},
		{X: p.X - 1, Y: p.Y},
		{X: p.X, Y: p.Y + 1},
		{X: p.X, Y: p.Y - 1},
	}
	out := make([]model.Point, 0, 4)
	for _, c := range candidates {
		if c.X < 0 || c.X >= w || c.Y < 0 || c.Y >= h {
			continue
		}
		if occ[fmt.Sprintf("%d,%d", c.X, c.Y)] {
			continue
		}
		out = append(out, c)
	}
	return out
}

// pickSeedWithRegionBias picks a seed based on profile.RegionBias and emptiness.
func pickSeedWithRegionBias(
	w, h int,
	occ map[string]bool,
	profile config.VarietyProfile,
	rng *rand.Rand,
) *model.Point {
	// if no profile fields set, fall back to uniform
	if profile.LengthMix == nil && profile.DirBalance == nil && profile.RegionBias == "" {
		return randomEmptyCell(w, h, occ, rng)
	}
	empty := make([]model.Point, 0)
	weights := make([]float64, 0)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			k := fmt.Sprintf("%d,%d", x, y)
			if occ[k] {
				continue
			}
			p := model.Point{X: x, Y: y}
			empty = append(empty, p)
			// base weight
			var wgt float64
			switch profile.RegionBias {
			case "edge":
				// favor distance to nearest edge
				d := minInt(minInt(x, w-1-x), minInt(y, h-1-y))
				wgt = float64(1 + (w/2 - d))
			case "center":
				cx := float64(w-1) / 2.0
				cy := float64(h-1) / 2.0
				dx := float64(x) - cx
				dy := float64(y) - cy
				dist := dx*dx + dy*dy
				wgt = 1.0 / (0.1 + dist)
			default:
				wgt = 1.0
			}
			weights = append(weights, wgt)
		}
	}
	if len(empty) == 0 {
		return nil
	}
	// weighted pick
	total := 0.0
	for _, v := range weights {
		total += v
	}
	r := rng.Float64() * total
	acc := 0.0
	for i, v := range weights {
		acc += v
		if r <= acc {
			return &empty[i]
		}
	}
	return &empty[len(empty)-1]
}

// chooseLengthBucket picks short/medium/long based on LengthMix weights.
func chooseLengthBucket(profile config.VarietyProfile, rng *rand.Rand) string {
	if len(profile.LengthMix) == 0 {
		return "medium"
	}
	wShort := profile.LengthMix["short"]
	wMed := profile.LengthMix["medium"]
	wLong := profile.LengthMix["long"]
	total := wShort + wMed + wLong
	if total <= 0 {
		return "medium"
	}
	r := rng.Float64() * total
	if r <= wShort {
		return "short"
	}
	r -= wShort
	if r <= wMed {
		return "medium"
	}
	return "long"
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// randomEmptyCell picks a random empty cell from the grid; returns nil if none.
func randomEmptyCell(w, h int, occ map[string]bool, rng *rand.Rand) *model.Point {
	empty := make([]model.Point, 0)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if !occ[key] {
				empty = append(empty, model.Point{X: x, Y: y})
			}
		}
	}
	if len(empty) == 0 {
		return nil
	}
	p := empty[rng.Intn(len(empty))]
	return &p
}
