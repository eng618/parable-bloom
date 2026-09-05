package generator

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestParseVineID(t *testing.T) {
	cases := map[string]int{
		"vine_1":  1,
		"vine_12": 12,
		"vine_0":  0,
		"bad":     0,
		"":        0,
		"vine_-3": 0,
		"vine_x":  0,
	}
	for in, want := range cases {
		if got := parseVineID(in); got != want {
			t.Errorf("parseVineID(%q)=%d want %d", in, got, want)
		}
	}
}

func TestResolveSeedDeterministic(t *testing.T) {
	cfg := config.GenerationConfig{Seed: 12345, Randomize: false}
	if got := resolveSeed(cfg); got != 12345 {
		t.Fatalf("resolveSeed deterministic got %d want 12345", got)
	}
	// Randomize path must not return zero seed deterministically; just exercise it.
	cfg.Randomize = true
	_ = resolveSeed(cfg)
}

func TestEnsureUniqueVineIDsSequential(t *testing.T) {
	vines := []model.Vine{{ID: "vine_9"}, {ID: "bogus"}, {ID: "vine_9"}}
	got := ensureUniqueVineIDs(vines)
	for i, v := range got {
		want := "vine_1"
		if i == 1 {
			want = "vine_2"
		}
		if i == 2 {
			want = "vine_3"
		}
		if v.ID != want {
			t.Fatalf("vine %d ID=%s want %s", i, v.ID, want)
		}
	}
}

func TestFindEmptyCells(t *testing.T) {
	occupied := map[string]string{"0,0": "vine_1", "1,0": "vine_1"}
	empty := findEmptyCells(2, 2, occupied)
	if len(empty) != 2 {
		t.Fatalf("expected 2 empty cells, got %d", len(empty))
	}
}

func TestComplexityDelegatesToCommon(t *testing.T) {
	a := &LevelAssembler{}
	for _, d := range []string{"Tutorial", "Seedling", "Sprout", "Nurturing", "Flourishing", "Transcendent"} {
		if got := a.complexityForDifficulty(d); got == "" {
			t.Fatalf("empty complexity for %s", d)
		}
	}
}
