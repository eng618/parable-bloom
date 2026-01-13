package tutorials

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

var (
	checkSolvable bool
	maxStates     int
)

// tutorialsCmd represents the validate-tutorials command
var tutorialsCmd = &cobra.Command{
	Use:     "validate-tutorials",
	Aliases: []string{"tut", "tutorials"},
	Short:   "Validate tutorial/lesson levels",
	Long: `Validate tutorial and lesson levels with relaxed rules.

Unlike main level validation, tutorial levels allow:
  - Sparse grid occupancy (not required to be 100% full)
  - Smaller grids for teaching specific mechanics
  - Simplified color schemes

Structural validation is still performed, and solvability checks
can be optionally enabled.

Examples:
  level-builder validate-tutorials
  level-builder tut --check-solvable
  level-builder tutorials --check-solvable --max-states 50000 --verbose`,
	RunE: func(cmd *cobra.Command, args []string) error {
		common.Info("Starting tutorial/lesson validation...")
		common.Verbose("Check solvable: %v, Max states: %d", checkSolvable, maxStates)

		if err := validator.ValidateTutorials(checkSolvable, maxStates); err != nil {
			return fmt.Errorf("tutorial validation failed: %w", err)
		}

		return nil
	},
}

func init() {
	tutorialsCmd.Flags().BoolVarP(&checkSolvable, "check-solvable", "s", false, "run solvability checks (may be slow)")
	tutorialsCmd.Flags().IntVar(&maxStates, "max-states", 100000, "max states budget for solver heuristic")
}

// GetCommand returns the tutorials validation command for registration with root
func GetCommand() *cobra.Command {
	return tutorialsCmd
}
