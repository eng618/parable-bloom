package generator

import (
	"fmt"
	"math"
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

// calculateVineLengths computes the initial vine count and their lengths based on constraints and profile.
func calculateVineLengths(
	gridSize []int,
	constraints common.DifficultySpec,
	profile common.VarietyProfile,
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
	lengths := make([]int, vineCount)
	for i := 0; i < vineCount; i++ {
		bucket := chooseLengthBucket(profile, rng)
		switch bucket {
		case "short":
			lengths[i] = maxInt(1, avgLen-2)
		case "medium":
			lengths[i] = maxInt(1, avgLen)
		case "long":
			lengths[i] = maxInt(1, avgLen+2)
		default:
			lengths[i] = avgLen
		}
	}

	// Adjust to exactly fill total cells
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
			} else if lengths[idx] > 1 {
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
	profile common.VarietyProfile,
	cfg common.GeneratorConfig,
	rng *rand.Rand,
) ([]common.Vine, map[string]bool, error) {
	w := gridSize[0]
	h := gridSize[1]

	occupied := make(map[string]bool)
	vines := make([]common.Vine, 0, len(lengths))

	for i := 0; i < len(lengths); i++ {
		target := lengths[i]
		// Try to grow a vine with several seed attempts
		var grown common.Vine
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
			v := common.Vine{ID: id, HeadDirection: "up", OrderedPath: []common.Point{*s}}
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
	constraints common.DifficultySpec,
	profile common.VarietyProfile,
	cfg common.GeneratorConfig,
	rng *rand.Rand,
) ([]common.Vine, *common.Mask, error) {
	_, lengths := calculateVineLengths(gridSize, constraints, profile, rng)

	vines, occupied, err := growVines(gridSize, lengths, profile, cfg, rng)
	if err != nil {
		return nil, nil, err
	}

	// Collect empty cells for masking
	var emptyPoints []common.Point
	w := gridSize[0]
	h := gridSize[1]
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if !occupied[key] {
				emptyPoints = append(emptyPoints, common.Point{X: x, Y: y})
			}
		}
	}
	var mask *common.Mask
	if len(emptyPoints) > 0 {
		mask = &common.Mask{Mode: "hide", Points: emptyPoints}
	}

	return vines, mask, nil
}

// GrowFromSeed attempts to grow a vine starting from seed, avoiding occupied cells.
// It returns the vine and the updated occupancy map on success.
func GrowFromSeed(
	seed common.Point,
	occupied map[string]bool,
	gridSize []int,
	targetLen int,
	profile common.VarietyProfile,
	_ common.GeneratorConfig,
	rng *rand.Rand,
) (common.Vine, map[string]bool, error) {
	w := gridSize[0]
	h := gridSize[1]

	// DIRECTION-FIRST APPROACH: Choose head direction before growing vine
	// This dramatically improves solvability by ensuring vines point toward exits
	desiredHeadDir := chooseExitDirection(seed, gridSize, profile.DirBalance, rng)
	headDx, headDy := deltaForDirection(desiredHeadDir)

	// Start path with seed as the head
	path := []common.Point{seed}
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
			// Stuck - return what we have so far
			return common.Vine{HeadDirection: desiredHeadDir, OrderedPath: path}, occ, nil
		}

		var chosen common.Point

		if len(path) == 1 {
			// First segment after head: prefer growing opposite to head direction
			// This creates the "neck" segment
			neckDx, neckDy := deltaForDirection(oppositeDirection(desiredHeadDir))
			neck := common.Point{X: head.X + neckDx, Y: head.Y + neckDy}
			
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
				bestNeighbors := []common.Point{}
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
			// Continue growing: prefer straight vs turning based on TurnMix
			prev := path[len(path)-2]
			dx := head.X - prev.X
			dy := head.Y - prev.Y
			straight := common.Point{X: head.X + dx, Y: head.Y + dy}
			
			straightAvailable := false
			for _, n := range neighbors {
				if n.X == straight.X && n.Y == straight.Y {
					straightAvailable = true
					break
				}
			}
			
			if straightAvailable && rng.Float64() > profile.TurnMix {
				chosen = straight
			} else {
				chosen = neighbors[rng.Intn(len(neighbors))]
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

	// Return vine with predetermined head direction
	return common.Vine{HeadDirection: desiredHeadDir, OrderedPath: path}, occ, nil
}

// availableNeighbors lists unoccupied Manhattan neighbors within grid.
func availableNeighbors(p common.Point, w, h int, occ map[string]bool) []common.Point {
	candidates := []common.Point{
		{X: p.X + 1, Y: p.Y},
		{X: p.X - 1, Y: p.Y},
		{X: p.X, Y: p.Y + 1},
		{X: p.X, Y: p.Y - 1},
	}
	out := make([]common.Point, 0, 4)
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

// chooseNeighborByDirBias picks a neighbor closest to a desired direction distribution.
func chooseNeighborByDirBias(
	origin common.Point,
	neighbors []common.Point,
	dirBalance map[string]float64,
	rng *rand.Rand,
) common.Point {
	if len(neighbors) == 0 || len(dirBalance) == 0 {
		return common.Point{}
	}
	// Score neighbors by their direction
	scores := make([]float64, len(neighbors))
	sum := 0.0
	for i, n := range neighbors {
		dx := n.X - origin.X
		dy := n.Y - origin.Y
		var dir string
		for k, v := range common.HeadDirections {
			if v[0] == dx && v[1] == dy {
				dir = k
				break
			}
		}
		s := dirBalance[dir]
		scores[i] = s
		sum += s
	}
	if sum == 0 {
		// fallback random
		return neighbors[rng.Intn(len(neighbors))]
	}
	// pick weighted
	r := rng.Float64() * sum
	acc := 0.0
	for i, s := range scores {
		acc += s
		if r <= acc {
			return neighbors[i]
		}
	}
	return neighbors[len(neighbors)-1]
}

// pickSeedWithRegionBias picks a seed based on profile.RegionBias and emptiness.
func pickSeedWithRegionBias(
	w, h int,
	occ map[string]bool,
	profile common.VarietyProfile,
	rng *rand.Rand,
) *common.Point {
	// if no profile fields set, fall back to uniform
	if profile.LengthMix == nil && profile.DirBalance == nil && profile.RegionBias == "" {
		return randomEmptyCell(w, h, occ, rng)
	}
	empty := make([]common.Point, 0)
	weights := make([]float64, 0)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			k := fmt.Sprintf("%d,%d", x, y)
			if occ[k] {
				continue
			}
			p := common.Point{X: x, Y: y}
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
func chooseLengthBucket(profile common.VarietyProfile, rng *rand.Rand) string {
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
func randomEmptyCell(w, h int, occ map[string]bool, rng *rand.Rand) *common.Point {
	empty := make([]common.Point, 0)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if !occ[key] {
				empty = append(empty, common.Point{X: x, Y: y})
			}
		}
	}
	if len(empty) == 0 {
		return nil
	}
	p := empty[rng.Intn(len(empty))]
	return &p
}
