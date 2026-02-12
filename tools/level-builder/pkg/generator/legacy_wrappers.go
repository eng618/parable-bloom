package generator

import (
	"fmt"
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// info: This file adapts legacy generation functions to the new VinePlacementStrategy interface.

// StrategyLegacyTiling wraps the old TileGridIntoVines algorithm
const StrategyLegacyTiling = "legacy-tiling"

type LegacyTilingStrategy struct{}

func (s *LegacyTilingStrategy) PlaceVines(config GenerationConfig, rng *rand.Rand, stats *GenerationStats) ([]model.Vine, map[string]string, error) {
	spec, ok := DifficultySpecs[config.Difficulty]
	if !ok {
		// Fallback
		spec = DifficultySpecs["Seedling"]
	}
	profile := GetPresetProfile(config.Difficulty)
	genCfg := GetGeneratorConfigForDifficulty(config.Difficulty)
	gridSize := []int{config.GridWidth, config.GridHeight}

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

func (s *LegacyClearableStrategy) PlaceVines(config GenerationConfig, rng *rand.Rand, stats *GenerationStats) ([]model.Vine, map[string]string, error) {
	spec, ok := DifficultySpecs[config.Difficulty]
	if !ok {
		// Fallback
		spec = DifficultySpecs["Seedling"]
	}
	profile := GetPresetProfile(config.Difficulty)
	genCfg := GetGeneratorConfigForDifficulty(config.Difficulty)
	gridSize := []int{config.GridWidth, config.GridHeight}

	// Legacy ClearableFirstPlacement took a seed (int64).
	// We can use config.Seed or just rng.Int63()
	seed := rng.Int63()

	// Anchor ratio - usually 0.3 in legacy code, but adaptive. Use default 0.3 for now.
	anchorRatio := 0.3

	vines, err := ClearableFirstPlacement(gridSize, spec, profile, genCfg, seed, anchorRatio, false)
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

func (s *LegacySolverAwareStrategy) PlaceVines(config GenerationConfig, rng *rand.Rand, stats *GenerationStats) ([]model.Vine, map[string]string, error) {
	spec, ok := DifficultySpecs[config.Difficulty]
	if !ok {
		// Fallback
		spec = DifficultySpecs["Seedling"]
	}
	profile := GetPresetProfile(config.Difficulty)
	genCfg := GetGeneratorConfigForDifficulty(config.Difficulty)
	gridSize := []int{config.GridWidth, config.GridHeight}

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

// init registers the legacy strategies
func init() {
	RegisterStrategy(StrategyLegacyTiling, "Legacy Tiling (Standard)", func() VinePlacementStrategy {
		return &LegacyTilingStrategy{}
	})
	RegisterStrategy(StrategyLegacyClearable, "Legacy Clearable-First", func() VinePlacementStrategy {
		return &LegacyClearableStrategy{}
	})
	RegisterStrategy(StrategyLegacySolverAware, "Legacy Solver-Aware", func() VinePlacementStrategy {
		return &LegacySolverAwareStrategy{}
	})
}
