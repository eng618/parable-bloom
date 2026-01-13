package generate

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
)

var (
	count int
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
  level-builder g -c 20 -v`,
	RunE: func(cmd *cobra.Command, args []string) error {
		common.Info("Starting level generation...")
		common.Verbose("Generating %d levels", count)

		if err := generator.Generate(count); err != nil {
			return fmt.Errorf("generation failed: %w", err)
		}

		common.Info("✓ Successfully generated %d levels", count)
		return nil
	},
}

func init() {
	generateCmd.Flags().IntVarP(&count, "count", "c", 50, "number of levels to generate")
}

// GetCommand returns the generate command for registration with root
func GetCommand() *cobra.Command {
	return generateCmd
}
