package generate

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
)

var (
	count      int
	seed       int64
	randomize  bool
	moduleID   int
	difficulty string
	overwrite  bool
)

// generateCmd represents the generate command
var generateCmd = &cobra.Command{
	Use:     "generate",
	Aliases: []string{"gen", "g"},
	Short:   "Generate new puzzle levels",
	Long: `Generate new puzzle levels for Parable Bloom.

Creates a specified number of levels with auto-assigned difficulty tiers,
grid sizes, and vine configurations. Generated levels are saved to
assets/levels/ and a modules.json registry is created.

Examples:
  level-builder generate --count 50
  level-builder gen --count 100 --verbose
  level-builder g -c 20 -v
  level-builder g -c 10 --seed 12345
  level-builder g -c 5 --randomize
  level-builder g --module 2 --verbose
  level-builder g --difficulty Seedling -c 10`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Validate difficulty flag if provided
		if difficulty != "" {
			validDifficulties := []string{"Tutorial", "Seedling", "Sprout", "Nurturing", "Flourishing", "Transcendent"}
			found := false
			for _, d := range validDifficulties {
				if d == difficulty {
					found = true
					break
				}
			}
			if !found {
				return fmt.Errorf("invalid difficulty '%s'. Valid options: Tutorial, Seedling, Sprout, Nurturing, Flourishing, Transcendent", difficulty)
			}
		}

		common.Info("Starting level generation...")
		common.Verbose("Generating %d levels", count)
		if seed != 0 {
			common.Verbose("Using base seed: %d", seed)
		}
		if randomize {
			common.Verbose("Using randomized seeds (will be recorded in level metadata)")
		}
		if moduleID != 0 {
			common.Verbose("Generating for module: %d", moduleID)
		}
		if difficulty != "" {
			common.Verbose("Fixed difficulty: %s", difficulty)
		}

		if err := generator.Generate(count, seed, randomize, moduleID, difficulty, overwrite); err != nil {
			return fmt.Errorf("generation failed: %w", err)
		}

		common.Info("✓ Successfully generated %d levels", count)
		return nil
	},
}

func init() {
	generateCmd.Flags().IntVarP(&count, "count", "c", 50, "number of levels to generate")
	generateCmd.Flags().Int64VarP(&seed, "seed", "s", 0, "base seed for generation (0 = random, per-level seeds derived for batch)")
	generateCmd.Flags().BoolVarP(&randomize, "randomize", "r", false, "use time-based random seeds (recorded in level metadata)")
	generateCmd.Flags().IntVarP(&moduleID, "module", "m", 0, "generate all levels for a specific module (1-8)")
	generateCmd.Flags().StringVarP(&difficulty, "difficulty", "d", "", "fixed difficulty tier (Tutorial, Seedling, Sprout, Nurturing, Flourishing, Transcendent)")
	generateCmd.Flags().BoolVar(&overwrite, "overwrite", false, "overwrite existing level files")
}

// GetCommand returns the generate command for registration with root
func GetCommand() *cobra.Command {
	return generateCmd
}
