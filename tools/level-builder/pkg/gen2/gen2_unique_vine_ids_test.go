package gen2

import (
	"fmt"
	"path/filepath"
	"testing"
)

func TestGeneratedLevelsHaveUniqueVineIDs(t *testing.T) {
	tests := []GenerationConfig{
		{LevelID: 1, GridWidth: 7, GridHeight: 10, VineCount: 10, Randomize: false, Seed: 31337, MinCoverage: 0.85, Overwrite: true, Difficulty: "Seedling"},
		{LevelID: 2, GridWidth: 7, GridHeight: 10, VineCount: 10, Randomize: false, Seed: 62674, MinCoverage: 0.85, Overwrite: true, Difficulty: "Seedling"},
		{LevelID: 3, GridWidth: 7, GridHeight: 10, VineCount: 10, Randomize: false, Seed: 94011, MinCoverage: 0.85, Overwrite: true, Difficulty: "Seedling"},
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
