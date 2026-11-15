package generator

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

// Clean removes generated level and module files used by the level builder.
func Clean() error {
	levelsDir, err := common.LevelsDir()
	if err != nil {
		return fmt.Errorf("failed to resolve levels directory: %w", err)
	}

	files, err := filepath.Glob(filepath.Join(levelsDir, "level_*.json"))
	if err != nil {
		return err
	}
	for _, f := range files {
		if err := os.Remove(f); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("failed to remove %s: %w", f, err)
		}
	}

	modulesFile, err := common.ModulesFile()
	if err != nil {
		return fmt.Errorf("failed to resolve modules.json path: %w", err)
	}

	if err := os.Remove(modulesFile); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to remove %s: %w", modulesFile, err)
	}
	return nil
}
