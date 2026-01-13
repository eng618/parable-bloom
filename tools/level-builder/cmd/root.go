package cmd

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/cmd/clean"
	"github.com/eng618/parable-bloom/tools/level-builder/cmd/generate"
	"github.com/eng618/parable-bloom/tools/level-builder/cmd/render"
	"github.com/eng618/parable-bloom/tools/level-builder/cmd/repair"
	"github.com/eng618/parable-bloom/tools/level-builder/cmd/tutorials"
	"github.com/eng618/parable-bloom/tools/level-builder/cmd/validate"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

var (
	// Global flags
	verbose    bool
	workers    string
	workingDir string

	// Parsed workers value
	WorkersCount int
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "level-builder",
	Short: "Parable Bloom level generation and validation tool",
	Long: `Level Builder is a CLI tool for generating, validating, and managing
puzzle levels for the Parable Bloom Flutter game.

It provides commands for:
  - Generating new levels with various difficulty tiers
  - Validating level structure and solvability
  - Rendering levels as ASCII/Unicode visualizations
  - Repairing corrupted level files
  - Managing tutorial/lesson levels`,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		// Set verbose flag in common package
		common.VerboseEnabled = verbose

		// Parse workers flag
		count, err := parseWorkers(workers)
		if err != nil {
			return fmt.Errorf("invalid --workers value: %w", err)
		}
		WorkersCount = count
		common.Verbose("Workers: %d (from flag: %s)", WorkersCount, workers)

		// Handle working directory
		if workingDir != "" {
			common.Verbose("Changing working directory to: %s", workingDir)
			if err := os.Chdir(workingDir); err != nil {
				return fmt.Errorf("failed to change working directory: %w", err)
			}
		}

		return nil
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func init() {
	// Persistent flags (available to all subcommands)
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "enable verbose output for debugging")
	rootCmd.PersistentFlags().StringVarP(&workers, "workers", "j", "half", "number of concurrent workers (integer, 'half', or 'full')")
	rootCmd.PersistentFlags().StringVarP(&workingDir, "working-dir", "w", "", "working directory for asset paths (default: current directory)")

	// Register subcommands
	rootCmd.AddCommand(generate.GetCommand())
	rootCmd.AddCommand(validate.GetCommand())
	rootCmd.AddCommand(render.RenderCmd)
	rootCmd.AddCommand(repair.RepairCmd)
	rootCmd.AddCommand(clean.GetCommand())
	rootCmd.AddCommand(tutorials.GetCommand())
}

// parseWorkers parses the workers flag value
// Accepts: "full" -> NumCPU(), "half" -> NumCPU()/2, or integer string -> that value
func parseWorkers(value string) (int, error) {
	value = strings.TrimSpace(strings.ToLower(value))

	switch value {
	case "full":
		return runtime.NumCPU(), nil
	case "half":
		count := runtime.NumCPU() / 2
		if count < 1 {
			count = 1
		}
		return count, nil
	default:
		// Try to parse as integer
		count, err := strconv.Atoi(value)
		if err != nil {
			return 0, fmt.Errorf("must be 'full', 'half', or a positive integer (got: %s)", value)
		}
		if count < 1 {
			return 0, fmt.Errorf("must be at least 1 (got: %d)", count)
		}
		return count, nil
	}
}
