package common

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestIsSolvableBFSGuardOversized(t *testing.T) {
	// 70 vines exceeds 63-bit mask; must return false, not panic/overflow.
	vines := make([]model.Vine, 70)
	for i := range vines {
		vines[i] = model.Vine{
			ID:            "vine",
			HeadDirection: "right",
			OrderedPath:   []model.Point{{X: 0, Y: 0}},
		}
	}
	lvl := &model.Level{GridSize: []int{10, 10}, Vines: vines}
	s := NewSolver(lvl)
	if s.IsSolvableBFS() {
		t.Fatalf("expected false for oversized vine count")
	}
}

func TestPointKeyRoundTrip(t *testing.T) {
	p := model.Point{X: 3, Y: 7}
	k := PointKey(p)
	x, y := ParsePointKey(k)
	if x != 3 || y != 7 {
		t.Fatalf("round trip got %d,%d", x, y)
	}
	if x, y := ParsePointKey("bogus"); x != 0 || y != 0 {
		t.Fatalf("malformed key should return zeros")
	}
}
