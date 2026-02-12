package generator

import (
	"fmt"
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// GapFiller handles the aggressive filling of small remaining gaps in the grid.
type GapFiller struct {
	w, h int
	rng  *rand.Rand
}

// NewGapFiller creates a new GapFiller.
func NewGapFiller(w, h int, rng *rand.Rand) *GapFiller {
	return &GapFiller{
		w:   w,
		h:   h,
		rng: rng,
	}
}

// FillGaps attempts to fill all reachable empty spaces with 2-cell vines.
// Returns the new filler vines and updated occupied map.
func (f *GapFiller) FillGaps(
	startVineID int,
	occupied map[string]string,
) ([]model.Vine, map[string]string) {
	newVines := []model.Vine{}
	currentOccupied := make(map[string]string)

	// Copy input map
	for k, v := range occupied {
		currentOccupied[k] = v
	}

	vineIDCounter := startVineID
	maxIterations := f.w * f.h * 2 // Safety cap

	// Try multiple passes to fill complex shapes
	// Phase 1: Try filling with longer vines (length 3-5) to minimize fragmentation
	for pass := 0; pass < 5; pass++ {
		candidates := f.findEmptyCells(currentOccupied)
		f.rng.Shuffle(len(candidates), func(i, j int) {
			candidates[i], candidates[j] = candidates[j], candidates[i]
		})

		for _, head := range candidates {
			if _, occ := currentOccupied[fmt.Sprintf("%d,%d", head.X, head.Y)]; occ {
				continue
			}

			// Try to grow a longer vine (3-5 cells)
			// Target length based on pass: early passes try longer, later passes try shorter
			targetLen := 5 - pass
			if targetLen < 3 {
				targetLen = 3
			}

			vine, ok := f.growMultiCellFiller(head, targetLen, currentOccupied, vineIDCounter)
			if ok {
				newVines = append(newVines, vine)
				for _, p := range vine.OrderedPath {
					currentOccupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = vine.ID
				}
				vineIDCounter++
			}
		}

		if len(newVines) > maxIterations {
			break
		}
	}

	// Phase 2: Fill remaining small gaps with 2-cell vines (standard fallback)
	for pass := 0; pass < 3; pass++ {
		madeProgress := false
		candidates := f.findEmptyCells(currentOccupied)
		f.rng.Shuffle(len(candidates), func(i, j int) {
			candidates[i], candidates[j] = candidates[j], candidates[i]
		})

		for _, head := range candidates {
			if _, occ := currentOccupied[fmt.Sprintf("%d,%d", head.X, head.Y)]; occ {
				continue
			}

			vine, ok := f.tryCreateFiller(head, currentOccupied, vineIDCounter)
			if ok {
				newVines = append(newVines, vine)
				for _, p := range vine.OrderedPath {
					currentOccupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = vine.ID
				}
				vineIDCounter++
				madeProgress = true
			}
		}

		if !madeProgress {
			break
		}

		if len(newVines) > maxIterations {
			break
		}
	}

	return newVines, currentOccupied
}

func (f *GapFiller) findEmptyCells(occupied map[string]string) []model.Point {
	var empty []model.Point
	for y := 0; y < f.h; y++ {
		for x := 0; x < f.w; x++ {
			if _, occ := occupied[fmt.Sprintf("%d,%d", x, y)]; !occ {
				empty = append(empty, model.Point{X: x, Y: y})
			}
		}
	}
	return empty
}

// growMultiCellFiller attempts to grow a filler vine of target length.
// Must have a clear exit path for the head to preserve LIFO solvability.
func (f *GapFiller) growMultiCellFiller(head model.Point, targetLen int, occupied map[string]string, id int) (model.Vine, bool) {
	vineID := fmt.Sprintf("vine_%d", id)

	// Check all valid exit directions for head
	candidates := []string{}
	for _, dir := range []string{"up", "down", "left", "right"} {
		if common.IsExitPathClear(head, dir, f.w, f.h, occupied) {
			candidates = append(candidates, dir)
		}
	}

	f.rng.Shuffle(len(candidates), func(i, j int) {
		candidates[i], candidates[j] = candidates[j], candidates[i]
	})

	// Direction to delta map
	deltas := map[string]model.Point{
		// Y is inverted? parrable-bloom usually Y=0 at top?
		// Wait, commonly Y increases downwards in 2D grids.
		// Let's check common package or existing logic.
		// In getFreeNeighbors: deltas := []model.Point{{X: 0, Y: 1}, {X: 0, Y: -1}, ...}
		// If "up" means Y-1 or Y+1?
		// common.DirectionFromPoints(from, to)
		// If to.Y < from.Y it returns "up". So Up is Y-1.
		// So HeadDirection "up" means Head points to (X, Y-1).
		// So Neck must be at (X, Y+1) i.e. "down".
		// Delta for Neck (from Head) is Opposite("up") = "down" = (0, 1).

		"up":    {X: 0, Y: 1},  // Opposite of up (-1) is down (+1)
		"down":  {X: 0, Y: -1}, // Opposite of down (+1) is up (-1)
		"left":  {X: 1, Y: 0},  // Opposite of left (-1) is right (+1)
		"right": {X: -1, Y: 0}, // Opposite of right (+1) is left (-1)
	}

	for _, headDir := range candidates {
		// Calculate required neck position
		// HeadDirection = Head - Neck  =>  Neck = Head - HeadDirection
		// HeadDirection vector is calculated as (Target - Head).
		// If HeadDirection is UP (0, -1), then Neck must be (0, 1) relative to Head.
		// i.e. Neck = Head + Opposite(HeadDirection).

		delta, ok := deltas[headDir]
		if !ok {
			continue
		}

		neck := model.Point{X: head.X + delta.X, Y: head.Y + delta.Y}

		// Check if neck is valid and free
		if neck.X < 0 || neck.X >= f.w || neck.Y < 0 || neck.Y >= f.h {
			continue
		}
		if _, occ := occupied[fmt.Sprintf("%d,%d", neck.X, neck.Y)]; occ {
			continue
		}

		// Start growing from neck
		path := []model.Point{head, neck}
		curr := neck

		valid := true
		for len(path) < targetLen {
			neighbors := f.getFreeNeighbors(curr, occupied)

			// Filter neighbors to avoid self-collision
			validNeighbors := []model.Point{}
			for _, n := range neighbors {
				inPath := false
				for _, p := range path {
					if p.X == n.X && p.Y == n.Y {
						inPath = true
						break
					}
				}
				if !inPath {
					validNeighbors = append(validNeighbors, n)
				}
			}

			if len(validNeighbors) == 0 {
				valid = false // cannot grow to target length
				break
			}

			// Simple greedy choice: random valid neighbor
			next := validNeighbors[f.rng.Intn(len(validNeighbors))]
			path = append(path, next)
			curr = next
		}

		if valid {
			return model.Vine{
				ID:            vineID,
				HeadDirection: headDir,
				OrderedPath:   path,
			}, true
		}
	}

	return model.Vine{}, false
}

func (f *GapFiller) tryCreateFiller(head model.Point, occupied map[string]string, id int) (model.Vine, bool) {
	vineID := fmt.Sprintf("vine_%d", id)

	// Get available neighbors
	neighbors := f.getFreeNeighbors(head, occupied)
	f.rng.Shuffle(len(neighbors), func(i, j int) {
		neighbors[i], neighbors[j] = neighbors[j], neighbors[i]
	})

	for _, neck := range neighbors {
		// Calculate potential vine
		neckDir := common.DirectionFromPoints(head, neck)
		headDir := common.OppositeDirection(neckDir)

		// Preference: Has clear exit path (LIFO safe)
		if common.IsExitPathClear(head, headDir, f.w, f.h, occupied) {
			return model.Vine{
				ID:            vineID,
				HeadDirection: headDir,
				OrderedPath:   []model.Point{head, neck},
			}, true
		}
	}

	return model.Vine{}, false
}

func (f *GapFiller) getFreeNeighbors(p model.Point, occupied map[string]string) []model.Point {
	deltas := []model.Point{{X: 0, Y: 1}, {X: 0, Y: -1}, {X: 1, Y: 0}, {X: -1, Y: 0}}
	var neighbors []model.Point

	for _, d := range deltas {
		nx, ny := p.X+d.X, p.Y+d.Y
		if nx >= 0 && nx < f.w && ny >= 0 && ny < f.h {
			if _, occ := occupied[fmt.Sprintf("%d,%d", nx, ny)]; !occ {
				neighbors = append(neighbors, model.Point{X: nx, Y: ny})
			}
		}
	}
	return neighbors
}
