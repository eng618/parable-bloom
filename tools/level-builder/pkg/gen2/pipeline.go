package gen2

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	math_rand "math/rand"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// GenerateRobust runs the full robust generation pipeline.
// 1. Primary Placement (Center-Out LIFO)
// 2. Recovery (Local Backtracking)
// 3. Aggressive Gap Filling
// 4. Mandatory Masking
func GenerateRobust(config GenerationConfig) (model.Level, GenerationStats, error) {
	startTime := time.Now()
	stats := GenerationStats{}

	// 1. Setup
	seed := config.Seed
	if config.Randomize {
		seed = cryptoSeedInt64()
	}
	rng := math_rand.New(math_rand.NewSource(seed))
	common.Verbose("Starting Robust Generation for Level %d (Size: %dx%d, Seed: %d)",
		config.LevelID, config.GridWidth, config.GridHeight, seed)

	placer := &CenterOutPlacer{} // Use existing logic for primary placement
	gapFiller := NewGapFiller(config.GridWidth, config.GridHeight, rng)
	assembler := &LevelAssembler{}

	// 2. Initial Placement Phase
	// Using "CenterOutPlacer" because it guarantees LIFO solvability by construction
	vines, occupied, err := placer.PlaceVines(config, rng, &stats)

	// Note: PlaceVines internally handles backtracking for primary vines.
	// If it returns error, it failed even after retries.
	// In aggressive mode, we might want to accept partial results and fill gaps,
	// but standard PlaceVines enforces critical path exists.
	if err != nil && len(vines) < 2 {
		return model.Level{}, stats, fmt.Errorf("primary placement failed: %w", err)
	}

	// Recover partial success if needed
	if occupied == nil {
		occupied = make(map[string]string)
		for _, v := range vines {
			for _, p := range v.OrderedPath {
				occupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = v.ID
			}
		}
	}

	// 3. Aggressive Fill Phase
	// Identify next available vine ID
	nextVineID := 1
	for _, v := range vines {
		var id int
		if n, _ := fmt.Sscanf(v.ID, "vine_%d", &id); n == 1 {
			if id >= nextVineID {
				nextVineID = id + 1
			}
		}
	}

	common.Verbose("Starting Aggressive Fill Phase...")
	fillerVines, fillerOccupied := gapFiller.FillGaps(nextVineID, occupied)

	// Merge filler vines
	vines = append(vines, fillerVines...)
	for k, v := range fillerOccupied {
		occupied[k] = v
	}

	common.Verbose("Added %d filler vines. Total coverage: %d/%d",
		len(fillerVines), len(occupied), config.GridWidth*config.GridHeight)

	// 4. Sanitize Phase
	// Ensure unique IDs before final assembly
	vines = ensureUniqueVineIDs(vines)

	// Rebuild fully consistent map
	finalOccupied := make(map[string]string)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			finalOccupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = v.ID
		}
	}

	// 5. Mandatory Masking Phase
	// Any cell not in finalOccupied MUST be masked to ensure 100% playable coverage
	var mask *model.Mask
	emptyCells := findEmptyCells(config.GridWidth, config.GridHeight, finalOccupied)
	if len(emptyCells) > 0 {
		common.Verbose("Masking %d empty cells to guarantee 100%% coverage", len(emptyCells))
		mask = &model.Mask{Mode: "hide", Points: emptyCells}
	}

	// 6. Assembly
	level := assembler.AssembleLevel(config, vines, mask, seed)

	stats.GenerationTime = time.Since(startTime)
	stats.GenerationTime = time.Since(startTime)

	return level, stats, nil
}

func findEmptyCells(w, h int, occupied map[string]string) []model.Point {
	var empty []model.Point
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if _, occ := occupied[fmt.Sprintf("%d,%d", x, y)]; !occ {
				empty = append(empty, model.Point{X: x, Y: y})
			}
		}
	}
	return empty
}

// ensureUniqueVineIDs renames vines to have sequential IDs vine_1, vine_2, ...
// preserving their original relative order.
func ensureUniqueVineIDs(vines []model.Vine) []model.Vine {
	// Stable sort or keep order? Just keep order and renumber.
	// But we might want to preserve IDs if possible to help debugging?
	// Actually, strictly sequential IDs are cleaner for the game engine.

	cleanVines := make([]model.Vine, len(vines))
	for i, v := range vines {
		cleanVines[i] = v
		cleanVines[i].ID = fmt.Sprintf("vine_%d", i+1)
	}
	return cleanVines
}

// cryptoSeedInt64 returns a crypto-random int64 seed
func cryptoSeedInt64() int64 {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return time.Now().UnixNano()
	}
	return int64(binary.LittleEndian.Uint64(b[:]))
}
