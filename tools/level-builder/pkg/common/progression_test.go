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
		106: "Seedling", 126: "Transcendent",
		484: "Seedling", 503: "Flourishing", 504: "Transcendent",
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
	if got := ModuleForLevel(106); got != 6 {
		t.Errorf("ModuleForLevel(106)=%d want 6", got)
	}
	if got := ModuleForLevel(504); got != 24 {
		t.Errorf("ModuleForLevel(504)=%d want 24", got)
	}
	if !IsChallengeLevel(21) || !IsChallengeLevel(105) || !IsChallengeLevel(504) {
		t.Errorf("challenge detection failed")
	}
	if IsChallengeLevel(20) {
		t.Errorf("level 20 should not be challenge")
	}
}
