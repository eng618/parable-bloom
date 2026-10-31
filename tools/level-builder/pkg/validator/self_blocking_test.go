package validator

import (
	"strings"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestValidateSelfBlocking_ClearExitRay(t *testing.T) {
	lvl := model.Level{
		ID:       1,
		GridSize: []int{4, 3},
		Vines: []model.Vine{
			{
				ID:            "vine_ok",
				HeadDirection: "right",
				// Head at right edge of body — exit ray leaves the grid immediately.
				OrderedPath: []model.Point{
					{X: 2, Y: 1},
					{X: 1, Y: 1},
					{X: 0, Y: 1},
				},
			},
		},
		MaxMoves: 3,
	}

	if errs := ValidateSelfBlocking(lvl); len(errs) != 0 {
		t.Fatalf("expected no self-blocking errors, got %v", errs)
	}
}

func TestValidateSelfBlocking_HeadFacesOwnBody(t *testing.T) {
	// Mirrors the densified Lesson 4 failure mode: head points right into
	// a later segment of the same vine that sits on the exit ray.
	lvl := model.Level{
		ID:       1,
		GridSize: []int{4, 3},
		Vines: []model.Vine{
			{
				ID:            "vine_loop",
				HeadDirection: "right",
				OrderedPath: []model.Point{
					{X: 1, Y: 1},
					{X: 0, Y: 1},
					{X: 0, Y: 2},
					{X: 1, Y: 2},
					{X: 2, Y: 2},
					{X: 2, Y: 1}, // occupies exit ray cell immediately ahead of head
				},
			},
		},
		MaxMoves: 3,
	}

	errs := ValidateSelfBlocking(lvl)
	if len(errs) == 0 {
		t.Fatal("expected self-blocking error, got none")
	}
	if !strings.Contains(errs[0].Error(), "self-blocking") {
		t.Fatalf("expected self-blocking message, got %v", errs[0])
	}
}

func TestValidateStructural_RejectsSelfBlocking(t *testing.T) {
	lvl := model.Level{
		ID:       1,
		GridSize: []int{4, 3},
		Vines: []model.Vine{
			{
				ID:            "vine_loop",
				HeadDirection: "right",
				OrderedPath: []model.Point{
					{X: 1, Y: 1},
					{X: 0, Y: 1},
					{X: 0, Y: 2},
					{X: 1, Y: 2},
					{X: 2, Y: 2},
					{X: 2, Y: 1},
				},
			},
		},
		MaxMoves: 3,
	}

	errs := ValidateStructural(lvl)
	found := false
	for _, err := range errs {
		if strings.Contains(err.Error(), "self-blocking") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("ValidateStructural should reject self-blocking vines, got %v", errs)
	}
}
