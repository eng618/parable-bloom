package strategies

import (
	"fmt"
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// info: This file adapts legacy generation functions to the new VinePlacementStrategy interface.

// StrategyLegacyTiling wraps the old TileGridIntoVines algorithm
const StrategyLegacyTiling = "legacy-tiling"

type LegacyTilingStrategy struct{}

func (s *LegacyTilingStrategy) PlaceVines(cfg config.GenerationConfig, rng *rand.Rand, stats *config.GenerationStats) ([]model.Vine, map[string]string, error) {
	spec, ok := config.DifficultySpecs[cfg.Difficulty]
	if !ok {
		// Fallback
		spec = config.DifficultySpecs["Seedling"]
	}
	profile := utils.GetPresetProfile(cfg.Difficulty)
	genCfg := utils.GetGeneratorConfigForDifficulty(cfg.Difficulty)
	gridSize := []int{cfg.GridWidth, cfg.GridHeight}

	vines, _, err := TileGridIntoVines(gridSize, spec, profile, genCfg, rng)
	if err != nil {
		return nil, nil, err
	}

	occupied := make(map[string]string)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			occupied[key] = v.ID
		}
	}
	return vines, occupied, nil
}

// StrategyLegacyClearable wraps the old ClearableFirstPlacement algorithm
const StrategyLegacyClearable = "legacy-clearable"

type LegacyClearableStrategy struct{}

func (s *LegacyClearableStrategy) PlaceVines(cfg config.GenerationConfig, rng *rand.Rand, stats *config.GenerationStats) ([]model.Vine, map[string]string, error) {
	spec, ok := config.DifficultySpecs[cfg.Difficulty]
	if !ok {
		// Fallback
		spec = config.DifficultySpecs["Seedling"]
	}
	profile := utils.GetPresetProfile(cfg.Difficulty)
	genCfg := utils.GetGeneratorConfigForDifficulty(cfg.Difficulty)
	gridSize := []int{cfg.GridWidth, cfg.GridHeight}

	// Legacy ClearableFirstPlacement took a seed (int64).
	// We can use cfg.Seed or just rng.Int63()
	seed := rng.Int63()

	// Anchor ratio - usually 0.3 in legacy code, but adaptive. Use default 0.3 for now.
	anchorRatio := 0.3

	vines, err := ClearableFirstPlacement(gridSize, spec, profile, genCfg, seed, anchorRatio, common.MinGridCoverage, false)
	if err != nil {
		return nil, nil, err
	}

	occupied := make(map[string]string)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			occupied[key] = v.ID
		}
	}
	return vines, occupied, nil
}

// StrategyLegacySolverAware wraps the old SolverAwarePlacement algorithm
const StrategyLegacySolverAware = "legacy-solver"

type LegacySolverAwareStrategy struct{}

func (s *LegacySolverAwareStrategy) PlaceVines(cfg config.GenerationConfig, rng *rand.Rand, stats *config.GenerationStats) ([]model.Vine, map[string]string, error) {
	spec, ok := config.DifficultySpecs[cfg.Difficulty]
	if !ok {
		// Fallback
		spec = config.DifficultySpecs["Seedling"]
	}
	profile := utils.GetPresetProfile(cfg.Difficulty)
	genCfg := utils.GetGeneratorConfigForDifficulty(cfg.Difficulty)
	gridSize := []int{cfg.GridWidth, cfg.GridHeight}

	vines, _, err := SolverAwarePlacement(gridSize, spec, profile, genCfg, rng)
	if err != nil {
		return nil, nil, err
	}

	occupied := make(map[string]string)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			occupied[key] = v.ID
		}
	}
	return vines, occupied, nil
}
