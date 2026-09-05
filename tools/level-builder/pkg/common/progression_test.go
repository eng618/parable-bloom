package common

import "testing"

func TestExpectedDifficultyPattern(t *testing.T) {
	cases := map[int]string{
		1: "Seedling", 5: "Seedling",
		6: "Sprout", 10: "Sprout",
		11: "Nurturing", 15: "Nurturing",
		16: "Flourishing", 20: "Flourishing",
		21: "Transcendent",
		22: "Seedling", 42: "Transcendent",
		43: "Seedling", 63: "Transcendent",
		105: "Transcendent",
	}
	for id, want := range cases {
		if got := ExpectedDifficulty(id); got != want {
			t.Errorf("ExpectedDifficulty(%d)=%s want %s", id, got, want)
		}
	}
}

func TestModuleMapping(t *testing.T) {
	if got := ModuleForLevel(21); got != 1 {
		t.Errorf("ModuleForLevel(21)=%d want 1", got)
	}
	if got := ModuleForLevel(22); got != 2 {
		t.Errorf("ModuleForLevel(22)=%d want 2", got)
	}
	if !IsChallengeLevel(21) || !IsChallengeLevel(105) {
		t.Errorf("challenge detection failed")
	}
	if IsChallengeLevel(20) {
		t.Errorf("level 20 should not be challenge")
	}
}
