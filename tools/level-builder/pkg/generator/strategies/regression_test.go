package strategies_test

import (
	"math/rand"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/metrics"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
)

func TestProblematicSeed313385(t *testing.T) {
	diff := "Nurturing"
	genCfg := config.GenerationConfig{
		LevelID:    10,
		GridWidth:  11,
		GridHeight: 18,
		Difficulty: diff,
		Seed:       313385,
	}

	spec, ok := config.DifficultySpecs[diff]
	if !ok {
		t.Fatalf("Unknown difficulty: %s", diff)
	}
	tuningCfg := utils.GetGeneratorConfigForDifficulty(diff)
	profile := utils.GetPresetProfile(diff)

	vines, err := strategies.ClearableFirstPlacement(
		[]int{genCfg.GridWidth, genCfg.GridHeight},
		spec,
		profile,
		tuningCfg,
		genCfg.Seed,
		0.3,
		0.95,
		true,
	)
	if err != nil {
		t.Fatalf("Failed to generate level for seed 313385: %v", err)
	}

	cov := metrics.CalculateCoverage([]int{genCfg.GridWidth, genCfg.GridHeight}, vines)

	if cov < 0.90 {
		t.Errorf("Coverage too low for known bad seed: got %.2f%%, want >= 90%%", cov*100)
	}
}

func TestRegressionSeed569780(t *testing.T) {
	// Setup config for Level 17 (Flourishing)
	difficulty := "Flourishing"
	spec := config.DifficultySpecs[difficulty]
	// Use strict occupancy to mimic original failure condition
	spec.MinGridOccupancy = 0.95
	profile := utils.GetPresetProfile(difficulty)
	genCfg := utils.GetGeneratorConfigForDifficulty(difficulty)
	gridSize := []int{14, 22}

	// Specific failing base seed from reproduce_mismatch_test.go
	// In the original test, it looped 0-100.
	// attempt 0 -> seed = baseSeed + 0*7919 = 569780
	// The original test said "The generator uses the first Int63() as the seed... So we do: seed := rng.Int63()"
	// We need to replicate exactly what the failing condition was.
	// Original code:
	// attemptSeed := baseSeed + int64(attempt)*7919
	// rng := rand.New(rand.NewSource(attemptSeed))
	// seed := rng.Int63()
	// strategies.ClearableFirstPlacement(..., seed, ...)

	baseSeed := int64(569780)
	// We test the base seed (attempt 0) which was the primary target
	attemptSeed := baseSeed
	rng := rand.New(rand.NewSource(attemptSeed))
	seed := rng.Int63()

	vines, err := strategies.ClearableFirstPlacement(gridSize, spec, profile, genCfg, seed, 0.3, spec.MinGridOccupancy, true)
	if err != nil {
		t.Fatalf("Generation failed for seed %d (derived from %d): %v", seed, attemptSeed, err)
	}

	for _, v := range vines {
		if len(v.OrderedPath) < 2 {
			continue
		}
		head := v.OrderedPath[0]
		neck := v.OrderedPath[1]
		dx := head.X - neck.X
		dy := head.Y - neck.Y

		// Validate direction
		var expectedDx, expectedDy int
		switch v.HeadDirection {
		case "up":
			expectedDx, expectedDy = 0, 1
		case "down":
			expectedDx, expectedDy = 0, -1
		case "left":
			expectedDx, expectedDy = -1, 0
		case "right":
			expectedDx, expectedDy = 1, 0
		}

		if dx != expectedDx || dy != expectedDy {
			t.Errorf("MISMATCH DETECTED in vine %s: head=%v neck=%v dir=%s (dx=%d dy=%d)",
				v.ID, head, neck, v.HeadDirection, dx, dy)
		}
	}
}
