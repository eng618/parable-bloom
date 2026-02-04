package gen2

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
	for pass := 0; pass < 3; pass++ {
		madeProgress := false

		// Find all empty cells
		candidates := f.findEmptyCells(currentOccupied)
		f.rng.Shuffle(len(candidates), func(i, j int) {
			candidates[i], candidates[j] = candidates[j], candidates[i]
		})

		for _, head := range candidates {
			// Skip if occupied during this pass
			if _, occ := currentOccupied[fmt.Sprintf("%d,%d", head.X, head.Y)]; occ {
				continue
			}

			// Try to find a valid neck for this head
			// 1. Try to maintain LIFO property (head has clear exit)
			// 2. Fallback to any valid 2-cell vine if LIFO not possible

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
