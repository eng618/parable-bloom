package render

import (
	"fmt"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

var (
	fileFlag   string
	idFlag     int
	styleFlag  string
	coordsFlag bool
)

// RenderCmd renders a level to the terminal for visual inspection.
var RenderCmd = &cobra.Command{
	Use:   "render",
	Short: "Render a level to the terminal (ASCII/Unicode)",
	Long: `Render a level to the terminal for quick visual inspection.

You can supply a file path with --file (-f) or a level id with --id (-i) (looks in assets/levels).

Examples:
  level-builder render --id 1
  level-builder render --file assets/levels/level_33.json
  level-builder render --id 10 --style ascii --coords
`,
	RunE: func(cmd *cobra.Command, args []string) error {
		var level *model.Level
		var err error

		if fileFlag != "" {
			level, err = common.ReadLevel(fileFlag)
			if err != nil {
				return fmt.Errorf("failed to read level file: %w", err)
			}
		} else if idFlag != 0 {
			path := filepath.Join("../../assets/levels", fmt.Sprintf("level_%d.json", idFlag))
			level, err = common.ReadLevel(path)
			if err != nil {
				return fmt.Errorf("failed to read level %d: %w", idFlag, err)
			}
		} else {
			return fmt.Errorf("please provide either --file or --id to render a level")
		}

		if styleFlag == "" {
			styleFlag = "unicode"
		}

		common.RenderLevelToWriter(cmd.OutOrStdout(), level, styleFlag, coordsFlag)
		return nil
	},
}

func init() {
	RenderCmd.Flags().StringVarP(&fileFlag, "file", "f", "", "Path to a level JSON file to render")
	RenderCmd.Flags().IntVarP(&idFlag, "id", "i", 0, "Level ID to render (uses assets/levels/level_<id>.json)")
	RenderCmd.Flags().StringVarP(&styleFlag, "style", "s", "unicode", "Render style: ascii or unicode")
	RenderCmd.Flags().BoolVarP(&coordsFlag, "coords", "c", false, "Show axis coordinates")
}
