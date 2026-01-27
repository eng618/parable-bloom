package gen2

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestIsLikelySolvablePartialSimpleExit(t *testing.T) {
	v := model.Vine{ID: "v1", HeadDirection: "right", OrderedPath: []model.Point{{X: 0, Y: 0}, {X: 1, Y: 0}}}
	v2 := model.Vine{ID: "v2", HeadDirection: "up", OrderedPath: []model.Point{{X: 9, Y: 9}, {X: 9, Y: 8}}}
	vines := []model.Vine{v, v2}
	occ := map[string]string{"0,0": "v1", "1,0": "v1", "9,9": "v2", "9,8": "v2"}
	if !IsLikelySolvablePartial(vines, occ, 10, 10, 10) {
		t.Fatalf("expected simple exit to be likely solvable")
	}
}

func TestIsLikelySolvablePartialBlocked(t *testing.T) {
	// Circular block: A and B head at (2,1) and (1,1) respectively and each wants the other's cell
	A := model.Vine{ID: "A", HeadDirection: "left", OrderedPath: []model.Point{{X: 2, Y: 1}, {X: 3, Y: 1}}}
	B := model.Vine{ID: "B", HeadDirection: "right", OrderedPath: []model.Point{{X: 1, Y: 1}, {X: 0, Y: 1}}}
	vines := []model.Vine{A, B}
	occ := map[string]string{"2,1": "A", "3,1": "A", "1,1": "B", "0,1": "B"}
	// Grid 4x4 contains these positions
	if IsLikelySolvablePartial(vines, occ, 4, 4, 10) {
		t.Fatalf("expected circular blocking to be not likely solvable")
	}
}
