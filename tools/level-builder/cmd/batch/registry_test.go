package batch

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func testRegistry() *model.ModuleRegistry {
	return &model.ModuleRegistry{
		Version:   "3.0",
		Tutorials: []string{"lesson_1"},
		LevelMappings: map[string]string{
			"lvl_m01_01": "levels/level_1.json",
		},
		Modules: []model.Module{
			{
				ID:             1,
				Name:           "Seedling",
				ThemeSeed:      "forest",
				Levels:         []string{"lvl_m01_01"},
				ChallengeLevel: "lvl_m01_challenge",
				Parable:        model.Parable{Title: "The Sower and the Seed"},
				Scriptures: []model.ModuleScripture{
					{ID: "seed_starter", TriggerLevel: "lesson_10", Reference: "Luke 8:11", Title: "The Seed is the Word", Type: "starter"},
				},
			},
		},
	}
}

func moduleLevelIDs(start int) []int {
	ids := make([]int, 21)
	for i := range ids {
		ids[i] = start + i
	}
	return ids
}

func TestApplyModulePatchPreservesNarrative(t *testing.T) {
	reg := testRegistry()
	if created := applyModuleToRegistry(reg, 1, moduleLevelIDs(1)); created {
		t.Fatalf("expected patch, got create")
	}
	m := reg.Modules[0]
	if len(m.Levels) != 20 || m.ChallengeLevel != "lvl_m01_challenge" {
		t.Fatalf("unexpected levels/challenge: %v / %s", m.Levels, m.ChallengeLevel)
	}
	if m.Name != "Seedling" || m.Parable.Title != "The Sower and the Seed" {
		t.Fatalf("narrative fields clobbered: %+v", m)
	}
	if len(m.Scriptures) != 1 || m.Scriptures[0].ID != "seed_starter" {
		t.Fatalf("scriptures dropped: %+v", m.Scriptures)
	}
	if reg.LevelMappings["lvl_m01_challenge"] != "levels/level_21.json" {
		t.Fatalf("challenge mapping missing: %v", reg.LevelMappings)
	}
}

func TestApplyModuleCreateStub(t *testing.T) {
	reg := testRegistry()
	if created := applyModuleToRegistry(reg, 6, moduleLevelIDs(106)); !created {
		t.Fatalf("expected create, got patch")
	}
	if len(reg.Modules) != 2 {
		t.Fatalf("expected 2 modules, got %d", len(reg.Modules))
	}
	m := reg.Modules[1]
	if m.ID != 6 || m.ThemeSeed != "grove" {
		t.Errorf("unexpected stub identity: %+v", m)
	}
	if len(m.Levels) != 20 || m.Levels[0] != "lvl_m06_01" || m.Levels[19] != "lvl_m06_20" {
		t.Errorf("unexpected stub levels: %v", m.Levels)
	}
	if m.ChallengeLevel != "lvl_m06_challenge" {
		t.Errorf("unexpected stub challenge: %s", m.ChallengeLevel)
	}
	if reg.LevelMappings["lvl_m06_01"] != "levels/level_106.json" {
		t.Errorf("missing generic mapping: %v", reg.LevelMappings)
	}
	if reg.LevelMappings["lvl_m06_challenge"] != "levels/level_126.json" {
		t.Errorf("missing challenge mapping: %v", reg.LevelMappings)
	}
	// Existing module untouched.
	if reg.Modules[0].Name != "Seedling" || len(reg.Modules[0].Scriptures) != 1 {
		t.Errorf("existing module disturbed: %+v", reg.Modules[0])
	}
}

func TestLiveRegistryRoundTrip(t *testing.T) {
	p, err := common.ModulesFile()
	if err != nil {
		t.Skip("no modules file")
	}
	reg, err := common.LoadModuleRegistry(p)
	if err != nil {
		t.Fatalf("load real modules.json: %v", err)
	}
	if len(reg.Modules) != 24 {
		t.Fatalf("expected 24 modules, got %d", len(reg.Modules))
	}
	total := 0
	for _, m := range reg.Modules {
		if len(m.Levels) != 20 {
			t.Errorf("module %d has %d levels, want 20", m.ID, len(m.Levels))
		}
		if m.ChallengeLevel == "" {
			t.Errorf("module %d missing challenge level", m.ID)
		}
		if len(m.Scriptures) == 0 {
			t.Errorf("module %d lost scriptures in load", m.ID)
		}
		total += len(m.Levels)
	}
	if total != 480 {
		t.Errorf("expected 480 regular levels, got %d", total)
	}
}
