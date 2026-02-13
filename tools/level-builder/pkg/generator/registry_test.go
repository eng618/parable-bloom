package generator

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
)

func TestRegisterStrategy(t *testing.T) {
	// Register a test strategy
	dummyFactory := func() config.VinePlacementStrategy {
		return &strategies.CenterOutPlacer{} // Revert to known type for simplicity, or mock if possible
	}
	RegisterStrategy("test-strategy", "A test strategy", dummyFactory)

	// Verify it exists in GetStrategy
	s, err := GetStrategy("test-strategy")
	if err != nil {
		t.Fatalf("Failed to get registered strategy: %v", err)
	}
	if s == nil {
		t.Fatal("Strategy instance is nil")
	}

	// Verify metadata in ListStrategies
	list := ListStrategies()
	found := false
	for _, info := range list {
		if info.Name == "test-strategy" {
			found = true
			if info.Description != "A test strategy" {
				t.Errorf("Expected description 'A test strategy', got '%s'", info.Description)
			}
		}
	}
	if !found {
		t.Error("Test strategy not found in list")
	}
}

func TestGetUnknownStrategy(t *testing.T) {
	_, err := GetStrategy("non-existent-strategy")
	if err == nil {
		t.Error("Expected error for unknown strategy, got nil")
	}
}

func TestCoreStrategiesRegistered(t *testing.T) {
	// Verify core strategies are present
	expected := []string{config.StrategyCenterOut, config.StrategyDirectionFirst, "circuit-board"}

	for _, name := range expected {
		_, err := GetStrategy(name)
		if err != nil {
			t.Errorf("Core strategy '%s' not registered: %v", name, err)
		}
	}
}
