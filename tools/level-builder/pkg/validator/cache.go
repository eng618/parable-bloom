package validator

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

// CacheEntry represents the validation details stored for a level.
type CacheEntry struct {
	ContentHash   string `json:"content_hash"`
	SolverVersion int    `json:"solver_version"`
	Solvable      bool   `json:"solvable"`
}

// ValidationCache holds a thread-safe map of level validation results.
type ValidationCache struct {
	mu     sync.RWMutex
	Levels map[string]CacheEntry `json:"levels"`
}

// NewValidationCache creates an empty ValidationCache.
func NewValidationCache() *ValidationCache {
	return &ValidationCache{
		Levels: make(map[string]CacheEntry),
	}
}

// CachePath returns the absolute path to validation_cache.json.
func CachePath() (string, error) {
	dataDir, err := common.DataDir()
	if err != nil {
		return "", fmt.Errorf("failed to get data directory: %w", err)
	}
	return filepath.Join(dataDir, "validation_cache.json"), nil
}

// LoadCache loads the validation cache from assets/data/validation_cache.json.
// If the file doesn't exist, it returns a new empty cache.
func LoadCache() (*ValidationCache, error) {
	path, err := CachePath()
	if err != nil {
		return nil, err
	}

	if _, err := os.Stat(path); os.IsNotExist(err) {
		common.Verbose("Validation cache not found; starting fresh at %s", path)
		return NewValidationCache(), nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read cache file: %w", err)
	}

	cache := NewValidationCache()
	if err := json.Unmarshal(data, cache); err != nil {
		return nil, fmt.Errorf("failed to parse cache JSON: %w", err)
	}

	if cache.Levels == nil {
		cache.Levels = make(map[string]CacheEntry)
	}

	common.Verbose("Loaded %d levels from validation cache", len(cache.Levels))
	return cache, nil
}

// SaveCache writes the validation cache atomically to validation_cache.json.
// Because Go's map marshalling automatically sorts string keys, key ordering is deterministic.
func (c *ValidationCache) SaveCache() error {
	c.mu.RLock()
	defer c.mu.RUnlock()

	path, err := CachePath()
	if err != nil {
		return err
	}

	// Create directory if needed
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal cache JSON: %w", err)
	}

	// Write atomically using temporary file to prevent corruption
	tmpFile, err := os.CreateTemp(dir, "tmpcache-*.json")
	if err != nil {
		return fmt.Errorf("failed to create temp cache file: %w", err)
	}
	tmpName := tmpFile.Name()

	defer func() {
		_ = tmpFile.Close()
		_ = os.Remove(tmpName)
	}()

	if _, err := tmpFile.Write(data); err != nil {
		return fmt.Errorf("failed to write temp cache: %w", err)
	}
	if err := tmpFile.Sync(); err != nil {
		return fmt.Errorf("failed to sync temp cache: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp cache: %w", err)
	}

	if err := os.Chmod(tmpName, 0644); err != nil {
		return fmt.Errorf("failed to chmod temp cache: %w", err)
	}

	if err := os.Rename(tmpName, path); err != nil {
		return fmt.Errorf("failed to rename temp cache to %s: %w", path, err)
	}

	common.Verbose("Successfully saved %d levels to validation cache", len(c.Levels))
	return nil
}

// ComputeHash calculates the SHA-256 checksum of file content bytes.
func ComputeHash(content []byte) string {
	hash := sha256.Sum256(content)
	return hex.EncodeToString(hash[:])
}

// Lookup checks if a level is cached with the same hash and solver version.
func (c *ValidationCache) Lookup(levelKey string, content []byte, currentSolverVersion int) (bool, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	entry, exists := c.Levels[levelKey]
	if !exists {
		return false, false
	}

	if entry.SolverVersion != currentSolverVersion {
		return false, false
	}

	hash := ComputeHash(content)
	if entry.ContentHash != hash {
		return false, false
	}

	return true, entry.Solvable
}

// Update records or updates a level's validation status.
func (c *ValidationCache) Update(levelKey string, content []byte, currentSolverVersion int, solvable bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	hash := ComputeHash(content)
	c.Levels[levelKey] = CacheEntry{
		ContentHash:   hash,
		SolverVersion: currentSolverVersion,
		Solvable:      solvable,
	}
}
