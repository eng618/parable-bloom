package batch

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/metrics"
)

// TestSampleModuleShape generates one module into a temp directory and
// checks the session ladder. It is skipped in short mode because the
// transcendent board is much larger than the level-1 canary.
func TestSampleModuleShape(t *testing.T) {
	if testing.Short() {
		t.Skip("sample module generation")
	}
	tmp := t.TempDir()
	cfg := Config{
		ModuleID:   1,
		OutputDir:  filepath.Join(tmp, "levels"),
		DumpDir:    filepath.Join(tmp, "dumps"),
		StatsOut:   filepath.Join(tmp, "stats"),
		Aggressive: true,
	}
	batch, err := GenerateModule(cfg)
	if err != nil {
		t.Fatal(err)
	}

	grids := map[string]map[[2]int]int{}
	for _, result := range batch.Levels {
		if !result.Success {
			t.Errorf("level %d (%s) failed: %s", result.LevelID, result.Difficulty, result.Error)
			continue
		}
		level, lerr := common.ReadLevel(filepath.Join(cfg.OutputDir, "level_"+strconv.Itoa(result.LevelID)+".json"))
		if lerr != nil {
			t.Errorf("level %d: %v", result.LevelID, lerr)
			continue
		}
		q := metrics.AnalyzeQuality(*level)
		if cerr := metrics.CheckContract(*level, q); cerr != nil {
			t.Errorf("level %d contract: %v", result.LevelID, cerr)
		}
		key := [2]int{level.GridSize[0], level.GridSize[1]}
		if grids[level.Difficulty] == nil {
			grids[level.Difficulty] = map[[2]int]int{}
		}
		grids[level.Difficulty][key]++
		t.Logf("L%d %s %dx%d vines=%d avg=%.1f short=%.0f%% mask=%.1f%% free=%.0f%% strategy=%s",
			result.LevelID, level.Difficulty, key[0], key[1], len(level.Vines),
			q.AvgVineLength, q.ShortVineShare*100, q.MaskShare*100, q.FreeVineShare*100,
			statsStrategy(cfg.StatsOut, result.LevelID))
	}
	for tier, set := range grids {
		want := 5
		if tier == "Transcendent" {
			want = 1
		}
		if len(set) != want {
			t.Errorf("%s has %d distinct grids, want %d", tier, len(set), want)
		}
	}
}

func statsStrategy(dir string, levelID int) string {
	raw, err := os.ReadFile(filepath.Join(dir, "level_"+strconv.Itoa(levelID)+"_stats.json"))
	if err != nil {
		return "?"
	}
	var stats struct {
		Strategy string `json:"strategy"`
		Motif    string `json:"motif"`
	}
	if err := json.Unmarshal(raw, &stats); err != nil {
		return "?"
	}
	if stats.Motif != "" && stats.Motif != stats.Strategy {
		return stats.Strategy + "/" + stats.Motif
	}
	if stats.Motif != "" {
		return stats.Motif
	}
	return stats.Strategy
}
