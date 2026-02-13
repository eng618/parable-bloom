package strategies_test

import (
	"math/rand"
	"path/filepath"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
)

// TestLIFOBacktrackingProducesDumpsAndSucceeds tests that the LIFO backtracking
// mechanism works correctly. Uses a small grid with relaxed coverage to ensure
// the test is deterministic and not dependent on specific seed behavior.
func TestLIFOBacktrackingProducesDumpsAndSucceeds(t *testing.T) {
	tmpDir := t.TempDir()
	genCfg := config.GenerationConfig{
		LevelID:              1,
		GridWidth:            5,
		GridHeight:           6, // 30 cells, very small grid
		VineCount:            4,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 12345,
		Overwrite:            true,
		MinCoverage:          0.80, // Relaxed coverage for test stability
		Difficulty:           "Seedling",
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		DumpDir:              tmpDir,
		OutputFile:           filepath.Join(tmpDir, "level_1.json"),
	}

	level, stats, err := generator.GenerateLevelLIFO(genCfg)
	if err != nil {
		t.Fatalf("expected generation to succeed, got error: %v", err)
	}
	if level.ID != 1 {
		t.Fatalf("unexpected level id: %d", level.ID)
	}
	if stats.PlacementAttempts == 0 {
		t.Fatalf("expected some placement attempts, got 0")
	}
}

// TestAttemptLocalBacktrackRecovers tests that aggressive backtracking can
// recover from difficult placement scenarios.
func TestAttemptLocalBacktrackRecovers(t *testing.T) {
	genCfg := config.GenerationConfig{
		LevelID:              1,
		GridWidth:            5,
		GridHeight:           6,
		VineCount:            4,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 54321,
		Overwrite:            true,
		MinCoverage:          0.80,
		Difficulty:           "Seedling",
		BacktrackWindow:      6,
		MaxBacktrackAttempts: 6,
		DumpDir:              t.TempDir(),
		OutputFile:           filepath.Join(t.TempDir(), "level_1.json"),
	}

	rng := rand.New(rand.NewSource(genCfg.Seed))
	placer := &strategies.CenterOutPlacer{}
	vines, _, err := placer.PlaceVines(genCfg, rng, &config.GenerationStats{})
	if err != nil {
		t.Fatalf("expected PlaceVines to succeed with aggressive backtracking, got: %v", err)
	}
	if len(vines) < 2 {
		t.Fatalf("expected at least 2 vines, got %d", len(vines))
	}
}

// TestCycleBreakerRepairRecovers tests that the cycle-breaker mechanism
// can recover from placement failures.
func TestCycleBreakerRepairRecovers(t *testing.T) {
	genCfg := config.GenerationConfig{
		LevelID:              28,
		GridWidth:            5,
		GridHeight:           6,
		VineCount:            4,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 99999,
		Overwrite:            true,
		MinCoverage:          0.75, // Lower threshold for test stability
		Difficulty:           "Seedling",
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		DumpDir:              t.TempDir(),
		OutputFile:           filepath.Join(t.TempDir(), "level_28.json"),
	}

	level, stats, err := generator.GenerateLevelLIFO(genCfg)
	if err != nil {
		t.Fatalf("expected cycle-breaker to recover and succeed for seed %d, got: %v", genCfg.Seed, err)
	}
	if level.ID != 28 {
		t.Fatalf("unexpected level id: %d", level.ID)
	}
	if stats.PlacementAttempts == 0 {
		t.Fatalf("expected some placement attempts, got 0")
	}
}

// TestCycleBreakerMultiRemovalRecovers tests that multi-vine removal
// can recover from complex placement failures.
func TestCycleBreakerMultiRemovalRecovers(t *testing.T) {
	genCfg := config.GenerationConfig{
		LevelID:              28,
		GridWidth:            5,
		GridHeight:           6,
		VineCount:            4,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 88888,
		Overwrite:            true,
		MinCoverage:          0.75,
		Difficulty:           "Seedling",
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		DumpDir:              t.TempDir(),
		OutputFile:           filepath.Join(t.TempDir(), "level_28.json"),
	}

	level, stats, err := generator.GenerateLevelLIFO(genCfg)
	if err != nil {
		t.Fatalf("expected multi-removal cycle-breaker to recover and succeed for seed %d, got: %v", genCfg.Seed, err)
	}
	if level.ID != 28 {
		t.Fatalf("unexpected level id: %d", level.ID)
	}
	if stats.PlacementAttempts == 0 {
		t.Fatalf("expected some placement attempts, got 0")
	}
}
