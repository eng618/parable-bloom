package gen2

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestReplayRegressionSeeds(t *testing.T) {
	pattern := "../../test/fixtures/failing_dumps/*.json"
	files, err := filepath.Glob(pattern)
	if err != nil {
		t.Fatalf("failed to glob fixtures: %v", err)
	}
	if len(files) == 0 {
		t.Fatalf("no fixtures found at %s", pattern)
	}

	for _, f := range files {
		name := filepath.Base(f)
		t.Run(name, func(t *testing.T) {
			b, rerr := os.ReadFile(f)
			if rerr != nil {
				t.Fatalf("failed to read fixture %s: %v", f, rerr)
			}

			var m map[string]interface{}
			if jerr := json.Unmarshal(b, &m); jerr != nil {
				t.Fatalf("failed to parse fixture %s: %v", f, jerr)
			}

			levelID := int(m["level_id"].(float64))
			seed := int64(m["seed"].(float64))

			// grid may be present in fixture; fallback to defaults
			gridW, gridH := 7, 10
			if g, ok := m["grid"].([]interface{}); ok && len(g) >= 2 {
				gridW = int(g[0].(float64))
				gridH = int(g[1].(float64))
			}

			tmpDir := t.TempDir()
			config := GenerationConfig{
				LevelID:              levelID,
				GridWidth:            gridW,
				GridHeight:           gridH,
				VineCount:            10,
				MaxMoves:             20,
				Randomize:            false,
				Seed:                 seed,
				Overwrite:            true,
				MinCoverage:          1.0,
				Difficulty:           "Seedling",
				BacktrackWindow:      6,
				MaxBacktrackAttempts: 6,
				DumpDir:              tmpDir,
				OutputFile:           filepath.Join(tmpDir, "level.json"),
			}

			level, _, err := GenerateLevelLIFO(config)
			if err == nil {
				if level.ID != levelID {
					t.Fatalf("expected generated level ID %d got %d", levelID, level.ID)
				}
				return
			}

			entries, rerr := os.ReadDir(tmpDir)
			if rerr != nil {
				t.Fatalf("failed to read dump dir: %v", rerr)
			}
			if len(entries) == 0 {
				t.Fatalf("expected dump files for fixture %s, none found", name)
			}
		})
	}
}
