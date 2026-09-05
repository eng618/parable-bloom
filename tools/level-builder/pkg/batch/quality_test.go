package batch

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/metrics"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestCheckDifficultyLock(t *testing.T) {
	lvl := model.Level{ID: 1, Difficulty: "Seedling"}
	if err := checkDifficultyLock(1, "Seedling", lvl); err != nil {
		t.Fatalf("expected lock pass: %v", err)
	}
	bad := model.Level{ID: 1, Difficulty: "Sprout"}
	if err := checkDifficultyLock(1, "Seedling", bad); err == nil {
		t.Fatalf("expected lock failure for mismatched difficulty")
	}
	if err := checkDifficultyLock(21, "Seedling", model.Level{ID: 21, Difficulty: "Seedling"}); err == nil {
		t.Fatalf("expected lock failure for wrong requested tier on challenge")
	}
}

func TestCheckQualityRejectsDegenerate(t *testing.T) {
	monochrome := make([]model.Vine, 6)
	for i := range monochrome {
		path := make([]model.Point, 5+i%2)
		for j := range path {
			path[j] = model.Point{X: j, Y: i}
		}
		monochrome[i] = model.Vine{ID: "vine", HeadDirection: "right", OrderedPath: path, ColorIndex: 0}
	}
	lvl := model.Level{ID: 6, Difficulty: "Sprout", GridSize: []int{10, 14}, Vines: monochrome}
	q := metrics.AnalyzeQuality(lvl)
	if err := checkQuality(lvl, q); err == nil {
		t.Fatalf("expected monochrome reject")
	}

	flat := make([]model.Vine, 6)
	for i := range flat {
		path := make([]model.Point, 5)
		for j := range path {
			path[j] = model.Point{X: j, Y: i}
		}
		flat[i] = model.Vine{ID: "vine", HeadDirection: "right", OrderedPath: path, ColorIndex: i % 3}
	}
	lvl2 := model.Level{ID: 6, Difficulty: "Sprout", GridSize: []int{10, 14}, Vines: flat}
	q2 := metrics.AnalyzeQuality(lvl2)
	if err := checkQuality(lvl2, q2); err == nil {
		t.Fatalf("expected flat-length reject")
	}
}
