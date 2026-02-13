package generator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

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

// writeLevelToFile writes the level to JSON file
func writeLevelToFile(level model.Level, cfg config.GenerationConfig) error {
	outputPath := cfg.OutputFile
	if outputPath == "" {
		var err error
		outputPath, err = common.LevelFilePath(cfg.LevelID)
		if err != nil {
			return fmt.Errorf("failed to resolve level file path: %w", err)
		}
	}

	// Check if file exists and overwrite is not enabled
	if !cfg.Overwrite {
		if _, err := os.Stat(outputPath); err == nil {
			return fmt.Errorf("file already exists: %s (use --overwrite to replace)", outputPath)
		}
	}

	// Ensure directory exists
	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Write JSON
	file, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer func() { _ = file.Close() }()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(level); err != nil {
		return fmt.Errorf("failed to encode JSON: %w", err)
	}

	common.Info("Wrote level file: %s", outputPath)
	return nil
}
