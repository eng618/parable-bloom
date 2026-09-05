package common

import "testing"

func TestLogicalLevelIDGenericScheme(t *testing.T) {
	cases := map[int]string{
		0:   "lvl_m01_01",
		-3:  "lvl_m01_01",
		1:   "lvl_m01_01",
		5:   "lvl_m01_05",
		20:  "lvl_m01_20",
		21:  "lvl_m01_challenge",
		22:  "lvl_m02_01",
		42:  "lvl_m02_challenge",
		105: "lvl_m05_challenge",
		106: "lvl_m06_01",
		110: "lvl_m06_05",
		111: "lvl_m06_06",
		125: "lvl_m06_20",
		126: "lvl_m06_challenge",
		127: "lvl_m07_01",
		147: "lvl_m07_challenge",
		484: "lvl_m24_01",
		503: "lvl_m24_20",
		504: "lvl_m24_challenge",
	}
	for id, want := range cases {
		if got := LogicalLevelID(id); got != want {
			t.Errorf("LogicalLevelID(%d)=%s want %s", id, got, want)
		}
	}
}

func TestLogicalLevelIDUniqueAcross504(t *testing.T) {
	seen := map[string]int{}
	for id := 1; id <= 504; id++ {
		got := LogicalLevelID(id)
		if prev, dup := seen[got]; dup {
			t.Fatalf("duplicate logical ID %s for levels %d and %d", got, prev, id)
		}
		seen[got] = id
		if ModuleForLevel(id) != 1+(id-1)/LevelsPerModule {
			t.Fatalf("ModuleForLevel(%d) inconsistent", id)
		}
		if want := IndexInModule(id); want != (id-1)%LevelsPerModule {
			t.Fatalf("IndexInModule(%d)=%d inconsistent", id, want)
		}
	}
	if len(seen) != 504 {
		t.Fatalf("expected 504 unique IDs for 1..504, got %d", len(seen))
	}
}

func TestThemeSeedForModule(t *testing.T) {
	// Shipped modules keep their registry seeds.
	for id, want := range map[int]string{
		1: "forest", 2: "meadow", 3: "garden", 4: "orchard", 5: "abundance",
	} {
		if got := ThemeSeedForModule(id); got != want {
			t.Errorf("ThemeSeedForModule(%d)=%s want %s", id, got, want)
		}
	}
	if got := ThemeSeedForModule(6); got != "grove" {
		t.Errorf("ThemeSeedForModule(6)=%s want grove", got)
	}
	// Distinct across the 24-module expansion, never empty/default.
	seen := map[string]int{}
	for id := 1; id <= 24; id++ {
		s := ThemeSeedForModule(id)
		if s == "" || s == "default" {
			t.Fatalf("ThemeSeedForModule(%d) fell back to %q", id, s)
		}
		if prev, dup := seen[s]; dup {
			t.Fatalf("duplicate theme seed %s for modules %d and %d", s, prev, id)
		}
		seen[s] = id
	}
}
