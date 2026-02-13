package metrics

import (
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// VerifySolvability checks if the level is solvable using the standard solver.
func VerifySolvability(level *model.Level) bool {
	solver := common.NewSolver(level)
	return solver.IsSolvableGreedy()
}
