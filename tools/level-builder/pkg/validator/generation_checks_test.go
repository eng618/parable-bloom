package validator

import (
	"strings"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func baseFullGridLevel() model.Level {
	vineIDs := []string{"v1", "v2", "v3", "v4"}
	rows := []int{0, 1, 2, 3}
	vines := make([]model.Vine, len(rows))
	for i, row := range rows {
		vines[i] = model.Vine{
			ID:            vineIDs[i],
			HeadDirection: "right",
			OrderedPath: []model.Point{
				{X: 3, Y: row},
				{X: 2, Y: row},
				{X: 1, Y: row},
				{X: 0, Y: row},
			},
			ColorIndex: 0,
		}
	}

	return model.Level{
		ID:          1,
		GridSize:    []int{4, 4},
		Vines:       vines,
		MaxMoves:    16,
		Grace:       3,
		ColorScheme: []string{"#000000"},
	}
}

func TestValidateDesignConstraints_Success(t *testing.T) {
	lvl := baseFullGridLevel()
	if errs := ValidateDesignConstraints(lvl); len(errs) != 0 {
		t.Fatalf("expected no validation errors, got %d: %v", len(errs), errs)
	}
}

func TestValidateDesignConstraints_OccupancyFailure(t *testing.T) {
	lvl := baseFullGridLevel()
	// Remove three vines to drop occupancy below 25% (tolerance is 40%)
	lvl.Vines = lvl.Vines[:1]

	errs := ValidateDesignConstraints(lvl)
	if len(errs) == 0 {
		t.Fatalf("expected occupancy failure, but got none")
	}

	if !strings.Contains(errs[0].Error(), "vine occupancy") {
		t.Fatalf("unexpected error message: %v", errs[0])
	}
}

func TestValidateDesignConstraints_StructuralFailure(t *testing.T) {
	lvl := baseFullGridLevel()
	lvl.Vines[0].HeadDirection = "up"

	errs := ValidateDesignConstraints(lvl)
	if len(errs) == 0 {
		t.Fatalf("expected structural errors, but got none")
	}

	found := false
	for _, err := range errs {
		if strings.Contains(err.Error(), "head/neck mismatch") {
			found = true
			break
		}
	}

	if !found {
		t.Fatalf("expected head/neck mismatch error, got %v", errs)
	}
}
