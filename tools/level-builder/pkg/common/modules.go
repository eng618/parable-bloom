package common

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// LoadModuleRegistry loads the modules.json file
func LoadModuleRegistry(filePath string) (*model.ModuleRegistry, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read modules.json: %w", err)
	}

	var registry model.ModuleRegistry
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()

	err = decoder.Decode(&registry)
	if err != nil {
		return nil, fmt.Errorf("failed to parse modules.json: %w", err)
	}

	return &registry, nil
}

// SaveModuleRegistry writes the modules.json file with proper formatting
func SaveModuleRegistry(filePath string, registry *model.ModuleRegistry) error {
	// Create directory if needed
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	// Marshal to JSON with nice formatting
	data, err := json.MarshalIndent(registry, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal modules.json: %w", err)
	}

	// Write atomically with temp file
	tmpFile := filePath + ".tmp"
	if err := os.WriteFile(tmpFile, data, 0o644); err != nil {
		return fmt.Errorf("failed to write temp file: %w", err)
	}

	// Atomic rename
	if err := os.Rename(tmpFile, filePath); err != nil {
		_ = os.Remove(tmpFile)
		return fmt.Errorf("failed to rename temp file: %w", err)
	}

	Verbose("Updated modules.json: %s", filePath)
	return nil
}

// UpdateModuleRegistry updates a module's level array in the registry
func UpdateModuleRegistry(filePath string, moduleID int, levelIDs []string) error {
	registry, err := LoadModuleRegistry(filePath)
	if err != nil {
		return err
	}

	// Find the module
	var found bool
	for i, mod := range registry.Modules {
		if mod.ID == moduleID {
			registry.Modules[i].Levels = levelIDs
			found = true
			break
		}
	}

	if !found {
		return fmt.Errorf("module %d not found in registry", moduleID)
	}

	return SaveModuleRegistry(filePath, registry)
}

// GetModuleLevelIDs returns the level IDs for a given module
func GetModuleLevelIDs(registry *model.ModuleRegistry, moduleID int) ([]string, error) {
	for _, mod := range registry.Modules {
		if mod.ID == moduleID {
			return mod.Levels, nil
		}
	}
	return nil, fmt.Errorf("module %d not found", moduleID)
}

// GetModuleByID returns a module by its ID
func GetModuleByID(registry *model.ModuleRegistry, moduleID int) (*model.Module, error) {
	for i := range registry.Modules {
		if registry.Modules[i].ID == moduleID {
			return &registry.Modules[i], nil
		}
	}
	return nil, fmt.Errorf("module %d not found", moduleID)
}

// LogicalLevelID maps a physical level integer to its logical String ID.
func LogicalLevelID(levelID int) string {
	if levelID == 21 {
		return "lvl_seed_challenge"
	}
	if levelID == 42 {
		return "lvl_sprout_challenge"
	}
	if levelID == 63 {
		return "lvl_blossom_challenge"
	}
	if levelID == 84 {
		return "lvl_flourish_challenge"
	}
	if levelID == 105 {
		return "lvl_harvest_challenge"
	}

	if levelID >= 1 && levelID <= 20 {
		return fmt.Sprintf("lvl_seed_%02d", levelID)
	}
	if levelID >= 22 && levelID <= 41 {
		idx := levelID - 21
		return fmt.Sprintf("lvl_sprout_%02d", idx)
	}
	if levelID >= 43 && levelID <= 62 {
		idx := levelID - 42
		return fmt.Sprintf("lvl_blossom_%02d", idx)
	}
	if levelID >= 64 && levelID <= 83 {
		idx := levelID - 63
		return fmt.Sprintf("lvl_flourish_%02d", idx)
	}
	if levelID >= 85 && levelID <= 104 {
		idx := levelID - 84
		return fmt.Sprintf("lvl_harvest_%02d", idx)
	}
	return "lvl_seed_01"
}
