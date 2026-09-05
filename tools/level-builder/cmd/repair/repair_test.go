package repair

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func healthyLevel(id int) model.Level {
	// Fully covered 4x4 level: 100% occupancy, no overlaps.
	// Difficulty matches the canonical lock for the ID.
	return model.Level{
		ID:         id,
		Name:       "Healthy",
		Difficulty: common.ExpectedDifficulty(id),
		GridSize:   []int{4, 4},
		Vines: []model.Vine{
			{ID: "vine_1", HeadDirection: "right", ColorIndex: 0, OrderedPath: []model.Point{{X: 3, Y: 0}, {X: 2, Y: 0}, {X: 1, Y: 0}, {X: 0, Y: 0}}},
			{ID: "vine_2", HeadDirection: "left", ColorIndex: 1, OrderedPath: []model.Point{{X: 0, Y: 1}, {X: 1, Y: 1}, {X: 2, Y: 1}, {X: 3, Y: 1}, {X: 3, Y: 2}, {X: 2, Y: 2}, {X: 1, Y: 2}, {X: 0, Y: 2}, {X: 0, Y: 3}, {X: 1, Y: 3}, {X: 2, Y: 3}, {X: 3, Y: 3}}},
		},
		MaxMoves:    4,
		MinMoves:    2,
		Complexity:  "tutorial",
		Grace:       3,
		ColorScheme: []string{"#888888", "#7CB342"},
	}
}

func writeLevelFile(t *testing.T, dir string, lvl model.Level) string {
	t.Helper()
	path := filepath.Join(dir, "level_"+strconv.Itoa(lvl.ID)+".json")
	b, err := json.MarshalIndent(lvl, "", "  ")
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if err := os.WriteFile(path, b, 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	return path
}

func TestRepairDirectory(t *testing.T) {
	oldCheck, oldStates := checkSolvable, maxStates
	checkSolvable = true
	maxStates = 1000000
	defer func() { checkSolvable, maxStates = oldCheck, oldStates }()

	dir := t.TempDir()

	// Healthy file must be left untouched.
	healthy := healthyLevel(1)
	healthyPath := writeLevelFile(t, dir, healthy)
	before, err := os.ReadFile(healthyPath)
	if err != nil {
		t.Fatalf("read healthy: %v", err)
	}

	// Corrupted JSON.
	if err := os.WriteFile(filepath.Join(dir, "level_2.json"), []byte("{invalid json"), 0o644); err != nil {
		t.Fatalf("write corrupt: %v", err)
	}

	// Structurally invalid: duplicated vine entries overlap.
	bad := healthyLevel(3)
	bad.Vines = append(bad.Vines, bad.Vines[0])
	writeLevelFile(t, dir, bad)

	if err := repairDirectory(dir, true, false); err != nil {
		t.Fatalf("repairDirectory failed: %v", err)
	}

	// Healthy untouched.
	after, _ := os.ReadFile(healthyPath)
	if string(before) != string(after) {
		t.Errorf("healthy file was modified")
	}

	// Corrupted regenerated: parses, ID matches, canonical difficulty.
	for _, id := range []int{2, 3} {
		lvl, err := common.ReadLevel(filepath.Join(dir, "level_"+strconv.Itoa(id)+".json"))
		if err != nil {
			t.Fatalf("level %d still unreadable: %v", id, err)
		}
		if lvl.ID != id {
			t.Errorf("level ID = %d, want %d", lvl.ID, id)
		}
		if want := common.ExpectedDifficulty(id); lvl.Difficulty != want {
			t.Errorf("level %d difficulty = %s, want canonical %s", id, lvl.Difficulty, want)
		}
	}
}

func TestRepairDirectoryDryRun(t *testing.T) {
	oldCheck := checkSolvable
	checkSolvable = true
	defer func() { checkSolvable = oldCheck }()

	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "level_3.json"), []byte("{bad"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}
	if err := repairDirectory(dir, true, true); err != nil {
		t.Fatalf("dry-run failed: %v", err)
	}
	// File must remain corrupted (no writes in dry-run).
	if _, err := common.ReadLevel(filepath.Join(dir, "level_3.json")); err == nil {
		t.Errorf("dry-run should not write files")
	}
}
