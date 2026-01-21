package common

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// BackupLevels creates a timestamped backup of the specified level files
func BackupLevels(levelIDs []int, sourceDir, backupBaseDir string) (string, error) {
	if len(levelIDs) == 0 {
		return "", fmt.Errorf("no level IDs provided for backup")
	}

	// Create timestamped backup directory
	timestamp := time.Now().Format("20060102_150405")
	backupDir := filepath.Join(backupBaseDir, fmt.Sprintf("backup_%s", timestamp))

	if err := os.MkdirAll(backupDir, 0o755); err != nil {
		return "", fmt.Errorf("failed to create backup directory: %w", err)
	}

	// Copy each level file
	for _, levelID := range levelIDs {
		srcFile := filepath.Join(sourceDir, fmt.Sprintf("level_%d.json", levelID))
		dstFile := filepath.Join(backupDir, fmt.Sprintf("level_%d.json", levelID))

		// Skip if source doesn't exist (expected for new levels)
		if _, err := os.Stat(srcFile); os.IsNotExist(err) {
			continue
		}

		// Copy the file
		data, err := os.ReadFile(srcFile)
		if err != nil {
			return "", fmt.Errorf("failed to read %s: %w", srcFile, err)
		}

		if err := os.WriteFile(dstFile, data, 0o644); err != nil {
			return "", fmt.Errorf("failed to write backup %s: %w", dstFile, err)
		}

		Verbose("Backed up: %s -> %s", srcFile, dstFile)
	}

	Info("Backup created at: %s", backupDir)
	return backupDir, nil
}
