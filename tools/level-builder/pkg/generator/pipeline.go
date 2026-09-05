package generator

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	math_rand "math/rand"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// GenerateRobust runs the full robust generation pipeline.
// Canonical entry point for all generation: batch, CLI, and tests must use
// this (via GenerateLevel) rather than legacy generator.go paths.
// 1. Primary Placement (strategy from cfg, default by difficulty)
// 2. Recovery (Local Backtracking inside placer)
// 3. Aggressive Gap Filling
// 4. Mandatory Masking
func GenerateRobust(cfg config.GenerationConfig) (model.Level, config.GenerationStats, error) {
	startTime := time.Now()
	stats := config.GenerationStats{}

	// 1. Setup - deterministic seed resolution.
	// Randomize=true explicitly opts into non-determinism; otherwise cfg.Seed is used as-is.
	seed := resolveSeed(cfg)
	rng := math_rand.New(math_rand.NewSource(seed))
	common.Verbose("Starting Robust Generation for Level %d (Size: %dx%d, Seed: %d)",
		cfg.LevelID, cfg.GridWidth, cfg.GridHeight, seed)

	var placer config.VinePlacementStrategy
	var err error

	// Use the registry to get the requested strategy
	if cfg.Strategy == "" {
		// Default validation in case config is empty, but batch should handle this
		if cfg.Difficulty == "Transcendent" {
			cfg.Strategy = config.StrategyCenterOut
		} else {
			cfg.Strategy = config.StrategyDirectionFirst
		}
	}

	placer, err = GetStrategy(cfg.Strategy)
	if err != nil {
		return model.Level{}, stats, fmt.Errorf("failed to get strategy %s: %w", cfg.Strategy, err)
	}

	gapFiller := strategies.NewGapFiller(cfg.GridWidth, cfg.GridHeight, rng)
	assembler := &LevelAssembler{}

	// 2. Initial Placement Phase
	// Using "CenterOutPlacer" because it guarantees LIFO solvability by construction
	vines, occupied, err := placer.PlaceVines(cfg, rng, &stats)
	// Note: PlaceVines internally handles backtracking for primary vines.
	// If it returns error, it failed even after retries.
	if err != nil {
		// If no failure dump was written by the placer (e.g. DirectionFirst doesn't use backtracking helper),
		// write one now to ensure we have a deterministic record of the failure.
		if stats.DumpsProduced == 0 {
			_ = strategies.WriteFailureDump(cfg, seed, 0, err.Error(), vines, occupied, &stats)
		}

		if len(vines) < 2 {
			return model.Level{}, stats, fmt.Errorf("primary placement failed: %w", err)
		}
	}

	// Recover partial success if needed
	if occupied == nil {
		occupied = make(map[string]string, len(vines)*8)
		for _, v := range vines {
			for _, p := range v.OrderedPath {
				occupied[common.PointKey(p)] = v.ID
			}
		}
	}

	// 3. Aggressive Fill Phase
	// Identify next available vine ID (robust to malformed IDs)
	nextVineID := 1
	for _, v := range vines {
		if id := parseVineID(v.ID); id >= nextVineID {
			nextVineID = id + 1
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
		len(fillerVines), len(occupied), cfg.GridWidth*cfg.GridHeight)

	// 4. Sanitize Phase
	// Ensure unique IDs before final assembly
	vines = ensureUniqueVineIDs(vines)

	// Rebuild fully consistent map
	finalOccupied := make(map[string]string, len(vines)*8)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			finalOccupied[common.PointKey(p)] = v.ID
		}
	}

	// 5. Mandatory Masking Phase
	// Any cell not in finalOccupied MUST be masked to ensure 100% playable coverage
	var mask *model.Mask
	emptyCells := findEmptyCells(cfg.GridWidth, cfg.GridHeight, finalOccupied)
	if len(emptyCells) > 0 {
		common.Verbose("Masking %d empty cells to guarantee 100%% coverage", len(emptyCells))
		mask = &model.Mask{Mode: "hide", Points: emptyCells}
	}

	// 6. Assembly
	level := assembler.AssembleLevel(cfg, vines, mask, seed)

	stats.GenerationTime = time.Since(startTime)
	stats.GridCoverage = float64(len(finalOccupied)) / float64(cfg.GridWidth*cfg.GridHeight)

	return level, stats, nil
}

func findEmptyCells(w, h int, occupied map[string]string) []model.Point {
	var empty []model.Point
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := common.PointKey(model.Point{X: x, Y: y})
			if _, occ := occupied[key]; !occ {
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

// resolveSeed returns the deterministic seed for this generation run.
// Randomize=true explicitly opts into crypto randomness; otherwise cfg.Seed is used verbatim
// so batch retries (seed=level*31337+retry*12345) stay reproducible.
func resolveSeed(cfg config.GenerationConfig) int64 {
	if cfg.Randomize {
		return cryptoSeedInt64()
	}
	return cfg.Seed
}

// parseVineID extracts the numeric suffix from IDs like "vine_12".
// Returns 0 for malformed IDs so callers can safely compute nextVineID.
func parseVineID(id string) int {
	var n int
	if _, err := fmt.Sscanf(id, "vine_%d", &n); err != nil {
		return 0
	}
	if n < 0 {
		return 0
	}
	return n
}

// cryptoSeedInt64 returns a crypto-random int64 seed
func cryptoSeedInt64() int64 {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return time.Now().UnixNano()
	}
	return int64(binary.LittleEndian.Uint64(b[:]))
}
