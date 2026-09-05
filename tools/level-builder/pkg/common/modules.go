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

// ModuleThemeSeeds provides a distinct theme seed per module (1-based).
// Modules 1-5 match the shipped registry; 6+ carry new-garden names for the
// 504-level expansion. Unknown IDs cycle so generation never blocks.
var ModuleThemeSeeds = []string{
	"forest", "meadow", "garden", "orchard", "abundance",
	"grove", "vineyard", "pasture", "thicket", "glade",
	"terrace", "nursery", "apiary", "mill", "wellspring",
	"olive", "fig", "wheat", "barley", "cedar",
	"cypress", "palm", "willow", "brook",
}

// ThemeSeedForModule returns the theme seed for a module ID, cycling past
// the named list so future modules never hit a "default" fallback.
func ThemeSeedForModule(moduleID int) string {
	if len(ModuleThemeSeeds) == 0 {
		return "default"
	}
	idx := (moduleID - 1) % len(ModuleThemeSeeds)
	if idx < 0 {
		idx = 0
	}
	return ModuleThemeSeeds[idx]
}

// LogicalLevelID maps a physical level integer to its logical String ID.
//
// Unified generic scheme for all levels: lvl_mNN_MM (e.g. 1 -> lvl_m01_01,
// 106 -> lvl_m06_01) and lvl_mNN_challenge for bosses (21 -> lvl_m01_challenge).
// IDs stay two-digit and Firestore-safe; module/index derive from
// ModuleForLevel/IndexInModule. Level IDs below 1 fall back to lvl_m01_01.
func LogicalLevelID(levelID int) string {
	if levelID < 1 {
		return "lvl_m01_01"
	}
	module := ModuleForLevel(levelID)
	if IsChallengeLevel(levelID) {
		return fmt.Sprintf("lvl_m%02d_challenge", module)
	}
	return fmt.Sprintf("lvl_m%02d_%02d", module, IndexInModule(levelID)+1)
}
