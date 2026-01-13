package clean

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
)

// cleanCmd represents the clean command
var cleanCmd = &cobra.Command{
	Use:   "clean",
	Short: "Remove generated levels and modules",
	Long: `Remove all generated level files and the modules registry.

Deletes:
  - All level_*.json files in assets/levels/
  - assets/data/modules.json

This is a destructive operation. Use with caution.

Examples:
  level-builder clean
  level-builder clean --verbose`,
	RunE: func(cmd *cobra.Command, args []string) error {
		common.Info("Cleaning generated levels...")
		common.Verbose("Deleting level files and modules.json")

		if err := generator.Clean(); err != nil {
			return fmt.Errorf("clean failed: %w", err)
		}

		common.Info("✓ Successfully cleaned generated levels")
		return nil
	},
}

// GetCommand returns the clean command for registration with root
func GetCommand() *cobra.Command {
	return cleanCmd
}
