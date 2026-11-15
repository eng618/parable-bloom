package strategies

import (
	"math/rand"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestSealHolesPullsPocketOffTheTail(t *testing.T) {
	path := []model.Point{
		{X: 0, Y: 0}, {X: 1, Y: 0}, {X: 2, Y: 0}, {X: 3, Y: 0}, {X: 4, Y: 0},
		{X: 4, Y: 1}, {X: 3, Y: 1}, {X: 3, Y: 2}, {X: 4, Y: 2}, {X: 4, Y: 3},
		{X: 3, Y: 3}, {X: 2, Y: 3}, {X: 1, Y: 3}, {X: 0, Y: 3}, {X: 0, Y: 2},
		{X: 1, Y: 2}, {X: 1, Y: 1}, {X: 0, Y: 1},
	}
	for i := 1; i < len(path); i++ {
		dx := path[i].X - path[i-1].X
		dy := path[i].Y - path[i-1].Y
		if dx*dx+dy*dy != 1 {
			t.Fatalf("path break at %d: %v -> %v", i, path[i-1], path[i])
		}
	}
	vine := model.Vine{ID: "vine_1", HeadDirection: "left", OrderedPath: path}
	occ := map[string]string{}
	for _, p := range path {
		occ[common.PointKey(p)] = vine.ID
	}
	vines := []model.Vine{vine}
	rng := rand.New(rand.NewSource(1))
	vines, occ = SealHoles(vines, occ, 5, 4, rng, 1, 0, 30)
	empty := emptyCount(occ, 5, 4)
	if empty >= 2 {
		t.Fatalf("sealed pocket still has %d empty cells, want fewer than 2", empty)
	}
	if !greedySolvable(vines, 5, 4) {
		t.Fatal("sealed board is not greedy-solvable")
	}
	if vineSelfBlocks(vines[0], 5, 4) {
		t.Fatal("sealed vine blocks its own exit")
	}
}

func TestSealHolesLeavesAFullBoardAlone(t *testing.T) {
	vine := model.Vine{
		ID:            "vine_1",
		HeadDirection: "left",
		OrderedPath:   []model.Point{{X: 0, Y: 0}, {X: 1, Y: 0}, {X: 1, Y: 1}, {X: 0, Y: 1}},
	}
	occ := map[string]string{}
	for _, p := range vine.OrderedPath {
		occ[common.PointKey(p)] = vine.ID
	}
	before := len(vine.OrderedPath)
	vines, _ := SealHoles([]model.Vine{vine}, occ, 2, 2, rand.New(rand.NewSource(1)), 1, 0, 30)
	if len(vines[0].OrderedPath) != before {
		t.Fatalf("full board changed length %d -> %d", before, len(vines[0].OrderedPath))
	}
}
