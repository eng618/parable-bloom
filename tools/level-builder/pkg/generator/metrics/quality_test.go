package metrics

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func vine(id string, color, length int) model.Vine {
	path := make([]model.Point, length)
	for i := range path {
		path[i] = model.Point{X: i, Y: 0}
	}
	return model.Vine{ID: id, HeadDirection: "right", OrderedPath: path, ColorIndex: color}
}

func TestAnalyzeQuality(t *testing.T) {
	lvl := model.Level{
		GridSize: []int{10, 10},
		Vines:    []model.Vine{vine("vine_1", 0, 5), vine("vine_2", 1, 9), vine("vine_3", 2, 3)},
	}
	q := AnalyzeQuality(lvl)
	if q.VineCount != 3 {
		t.Fatalf("VineCount=%d want 3", q.VineCount)
	}
	if q.DistinctColors != 3 {
		t.Fatalf("DistinctColors=%d want 3", q.DistinctColors)
	}
	if q.LengthVariety != 6 {
		t.Fatalf("LengthVariety=%d want 6", q.LengthVariety)
	}
	if q.AvgVineLength < 5.6 || q.AvgVineLength > 5.8 {
		t.Fatalf("AvgVineLength=%f want ~5.67", q.AvgVineLength)
	}
}

func TestCalculateCoverageUsesPointKey(t *testing.T) {
	vines := []model.Vine{vine("vine_1", 0, 4)}
	if got := CalculateCoverage([]int{4, 1}, vines); got != 1.0 {
		t.Fatalf("coverage=%f want 1.0", got)
	}
	lvl := model.Level{
		GridSize: []int{4, 1},
		Vines:    vines,
		Mask:     &model.Mask{Mode: "hide", Points: []model.Point{}},
	}
	if got := CalculatePlayableCoverage(lvl); got != 1.0 {
		t.Fatalf("playable=%f want 1.0", got)
	}
}
