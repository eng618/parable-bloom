package gen2

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func makeVine(id, dir string, path []model.Point) model.Vine {
	return model.Vine{ID: id, HeadDirection: dir, OrderedPath: path}
}

func TestBuildBlockingGraphSimple(t *testing.T) {
	// vine A occupies (2,2); vine B head at (2,1) facing up -> head will move to (2,2)
	vA := makeVine("A", "right", []model.Point{{X: 2, Y: 2}, {X: 3, Y: 2}})
	vB := makeVine("B", "up", []model.Point{{X: 2, Y: 1}, {X: 2, Y: 0}})
	vC := makeVine("C", "left", []model.Point{{X: 5, Y: 5}, {X: 6, Y: 5}})

	graph := BuildBlockingGraph([]model.Vine{vA, vB, vC})
	if !graph["A"]["B"] {
		t.Fatalf("expected A to block B")
	}
	if graph["B"]["A"] {
		t.Fatalf("did not expect B to block A")
	}
}

func TestPickBacktrackCandidatesPrioritizesDirectBlockers(t *testing.T) {
	// A blocks B; D blocks many others
	graph := map[string]map[string]bool{
		"A": {"B": true},
		"D": {"X": true, "Y": true, "Z": true},
		"E": {},
	}
	cands := PickBacktrackCandidates(graph, "B", 2)
	if len(cands) == 0 {
		t.Fatalf("expected candidates, got none")
	}
	// A should be first (direct blocker)
	if cands[0] != "A" {
		t.Fatalf("expected A first, got %v", cands)
	}
}
