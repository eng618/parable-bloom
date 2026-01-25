package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

// BenchmarkStructuralValidation measures structural validation performance
func BenchmarkStructuralValidation(b *testing.B) {
	levelsDir, err := common.LevelsDir()
	if err != nil {
		b.Fatalf("Failed to resolve levels directory: %v", err)
	}
	levels, err := loadAllLevels(levelsDir)
	if err != nil {
		b.Fatalf("Failed to load levels: %v", err)
	}

	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		for _, level := range levels {
			errs := validator.ValidateStructural(*level)
			if len(errs) > 0 {
				b.Fatalf("Structural validation failed for level %d: %v", level.ID, errs[0])
			}
		}
	}
}

// BenchmarkSingleLevelSolvability measures solvability check for level 20 (slowest)
func BenchmarkSingleLevelSolvability(b *testing.B) {
	levelPath, err := common.LevelFilePath(20)
	if err != nil {
		b.Fatalf("Failed to resolve level path: %v", err)
	}
	level, err := loadLevel(levelPath)
	if err != nil {
		b.Fatalf("Failed to load level: %v", err)
	}

	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		_, _, _ = validator.IsSolvableWithOptions(*level, 100000, true, 10)
	}
}

// Helper function to load all levels from directory
func loadAllLevels(dir string) ([]*model.Level, error) {
	files, err := filepath.Glob(filepath.Join(dir, "level_*.json"))
	if err != nil {
		return nil, err
	}

	var levels []*model.Level
	for _, file := range files {
		level, err := loadLevel(file)
		if err != nil {
			return nil, err
		}
		levels = append(levels, level)
	}

	return levels, nil
}

// Helper function to load a single level
func loadLevel(path string) (*model.Level, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var level model.Level
	if err := json.Unmarshal(data, &level); err != nil {
		return nil, err
	}

	return &level, nil
}
