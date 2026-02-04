package gen2

import (
	"fmt"
	"path/filepath"
	"testing"
)

// TestGeneratedLevelsHaveUniqueVineIDs verifies that all generated vines
// have unique IDs. Uses small grids and relaxed coverage for test stability.
func TestGeneratedLevelsHaveUniqueVineIDs(t *testing.T) {
	tests := []GenerationConfig{
		{LevelID: 1, GridWidth: 5, GridHeight: 6, VineCount: 4, Randomize: false, Seed: 11111, MinCoverage: 0.70, Overwrite: true, Difficulty: "Seedling"},
		{LevelID: 2, GridWidth: 5, GridHeight: 6, VineCount: 4, Randomize: false, Seed: 22222, MinCoverage: 0.70, Overwrite: true, Difficulty: "Seedling"},
		{LevelID: 3, GridWidth: 5, GridHeight: 6, VineCount: 4, Randomize: false, Seed: 33333, MinCoverage: 0.70, Overwrite: true, Difficulty: "Seedling"},
	}

	for _, cfg := range tests {
		tmpDir := t.TempDir()
		cfg.OutputFile = filepath.Join(tmpDir, fmt.Sprintf("level_%d.json", cfg.LevelID))
		level, _, err := GenerateLevelLIFO(cfg)
		if err != nil {
			t.Fatalf("generation failed for seed %d: %v", cfg.Seed, err)
		}

		seen := map[string]struct{}{}
		for _, v := range level.Vines {
			if _, ok := seen[v.ID]; ok {
				t.Fatalf("duplicate vine id %s in level %d", v.ID, cfg.LevelID)
			}
			seen[v.ID] = struct{}{}
		}
	}
}
