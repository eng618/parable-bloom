package validator

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

func TestDebugAStarLevel33(t *testing.T) {
	levelPath, err := common.LevelFilePath(33)
	if err != nil {
		t.Fatalf("Failed to resolve level path: %v", err)
	}
	lvl := loadLevel(t, levelPath)
	for _, useAstar := range []bool{false, true} {
		ok, stats, err := IsSolvableWithOptions(lvl, 300000, useAstar, 10)
		if err != nil {
			t.Fatalf("solver failed: %v", err)
		}
		t.Logf("useAstar=%v ok=%v states=%d solver=%s gaveUp=%v", useAstar, ok, stats.StatesExplored, stats.Solver, stats.GaveUp)
	}
}
