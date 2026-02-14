package strategies_test

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/metrics"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
)

func BenchmarkClearableFirstCoverage(b *testing.B) {
	// Setup standard difficulty
	diff := "Nurturing" // Level 10-ish difficulty
	genCfg := config.GenerationConfig{
		LevelID:     10,
		GridWidth:   11, // Standard size
		GridHeight:  18,
		VineCount:   10,
		MaxMoves:    25,
		Difficulty:  diff,
		Seed:        12345,
		MinCoverage: 0.95,
	}

	spec, ok := config.DifficultySpecs[diff]
	if !ok {
		b.Fatalf("Unknown difficulty: %s", diff)
	}
	tuningCfg := utils.GetGeneratorConfigForDifficulty(diff)
	profile := utils.GetPresetProfile(diff)

	seeds := []int64{313385, 123, 456, 789, 999}

	// Add more random seeds
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	for i := 0; i < 20; i++ {
		seeds = append(seeds, rng.Int63())
	}

	var totalCoverage float64
	var successCount int

	for _, seed := range seeds {
		// Run generation
		vines, err := strategies.ClearableFirstPlacement(
			[]int{genCfg.GridWidth, genCfg.GridHeight},
			spec,
			profile,
			tuningCfg,

			seed,
			0.3, // anchor ratio
			genCfg.MinCoverage,
			true, // greedy solvability check
		)

		if err == nil {
			successCount++
			cov := metrics.CalculateCoverage([]int{genCfg.GridWidth, genCfg.GridHeight}, vines)
			totalCoverage += cov
		}
	}

	avgCoverage := totalCoverage / float64(len(seeds))
	successRate := float64(successCount) / float64(len(seeds))

	fmt.Printf("\nBenchmark Results (ClearableFirst):\n")
	fmt.Printf("Seeds Tested: %d\n", len(seeds))
	fmt.Printf("Success Rate: %.2f%%\n", successRate*100)
	fmt.Printf("Avg Coverage: %.2f%%\n", avgCoverage*100)
}

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
	t.Logf("Coverage for seed 313385: %.2f%%", cov*100)

	if cov < 0.90 {
		t.Errorf("Coverage too low for known bad seed: got %.2f%%, want >= 90%%", cov*100)
	}
}

func TestFindFailingSeed(t *testing.T) {
	diff := "Nurturing"
	genCfg := config.GenerationConfig{
		LevelID:     10,
		GridWidth:   11,
		GridHeight:  18,
		Difficulty:  diff,
		MinCoverage: 0.95,
	}

	spec := config.DifficultySpecs[diff]
	tuningCfg := utils.GetGeneratorConfigForDifficulty(diff)
	profile := utils.GetPresetProfile(diff)

	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	for i := 0; i < 100; i++ {
		seed := rng.Int63()
		_, err := strategies.ClearableFirstPlacement(
			[]int{genCfg.GridWidth, genCfg.GridHeight},
			spec,
			profile,
			tuningCfg,
			seed,
			0.3,
			genCfg.MinCoverage,
			true,
		)
		if err != nil {
			t.Logf("Found failing seed: %d (Error: %v)", seed, err)
			return // Found one
		}
	}
	t.Log("No failing seeds found in 100 attempts")
}

func BenchmarkCenterOutCoverage(b *testing.B) {
	runStrategyBenchmark(b, &strategies.CenterOutPlacer{})
}

func BenchmarkDirectionFirstCoverage(b *testing.B) {
	runStrategyBenchmark(b, &strategies.DirectionFirstPlacer{})
}

func runStrategyBenchmark(b *testing.B, strategy config.VinePlacementStrategy) {
	// Setup standard difficulty
	diff := "Nurturing"
	genCfg := config.GenerationConfig{
		LevelID:    10,
		GridWidth:  11,
		GridHeight: 18,
		VineCount:  10,
		MaxMoves:   25,
		Difficulty: diff,
		Seed:       12345,
		// Ensure defaults for backtracking are set
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		MinCoverage:          0.95,
	}

	seeds := []int64{313385, 123, 456, 789, 999}
	// Add more random seeds
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	for i := 0; i < 20; i++ {
		seeds = append(seeds, rng.Int63())
	}

	var totalCoverage float64
	var successCount int

	for _, seed := range seeds {
		genCfg.Seed = seed
		// Reset stats for each run
		stats := &config.GenerationStats{}

		// Run generation
		vines, _, err := strategy.PlaceVines(genCfg, rand.New(rand.NewSource(seed)), stats)

		if err == nil {
			successCount++
			cov := metrics.CalculateCoverage([]int{genCfg.GridWidth, genCfg.GridHeight}, vines)
			totalCoverage += cov
		}
	}

	avgCoverage := totalCoverage / float64(len(seeds))
	successRate := float64(successCount) / float64(len(seeds))

	fmt.Printf("\nBenchmark Results (%T):\n", strategy)
	fmt.Printf("Seeds Tested: %d\n", len(seeds))
	fmt.Printf("Success Rate: %.2f%%\n", successRate*100)
	fmt.Printf("Avg Coverage: %.2f%%\n", avgCoverage*100)
}

func TestCenterOutDebug(t *testing.T) {
	common.VerboseEnabled = true
	defer func() { common.VerboseEnabled = false }()

	// Debug specific Nurturing seed that fails
	diff := "Nurturing"
	genCfg := config.GenerationConfig{
		LevelID:              10,
		GridWidth:            11,
		GridHeight:           18,
		VineCount:            10,
		MaxMoves:             25,
		Difficulty:           diff,
		Seed:                 12345,
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		MinCoverage:          0.7,
	}

	stats := &config.GenerationStats{}
	strategy := &strategies.CenterOutPlacer{}

	vines, _, err := strategy.PlaceVines(genCfg, rand.New(rand.NewSource(genCfg.Seed)), stats)
	if err != nil {
		t.Fatalf("CenterOut failed: %v", err)
	}
	t.Logf("CenterOut success: %d vines", len(vines))
}

func TestDirectionFirstDebug(t *testing.T) {
	common.VerboseEnabled = true
	defer func() { common.VerboseEnabled = false }()

	diff := "Nurturing"
	genCfg := config.GenerationConfig{
		LevelID:              10,
		GridWidth:            11,
		GridHeight:           18,
		VineCount:            10,
		MaxMoves:             25,
		Difficulty:           diff,
		Seed:                 12345,
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		MinCoverage:          0.95,
	}

	stats := &config.GenerationStats{}
	strategy := &strategies.DirectionFirstPlacer{}

	vines, _, err := strategy.PlaceVines(genCfg, rand.New(rand.NewSource(genCfg.Seed)), stats)
	if err != nil {
		t.Logf("DirectionFirst failed (expected): %v", err)
	}
	cov := metrics.CalculateCoverage([]int{genCfg.GridWidth, genCfg.GridHeight}, vines)
	t.Logf("DirectionFirst coverage: %.2f%% (%d vines)", cov*100, len(vines))
}
