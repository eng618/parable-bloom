package validate

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

var (
	checkSolvable bool
	maxStates     int
	useAstar      bool
	astarWeight   int
)

// validateCmd represents the validate command
var validateCmd = &cobra.Command{
	Use:     "validate",
	Aliases: []string{"val", "v"},
	Short:   "Validate existing levels",
	Long: `Validate puzzle levels for structural integrity and solvability.

Performs comprehensive validation including:
  - Module and level file parsing
  - Grid size and occupancy checks
  - Color scheme validation
  - Optional solvability checks using BFS or A* algorithms

When --check-solvable is enabled, the validator uses advanced solvers
to ensure all levels can be completed. Results are written to
validation_stats.json for analysis.

Examples:
  level-builder validate
  level-builder val --check-solvable
  level-builder v --check-solvable --max-states 100000 --verbose
  level-builder validate --check-solvable --use-astar --astar-weight 10`,
	RunE: func(cmd *cobra.Command, args []string) error {
		common.Info("Starting level validation...")
		common.Verbose("Check solvable: %v, Max states: %d, Use A*: %v, A* weight: %d",
			checkSolvable, maxStates, useAstar, astarWeight)

		if err := validator.Validate(checkSolvable, maxStates, useAstar, astarWeight); err != nil {
			return fmt.Errorf("validation failed: %w", err)
		}

		return nil
	},
}

func init() {
	validateCmd.Flags().BoolVarP(&checkSolvable, "check-solvable", "s", false, "run solvability checks (may be slow)")
	validateCmd.Flags().IntVar(&maxStates, "max-states", 100000, "max states budget for solver heuristic")
	validateCmd.Flags().BoolVar(&useAstar, "use-astar", true, "use A* guided search for exact solver")
	validateCmd.Flags().IntVar(&astarWeight, "astar-weight", validator.DefaultAStarWeight, "weight multiplier for A* heuristic")
}

// GetCommand returns the validate command for registration with root
func GetCommand() *cobra.Command {
	return validateCmd
}
