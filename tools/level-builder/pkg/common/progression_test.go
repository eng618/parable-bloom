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

func TestExpectedGridSchedule(t *testing.T) {
	cases := []struct {
		id   int
		w, h int
		slot int
		tier string
	}{
		{1, 9, 12, 0, "Seedling"},
		{5, 12, 16, 4, "Seedling"},
		{6, 12, 16, 0, "Sprout"},
		{10, 14, 22, 4, "Sprout"},
		{11, 14, 20, 0, "Nurturing"},
		{15, 16, 26, 4, "Nurturing"},
		{16, 16, 24, 0, "Flourishing"},
		{20, 18, 30, 4, "Flourishing"},
		{21, 22, 36, 0, "Transcendent"},
		{22, 9, 12, 0, "Seedling"},
		{504, 22, 36, 0, "Transcendent"},
	}
	seen := map[[2]int]int{}
	for _, tc := range cases {
		if got := SlotInTier(tc.id); got != tc.slot {
			t.Errorf("SlotInTier(%d)=%d want %d", tc.id, got, tc.slot)
		}
		w, h := ExpectedGrid(tc.id)
		if w != tc.w || h != tc.h {
			t.Errorf("ExpectedGrid(%d)=%dx%d want %dx%d", tc.id, w, h, tc.w, tc.h)
		}
		if ExpectedDifficulty(tc.id) != tc.tier {
			t.Errorf("difficulty(%d)=%s want %s", tc.id, ExpectedDifficulty(tc.id), tc.tier)
		}
		seen[[2]int{w, h}]++
	}
	// The five seedling boards in a module are different shapes.
	var seedling [][2]int
	for id := 1; id <= 5; id++ {
		w, h := ExpectedGrid(id)
		seedling = append(seedling, [2]int{w, h})
	}
	for i := 0; i < len(seedling); i++ {
		for j := i + 1; j < len(seedling); j++ {
			if seedling[i] == seedling[j] {
				t.Errorf("seedling slots %d and %d share grid %v", i, j, seedling[i])
			}
		}
	}
}
