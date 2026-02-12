package generator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// backtrackVines removes the last N vines and returns updated collections
func backtrackVines(vines []model.Vine, occupied map[string]string, count int) ([]model.Vine, map[string]string) {
	if count >= len(vines) {
		count = len(vines) - 1 // Keep at least one vine
	}
	if count < 1 || len(vines) < 2 {
		return vines, occupied
	}

	// Remove last 'count' vines
	toRemove := vines[len(vines)-count:]
	vines = vines[:len(vines)-count]

	// Remove their cells from occupied
	for _, vine := range toRemove {
		for _, pt := range vine.OrderedPath {
			key := fmt.Sprintf("%d,%d", pt.X, pt.Y)
			delete(occupied, key)
		}
	}

	return vines, occupied
}

// writeFailureDump writes a deterministic dump (JSON + ASCII render) for failing generation states.
func writeFailureDump(config GenerationConfig, seed int64, attempt int, message string, vines []model.Vine, occupied map[string]string, stats *GenerationStats) error {
	// Default dump dir
	dumpDir := config.DumpDir
	if dumpDir == "" {
		dumpDir = filepath.Join(common.MustLogsDir(), "failing_dumps")
	}
	if err := os.MkdirAll(dumpDir, 0o755); err != nil {
		return err
	}
	if stats != nil {
		stats.DumpsProduced++
	}

	// File names
	timestamp := time.Now().UTC().Format("20060102_150405")
	base := fmt.Sprintf("failure_level_%d_seed_%d_attempt_%d_%s", config.LevelID, seed, attempt, timestamp)
	jsonPath := filepath.Join(dumpDir, base+".json")
	txtPath := filepath.Join(dumpDir, base+".txt")

	// Prepare dump object
	dump := map[string]interface{}{
		"level_id": config.LevelID,
		"grid":     []int{config.GridWidth, config.GridHeight},
		"seed":     seed,
		"attempt":  attempt,
		"message":  message,
		"coverage": calculateGridCoverage(config, occupied),
	}

	// Vines
	var simpleVines []map[string]interface{}
	for _, v := range vines {
		simple := map[string]interface{}{
			"id":             v.ID,
			"head_direction": v.HeadDirection,
			"ordered_path":   v.OrderedPath,
		}
		simpleVines = append(simpleVines, simple)
	}
	dump["vines"] = simpleVines
	dump["occupied"] = occupied

	// Write JSON
	f, err := os.Create(jsonPath)
	if err == nil {
		enc := json.NewEncoder(f)
		enc.SetIndent("", "  ")
		_ = enc.Encode(dump)
		_ = f.Close()
		common.Info("Wrote failure dump: %s", jsonPath)
	} else {
		common.Verbose("Failed to write dump JSON: %v", err)
	}

	// Write ASCII render
	level := model.Level{
		ID:       config.LevelID,
		Name:     "failure_dump",
		GridSize: []int{config.GridWidth, config.GridHeight},
		Vines:    convertVinesToModel(vines),
	}
	f2, err := os.Create(txtPath)
	if err == nil {
		common.RenderLevelToWriter(f2, &level, "ascii", true)
		_ = f2.Close()
		common.Info("Wrote failure render: %s", txtPath)
	} else {
		common.Verbose("Failed to write dump render: %v", err)
	}

	return nil
}

// Helper func needed for writeFailureDump
func calculateGridCoverage(config GenerationConfig, occupied map[string]string) float64 {
	totalCells := config.GridWidth * config.GridHeight
	occupiedCells := len(occupied)
	return float64(occupiedCells) / float64(totalCells)
}

// Helper func needed for writeFailureDump
func convertVinesToModel(vines []model.Vine) []model.Vine {
	result := make([]model.Vine, len(vines))
	for i, v := range vines {
		result[i] = model.Vine{
			ID:            v.ID,
			HeadDirection: v.HeadDirection,
			OrderedPath:   convertCommonPointsToModel(v.OrderedPath), // from assembler.go? No wait, assembler.go has it
		}
	}
	return result
}

// ConvertCommonPointsToModel needs to be accessible.
// It was in assembler.go but private. I will duplicate it here for now or fix assembler.go later.
// convertCommonPointsToModel removed (defined in assembler.go)
