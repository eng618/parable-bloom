package validator

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func loadLevel(t *testing.T, path string) model.Level {
	t.Helper()

	// Try direct read, else search upward for assets/levels
	bytes, err := os.ReadFile(path)
	if err != nil {
		base := filepath.Base(path)
		found := false
		for i := 0; i < 6; i++ {
			prefix := strings.Repeat("../", i)
			candidate := filepath.Clean(prefix + "assets/levels/" + base)
			if b, e := os.ReadFile(candidate); e == nil {
				bytes = b
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("failed to read level file: %v", err)
		}
	}

	var lvl model.Level
	if err := json.Unmarshal(bytes, &lvl); err != nil {
		t.Fatalf("failed to unmarshal level: %v", err)
	}
	return lvl
}

func TestAstarReducesWork_Level33(t *testing.T) {
	lvl := loadLevel(t, "../../assets/levels/level_33.json")
	// Run without A*
	_, statsNo, err := IsSolvableWithOptions(lvl, 300000, false, 10)
	if err != nil {
		t.Fatalf("IsSolvableWithOptions failed (no astar): %v", err)
	}

	// Run with A*
	okYes, statsYes, err := IsSolvableWithOptions(lvl, 300000, true, 10)
	if err != nil {
		t.Fatalf("IsSolvableWithOptions failed (astar): %v", err)
	}

	if !okYes {
		t.Fatalf("A* run should find solution for level 33, but got false (states=%d)", statsYes.StatesExplored)
	}

	if statsYes.StatesExplored > statsNo.StatesExplored {
		t.Fatalf("A* did not reduce states: no=%d astar=%d", statsNo.StatesExplored, statsYes.StatesExplored)
	}
}
