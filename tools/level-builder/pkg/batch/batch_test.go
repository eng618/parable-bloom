package batch

import (
	"os"
	"path/filepath"
	"testing"
)

func TestGenerateModuleWritesStats(t *testing.T) {
	tmp := t.TempDir()
	cfg := Config{
		ModuleID:   1,
		UseLIFO:    false,
		OutputDir:  filepath.Join(tmp, "levels"),
		Aggressive: true,
		DumpDir:    filepath.Join(tmp, "dumps"),
		StatsOut:   filepath.Join(tmp, "stats"),
	}

	// Run GenerateModule for a single level via generateSingleLevel helper
	result := generateSingleLevel(1, "Seedling", cfg)
	if !result.Success {
		t.Fatalf("expected generation to succeed, got error: %s", result.Error)
	}

	// Ensure stats file exists
	statsFile := filepath.Join(cfg.StatsOut, "level_1_stats.json")
	if _, err := os.Stat(statsFile); os.IsNotExist(err) {
		t.Fatalf("expected stats file to exist: %s", statsFile)
	}
}
