package validator

import (
	"fmt"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestGreedySolverPriority(t *testing.T) {
	// Construct a large level that is trivially solvable by greedy algorithm
	// but would be expensive for A* if it tries to explore states.
	// 14x22 grid (Level 18 size)
	w, h := 14, 22

	// Create ~30 simple horizontal vines.
	// Each vine is length 4, moving right.
	// They are placed in separate rows/columns so they don't block each other at all.
	var vines []model.Vine

	// Fill grid with purely horizontal vines that exit right
	count := 0
	for y := 0; y < h; y += 2 {
		for x := 0; x < w-3; x += 4 { // fits 3 vines per row: x=0,4,8 in width 14
			v := model.Vine{
				ID:            fmt.Sprintf("v%d", count),
				HeadDirection: "right",
				OrderedPath: []model.Point{
					{X: x + 2, Y: y}, // Head
					{X: x + 1, Y: y},
					{X: x, Y: y}, // Tail
				},
			}
			vines = append(vines, v)
			count++
		}
	}

	if len(vines) <= 24 {
		t.Fatalf("Test requires > 24 vines to trigger potential A* fallback, got %d", len(vines))
	}

	level := model.Level{
		ID:       999,
		GridSize: []int{w, h},
		Vines:    vines,
	}

	// With the fix, this should use "greedy-fast" and return immediately.
	// Without the fix, it would fall through to isSolvableExactAStarWithStats (since count <= 64 but > 24 is handled by A* or Heuristic depending on implementation details, but here we want to ensure greedy is checked FIRST).

	ok, stats, err := IsSolvableWithOptions(level, 100000, true, 10)
	if err != nil {
		t.Fatalf("IsSolvableWithOptions failed: %v", err)
	}

	if !ok {
		t.Fatal("Level should be solvable")
	}

	if stats.Solver != "greedy-fast" {
		t.Errorf("Expected solver 'greedy-fast', got '%s'", stats.Solver)
	}
}
