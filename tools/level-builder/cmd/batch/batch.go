/*
Package batch provides the command-line interface for batch-generating entire modules using gen2.

The batch command orchestrates the generation of 21 levels per module, with difficulty
progression across tiers:
  - Levels 1-5: Seedling
  - Levels 6-10: Sprout
  - Levels 11-15: Nurturing
  - Levels 16-20: Flourishing
  - Level 21: Transcendent (challenge level)

For module N, level IDs are calculated as: (N-1)*21+1 through (N-1)*21+21

Features:
  - Auto-update of modules.json with new level arrays
  - Optional backup of existing levels before overwriting
  - Per-level validation with fail-fast error reporting
  - Dry-run mode for previewing generation without writing files
  - LIFO mode for guaranteed solvability and 100% coverage

Usage examples:

	level-builder batch --module 1
	level-builder batch --module 2 --lifo --overwrite
	level-builder batch --module 3 --dry-run
	level-builder batch --module 4 --backup

The command generates levels sequentially, validates each immediately after generation,
and reports a summary of success/failure statistics at the end.
*/
package batch

import (
	"fmt"
	"path/filepath"

	"github.com/spf13/cobra"

	batchsvc "github.com/eng618/parable-bloom/tools/level-builder/pkg/batch"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

var (
	moduleID  int
	overwrite bool
	useLIFO   bool
	dryRun    bool
	backup    bool
	// Batch-level options
	aggressive bool
	dumpDir    string
	statsOut   string
)

// batchCmd represents the batch command
var batchCmd = &cobra.Command{
	Use:   "batch",
	Short: "Generate all 21 levels for a module using gen2 algorithm",
	Long: `Generate an entire module of 21 levels with difficulty progression:
  - Levels 1-5: Seedling
  - Levels 6-10: Sprout
  - Levels 11-15: Nurturing
  - Levels 16-20: Flourishing
  - Level 21: Transcendent (challenge)

For module N, level IDs are (N-1)*21+1 through (N-1)*21+21.

The command generates levels sequentially, validates each immediately,
updates modules.json with the new level array, and optionally backs up
existing level files.

Examples:
  level-builder batch --module 1
  level-builder batch --module 2 --lifo --overwrite
  level-builder batch --module 3 --dry-run
  level-builder batch --module 4 --backup`,
	RunE: runBatch,
}

func init() {
	batchCmd.Flags().IntVar(&moduleID, "module", 0, "module ID to generate (1-5, required)")
	batchCmd.Flags().BoolVar(&overwrite, "overwrite", false, "overwrite existing level files")
	batchCmd.Flags().BoolVar(&useLIFO, "lifo", false, "use LIFO mode for guaranteed solvability and 100% coverage")
	batchCmd.Flags().BoolVar(&dryRun, "dry-run", false, "preview what would be generated without writing files")
	batchCmd.Flags().BoolVar(&backup, "backup", true, "backup existing levels before overwriting")

	// New flags to support aggressive LIFO runs and dump directory
	batchCmd.Flags().BoolVar(&aggressive, "aggressive", false, "enable aggressive backtracking defaults for batch runs (window=6 attempts=6)")
	batchCmd.Flags().StringVar(&dumpDir, "dump-dir", "", "directory to write failing generation dumps (optional)")
	batchCmd.Flags().StringVar(&statsOut, "stats-out", "", "optional directory to write per-level generation stats JSON files")

	batchCmd.MarkFlagRequired("module")
}

// GetCommand returns the batch command
func GetCommand() *cobra.Command {
	return batchCmd
}

func runBatch(cmd *cobra.Command, args []string) error {
	common.Info("Starting batch generation for module %d...", moduleID)
	if err := validateModuleID(moduleID); err != nil {
		return err
	}

	config := buildConfig()
	levelIDs := buildModuleLevelIDs(moduleID)
	performBackupGuarded(levelIDs, config, backup, dryRun)

	// Generate the module
	batchResult, err := batchsvc.GenerateModule(config)
	if err != nil {
		return err
	}

	if err := reportSummary(batchResult); err != nil {
		return err
	}

	if dryRun {
		common.Info("\nBatch generation completed (dry run).")
		return nil
	}

	if err := updateModulesRegistry(moduleID, levelIDs); err != nil {
		return err
	}

	common.Info("\nBatch generation completed successfully!")
	return nil
}

func validateModuleID(id int) error {
	if id < 1 || id > 5 {
		return fmt.Errorf("invalid module ID: %d (must be 1-5)", id)
	}
	return nil
}

func buildConfig() batchsvc.Config {
	return batchsvc.Config{
		ModuleID:   moduleID,
		UseLIFO:    useLIFO,
		Overwrite:  overwrite,
		DryRun:     dryRun,
		OutputDir:  "assets/levels",
		Aggressive: aggressive,
		DumpDir:    dumpDir,
		StatsOut:   statsOut,
	}
}

func buildModuleLevelIDs(moduleID int) []int {
	startLevelID := (moduleID-1)*21 + 1
	levelIDs := make([]int, 21)
	for i := 0; i < 21; i++ {
		levelIDs[i] = startLevelID + i
	}
	return levelIDs
}

func performBackup(levelIDs []int, sourceDir string) {
	if _, err := common.BackupLevels(levelIDs, sourceDir, "assets/levels_backup"); err != nil {
		common.Warning("Backup failed: %v (continuing anyway)", err)
	}
}

func performBackupGuarded(levelIDs []int, cfg batchsvc.Config, doBackup bool, isDryRun bool) {
	if !doBackup || isDryRun || !cfg.Overwrite {
		return
	}
	performBackup(levelIDs, cfg.OutputDir)
}

func updateModulesRegistry(moduleID int, levelIDs []int) error {
	modulesPath := filepath.Join("assets/data", "modules.json")
	if err := common.UpdateModuleRegistry(modulesPath, moduleID, levelIDs); err != nil {
		return fmt.Errorf("failed to update modules.json: %w", err)
	}
	common.Info("Updated modules.json for module %d", moduleID)
	return nil
}

func reportSummary(batchResult *batchsvc.ModuleBatch) error {
	common.Info("\n=== Batch Generation Summary ===")
	common.Info("Module: %d", batchResult.ModuleID)
	common.Info("Total Time: %v", batchResult.TotalTime)
	common.Info("Success: %d / %d", batchResult.SuccessCount, len(batchResult.Levels))
	common.Info("Failures: %d", batchResult.FailureCount)

	if batchResult.FailureCount == 0 {
		return nil
	}

	common.Warning("\nFailed levels:")
	for _, result := range batchResult.Levels {
		if !result.Success {
			common.Warning("  Level %d (%s): %s", result.LevelID, result.Difficulty, result.Error)
		}
	}
	return fmt.Errorf("batch generation completed with %d failures", batchResult.FailureCount)
}
