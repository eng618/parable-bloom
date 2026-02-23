package common

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

// Singleton for resolved asset paths
var (
	resolvedAssetsDir   string
	resolvedLevelsDir   string
	resolvedDataDir     string
	resolvedModulesFile string
	resolvedLessonsDir  string
	resolvedLogsDir     string
	pathsOnce           sync.Once
	pathsError          error
)

// RepoMarkerFiles are files that indicate the root of the parable-bloom repository.
// We specifically use pubspec.yaml because it's only at the project root,
// unlike go.mod or assets/ which also exist in tools/level-builder.
var RepoMarkerFiles = []string{"nx.json", "bun.lock", "pubspec.yaml"}

// initPaths resolves asset paths once at startup.
// It looks for the repo root by checking:
// 1. Current working directory
// 2. Parent directories (up to 5 levels)
// Returns error if repo root cannot be found.
func initPaths() {
	pathsOnce.Do(func() {
		repoRoot, err := findRepoRoot()
		if err != nil {
			pathsError = err
			return
		}

		// Support both monorepo and legacy structures
		monorepoAssets := filepath.Join(repoRoot, "apps", "parable-bloom", "assets")
		if _, err := os.Stat(monorepoAssets); err == nil {
			resolvedAssetsDir = monorepoAssets
		} else {
			resolvedAssetsDir = filepath.Join(repoRoot, "assets")
		}

		resolvedLevelsDir = filepath.Join(resolvedAssetsDir, "levels")
		resolvedDataDir = filepath.Join(resolvedAssetsDir, "data")
		resolvedModulesFile = filepath.Join(resolvedDataDir, "modules.json")
		resolvedLessonsDir = filepath.Join(resolvedAssetsDir, "lessons")
		resolvedLogsDir = filepath.Join(repoRoot, "logs")

		Verbose("Resolved repo root: %s", repoRoot)
		Verbose("Assets directory: %s", resolvedAssetsDir)
	})
}

// findRepoRoot searches for the repository root by looking for marker files
// starting from the current directory and walking up the directory tree.
func findRepoRoot() (string, error) {
	// Start from current working directory
	cwd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("failed to get current directory: %w", err)
	}

	// Check current directory and up to 5 parent directories
	dir := cwd
	for i := 0; i < 6; i++ {
		if isRepoRoot(dir) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			// Reached filesystem root
			break
		}
		dir = parent
	}

	return "", fmt.Errorf("could not find parable-bloom repo root (looked for %v starting from %s)", RepoMarkerFiles, cwd)
}

// isRepoRoot checks if a directory contains repo marker files
func isRepoRoot(dir string) bool {
	for _, marker := range RepoMarkerFiles {
		markerPath := filepath.Join(dir, marker)
		if _, err := os.Stat(markerPath); err == nil {
			// Found a marker, check for assets in standard or monorepo locations
			assetsPaths := []string{
				filepath.Join(dir, "assets"),
				filepath.Join(dir, "apps", "parable-bloom", "assets"),
			}
			for _, assetsPath := range assetsPaths {
				if _, err := os.Stat(assetsPath); err == nil {
					return true
				}
			}
		}
	}
	return false
}

// AssetsDir returns the absolute path to the assets directory.
func AssetsDir() (string, error) {
	initPaths()
	if pathsError != nil {
		return "", pathsError
	}
	return resolvedAssetsDir, nil
}

// LevelsDir returns the absolute path to the levels directory.
func LevelsDir() (string, error) {
	initPaths()
	if pathsError != nil {
		return "", pathsError
	}
	return resolvedLevelsDir, nil
}

// DataDir returns the absolute path to the data directory.
func DataDir() (string, error) {
	initPaths()
	if pathsError != nil {
		return "", pathsError
	}
	return resolvedDataDir, nil
}

// ModulesFile returns the absolute path to the modules.json file.
func ModulesFile() (string, error) {
	initPaths()
	if pathsError != nil {
		return "", pathsError
	}
	return resolvedModulesFile, nil
}

// LessonsDir returns the absolute path to the lessons directory.
func LessonsDir() (string, error) {
	initPaths()
	if pathsError != nil {
		return "", pathsError
	}
	return resolvedLessonsDir, nil
}

// LogsDir returns the absolute path to the root logs directory.
func LogsDir() (string, error) {
	initPaths()
	if pathsError != nil {
		return "", pathsError
	}
	return resolvedLogsDir, nil
}

// LevelFilePath returns the absolute path to a specific level file.
func LevelFilePath(levelID int) (string, error) {
	levelsDir, err := LevelsDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(levelsDir, fmt.Sprintf("level_%d.json", levelID)), nil
}

// MustLevelsDir returns the levels directory path or panics if not found.
// Use sparingly - prefer LevelsDir() with proper error handling.
func MustLevelsDir() string {
	dir, err := LevelsDir()
	if err != nil {
		panic(fmt.Sprintf("failed to resolve levels directory: %v", err))
	}
	return dir
}

// MustModulesFile returns the modules.json file path or panics if not found.
// Use sparingly - prefer ModulesFile() with proper error handling.
func MustModulesFile() string {
	path, err := ModulesFile()
	if err != nil {
		panic(fmt.Sprintf("failed to resolve modules.json path: %v", err))
	}
	return path
}

// MustLogsDir returns the logs directory path or panics if not found.
func MustLogsDir() string {
	path, err := LogsDir()
	if err != nil {
		panic(fmt.Sprintf("failed to resolve logs directory: %v", err))
	}
	return path
}

// ResetPaths resets the cached paths (useful for testing)
func ResetPaths() {
	resolvedAssetsDir = ""
	resolvedLevelsDir = ""
	resolvedDataDir = ""
	resolvedModulesFile = ""
	resolvedLessonsDir = ""
	resolvedLogsDir = ""
	pathsOnce = sync.Once{}
	pathsError = nil
}
