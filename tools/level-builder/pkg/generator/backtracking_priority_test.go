package generator

import (
	"math/rand"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// Test that prioritized combo scoring prefers high-impact removals
func TestScoreCombinationPrioritizesBlockingDegree(t *testing.T) {
	// Build a simple configuration: three vines where vine_a blocks vine_c and vine_b blocks vine_c
	vA := model.Vine{ID: "a", HeadDirection: "right", OrderedPath: []model.Point{{X: 2, Y: 2}, {X: 1, Y: 2}}}
	vB := model.Vine{ID: "b", HeadDirection: "right", OrderedPath: []model.Point{{X: 3, Y: 3}, {X: 2, Y: 3}}}
	vC := model.Vine{ID: "c", HeadDirection: "right", OrderedPath: []model.Point{{X: 4, Y: 2}, {X: 3, Y: 2}}}
	vines := []model.Vine{vA, vB, vC}

	graph := BuildBlockingGraph(vines)

	scoreAB := scoreCombination([]string{"a", "b"}, graph, vines)
	scoreA := scoreCombination([]string{"a"}, graph, vines)
	if scoreAB <= scoreA {
		t.Fatalf("expected combined score to be higher: %d > %d", scoreAB, scoreA)
	}
}

// Sanity test ensuring PlaceVines continues to work with stats param
func TestPlaceVinesWithStatsSanity(t *testing.T) {
	config := GenerationConfig{LevelID: 1, GridWidth: 7, GridHeight: 10, VineCount: 8, MinCoverage: 0.8, Seed: 31337}
	rng := rand.New(rand.NewSource(config.Seed))
	p := &CenterOutPlacer{}
	_, occ, err := p.PlaceVines(config, rng, &GenerationStats{})
	if err != nil {
		t.Fatalf("PlaceVines with stats should not error unexpectedly: %v", err)
	}
	if len(occ) == 0 {
		t.Fatalf("expected some occupied cells, got 0")
	}
}
