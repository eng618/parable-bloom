package generator

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// GenerateLevel is now a wrapper for GenerateRobust.
func GenerateLevel(cfg config.GenerationConfig) (model.Level, config.GenerationStats, error) {
	level, stats, err := GenerateRobust(cfg)
	if err != nil {
		return level, stats, err
	}
	if err := writeLevelToFile(level, cfg); err != nil {
		return level, stats, err
	}
	return level, stats, nil
}

// GenerateLevelLIFO is now a wrapper for GenerateRobust.
func GenerateLevelLIFO(cfg config.GenerationConfig) (model.Level, config.GenerationStats, error) {
	if cfg.Strategy == "" {
		cfg.Strategy = config.StrategyCenterOut
	}
	return GenerateLevel(cfg) // Both use the robust pipeline now
}

// writeLevelToFile writes the level atomically via common.WriteLevel,
// which sanitizes runtime-only fields and uses tmp+rename.
func writeLevelToFile(level model.Level, cfg config.GenerationConfig) error {
	outputPath := cfg.OutputFile
	if outputPath == "" {
		var err error
		outputPath, err = common.LevelFilePath(cfg.LevelID)
		if err != nil {
			return fmt.Errorf("failed to resolve level file path: %w", err)
		}
	}

	if err := common.WriteLevel(outputPath, &level, cfg.Overwrite); err != nil {
		return err
	}

	common.Info("Wrote level file: %s", outputPath)
	return nil
}
