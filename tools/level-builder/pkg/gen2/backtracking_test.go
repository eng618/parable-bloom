package gen2

import (
	"math/rand"
	"os"
	"testing"
)

func TestLIFOBacktrackingProducesDumpsAndSucceeds(t *testing.T) {
	tmpDir := t.TempDir()
	config := GenerationConfig{
		LevelID:              1,
		GridWidth:            7,
		GridHeight:           10,
		VineCount:            10,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 31337,
		Overwrite:            true,
		MinCoverage:          1.0,
		Difficulty:           "Seedling",
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		DumpDir:              tmpDir,
	}

	level, stats, err := GenerateLevelLIFO(config)
	if err != nil {
		t.Fatalf("expected generation to succeed, got error: %v", err)
	}
	if level.ID != 1 {
		t.Fatalf("unexpected level id: %d", level.ID)
	}
	if stats.PlacementAttempts == 0 {
		t.Fatalf("expected some placement attempts, got 0")
	}
	if stats.BacktracksAttempted == 0 {
		t.Fatalf("expected backtracks attempted > 0, got 0")
	}
	if stats.DumpsProduced == 0 {
		t.Fatalf("expected at least one dump to be produced, got 0")
	}

	// Ensure dumps were created for failing attempts (we expect at least one)
	entries, err := os.ReadDir(tmpDir)
	if err != nil {
		t.Fatalf("failed to read dump dir: %v", err)
	}
	if len(entries) == 0 {
		t.Fatalf("expected dump files in %s, found none", tmpDir)
	}
}

func TestAttemptLocalBacktrackRecovers(t *testing.T) {
	// Use a seed known to cause a per-vine failure under small windows but succeed under aggressive
	config := GenerationConfig{
		LevelID:              1,
		GridWidth:            7,
		GridHeight:           10,
		VineCount:            10,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 31337,
		Overwrite:            true,
		MinCoverage:          1.0,
		Difficulty:           "Seedling",
		BacktrackWindow:      6,
		MaxBacktrackAttempts: 6,
	}

	rng := rand.New(rand.NewSource(config.Seed))
	placer := &CenterOutPlacer{}
	vines, _, err := placer.PlaceVines(config, rng, &GenerationStats{})
	if err != nil {
		t.Fatalf("expected PlaceVines to succeed with aggressive backtracking, got: %v", err)
	}
	if len(vines) < 2 {
		t.Fatalf("expected at least 2 vines, got %d", len(vines))
	}
}

func TestCycleBreakerRepairRecovers(t *testing.T) {
	// Replay a known failing seed which previously produced a high-coverage unsolvable state
	config := GenerationConfig{
		LevelID:              28,
		GridWidth:            7,
		GridHeight:           10,
		VineCount:            10,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 877436,
		Overwrite:            true,
		MinCoverage:          1.0,
		Difficulty:           "Seedling",
		BacktrackWindow:      3, // conservative window to force fallback path
		MaxBacktrackAttempts: 2,
		DumpDir:              t.TempDir(),
	}

	level, stats, err := GenerateLevelLIFO(config)
	if err != nil {
		t.Fatalf("expected cycle-breaker to recover and succeed for seed %d, got: %v", config.Seed, err)
	}
	if level.ID != 28 {
		t.Fatalf("unexpected level id: %d", level.ID)
	}
	if stats.PlacementAttempts == 0 {
		t.Fatalf("expected some placement attempts, got 0")
	}
}

func TestCycleBreakerMultiRemovalRecovers(t *testing.T) {
	// Seed 897436 previously produced a high-coverage unsolvable state that required
	// removing multiple vines in a cycle to recover.
	config := GenerationConfig{
		LevelID:              28,
		GridWidth:            7,
		GridHeight:           10,
		VineCount:            10,
		MaxMoves:             20,
		Randomize:            false,
		Seed:                 897436,
		Overwrite:            true,
		MinCoverage:          1.0,
		Difficulty:           "Seedling",
		BacktrackWindow:      3,
		MaxBacktrackAttempts: 2,
		DumpDir:              t.TempDir(),
	}

	level, stats, err := GenerateLevelLIFO(config)
	if err != nil {
		t.Fatalf("expected multi-removal cycle-breaker to recover and succeed for seed %d, got: %v", config.Seed, err)
	}
	if level.ID != 28 {
		t.Fatalf("unexpected level id: %d", level.ID)
	}
	if stats.PlacementAttempts == 0 {
		t.Fatalf("expected some placement attempts, got 0")
	}
}