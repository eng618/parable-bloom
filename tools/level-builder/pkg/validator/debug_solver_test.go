package validator

import (
	"testing"
)

func TestDebugAStarLevel33(t *testing.T) {
	lvl := loadLevel(t, "../../assets/levels/level_33.json")
	for _, useAstar := range []bool{false, true} {
		ok, stats, err := IsSolvableWithOptions(lvl, 300000, useAstar, 10)
		if err != nil {
			t.Fatalf("solver failed: %v", err)
		}
		t.Logf("useAstar=%v ok=%v states=%d solver=%s gaveUp=%v", useAstar, ok, stats.StatesExplored, stats.Solver, stats.GaveUp)
	}
}
